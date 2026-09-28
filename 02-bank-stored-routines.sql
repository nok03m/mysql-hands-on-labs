-- User-defined functions workshop, banking domain
-- Reviewed and cleaned up: English naming, tighter validation, minor fixes
-- Table references (Cuentas, historial_transferencias) kept as-is since those already exist

USE BancoDB;

-- ---------------------------------------------------------------------------
-- Exercise 1: 4x1000 tax (GMF) calculation
-- DETERMINISTIC because it's pure math, no table access
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS CalculateGMFTax;

DELIMITER //

CREATE FUNCTION CalculateGMFTax(
    p_amount DECIMAL(12,2),
    p_is_exempt BOOLEAN
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE v_tax DECIMAL(12,2);

    -- negative amounts don't make sense here, treat them as zero base
    IF p_amount IS NULL OR p_amount < 0 THEN
        RETURN 0.00;
    END IF;

    IF p_is_exempt THEN
        SET v_tax = 0.00;
    ELSE
        -- 4x1000 is just 0.4%
        SET v_tax = ROUND(p_amount * 0.004, 2);
    END IF;

    RETURN v_tax;
END //

DELIMITER ;

-- quick checks
-- SELECT CalculateGMFTax(1000000.00, FALSE) AS tax_4x1000; -- expect 4000.00
-- SELECT CalculateGMFTax(1000000.00, TRUE)  AS tax_exempt; -- expect 0.00


-- ---------------------------------------------------------------------------
-- Exercise 2: total withdrawals within a date range
-- READS SQL DATA since it hits the historial_transferencias table
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS GetWithdrawalsTotalByPeriod;

DELIMITER //

CREATE FUNCTION GetWithdrawalsTotalByPeriod(
    p_account_id INT,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_total_withdrawals DECIMAL(12,2);

    -- swapped dates would silently return 0 with BETWEEN, so guard against that
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RETURN 0.00;
    END IF;

    SELECT IFNULL(SUM(monto), 0.00)
    INTO v_total_withdrawals
    FROM historial_transferencias
    WHERE cuenta_origen = p_account_id
      AND estado_transferencia = 'Exitosa'
      AND fecha >= p_start_date AND fecha < p_end_date + INTERVAL 1 DAY;

    RETURN v_total_withdrawals;
END //

DELIMITER ;

-- quick check
-- SELECT GetWithdrawalsTotalByPeriod(1, '2026-01-01', '2026-01-31') AS january_withdrawals;


-- ---------------------------------------------------------------------------
-- Exercise 3: CD (term deposit) return projection using a loop
-- DETERMINISTIC, compound interest year over year
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS ProjectCDInvestmentReturn;

DELIMITER //

CREATE FUNCTION ProjectCDInvestmentReturn(
    p_principal DECIMAL(12,2),
    p_annual_rate DECIMAL(5,2),
    p_years INT
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE v_accumulated DECIMAL(12,2);
    DECLARE v_year_counter INT DEFAULT 1;

    -- nothing to project without a positive term
    IF p_principal IS NULL OR p_years IS NULL OR p_years <= 0 THEN
        RETURN IFNULL(p_principal, 0.00);
    END IF;

    SET v_accumulated = p_principal;

    WHILE v_year_counter <= p_years DO
        SET v_accumulated = ROUND(v_accumulated * (1 + (p_annual_rate / 100.0)), 2);
        SET v_year_counter = v_year_counter + 1;
    END WHILE;

    RETURN v_accumulated;
END //

DELIMITER ;

-- quick check
-- SELECT ProjectCDInvestmentReturn(10000000.00, 10.50, 3) AS projected_capital_3y;


-- ---------------------------------------------------------------------------
-- Exercise 4: credit score evaluation (integrator challenge)
-- READS SQL DATA, pulls balance + withdrawal history and applies the rules
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS EvaluateCreditEligibility;

DELIMITER //

CREATE FUNCTION EvaluateCreditEligibility(
    p_account_id INT
)
RETURNS VARCHAR(30)
READS SQL DATA
BEGIN
    DECLARE v_balance DECIMAL(12,2);
    DECLARE v_total_withdrawals DECIMAL(12,2);
    DECLARE v_result VARCHAR(30);

    SELECT saldo INTO v_balance
    FROM Cuentas
    WHERE id_cuenta = p_account_id;

    -- account doesn't exist, no point checking anything else
    IF v_balance IS NULL THEN
        RETURN 'Account Not Found';
    END IF;

    SELECT IFNULL(SUM(monto), 0.00)
    INTO v_total_withdrawals
    FROM historial_transferencias
    WHERE cuenta_origen = p_account_id;

    -- business rules, in order of priority
    IF v_balance >= 2000000.00 AND v_total_withdrawals <= (v_balance * 2) THEN
        SET v_result = 'Approved';
    ELSEIF v_balance >= 500000.00 AND v_balance < 2000000.00 THEN
        SET v_result = 'Requires Guarantor';
    ELSE
        SET v_result = 'Rejected';
    END IF;

    RETURN v_result;
END //

DELIMITER ;

-- quick check
-- SELECT cuenta_id, titular, saldo, EvaluateCreditEligibility(cuenta_id) AS credit_status FROM Cuentas;
