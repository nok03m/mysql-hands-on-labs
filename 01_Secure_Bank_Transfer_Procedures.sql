-- Bank transfer challenge - stored procedure with transactions and error handling
-- Tested on MySQL 8.0, InnoDB

-- setting up the database
CREATE DATABASE IF NOT EXISTS BancoDB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE BancoDB;

-- test accounts
INSERT INTO cuentas (id_cuenta, titular, saldo) VALUES
    (1, 'Ana López', 5000.00),
    (2, 'Carlos Pérez', 3000.00);

-- Main procedure. Handles the whole transfer flow: validates the amount,
-- locks both accounts, checks balance, moves the money and logs everything.
-- Includes the extra requirements from the challenge (amount > 0 check,
-- 401 code, returning the source account holder's name, and who triggered it).
DROP PROCEDURE IF EXISTS TransferirFondos;

DELIMITER $$

CREATE PROCEDURE TransferirFondos (
    IN  p_origen              INT,
    IN  p_destino             INT,
    IN  p_monto               DECIMAL(10,2),
    IN  p_usuario_responsable VARCHAR(100),
    OUT p_codigo_respuesta    INT,
    OUT p_titular_origen      VARCHAR(100)
)
proc_body: BEGIN
    DECLARE v_saldo_origen DECIMAL(10,2);
    DECLARE v_titular_origen VARCHAR(100);
    DECLARE v_existe_origen INT DEFAULT 0;
    DECLARE v_existe_destino INT DEFAULT 0;

    -- if anything unexpected blows up mid-transaction, roll back and return 500
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_codigo_respuesta = 500;
        SET p_titular_origen = v_titular_origen;
    END;

    -- reject zero, negative or null amounts before even opening a transaction
    IF p_monto IS NULL OR p_monto <= 0 THEN
        SET p_codigo_respuesta = 401;
        SET p_titular_origen = NULL;
        LEAVE proc_body;
    END IF;

    START TRANSACTION;

    -- Lock accounts in ascending order by ID to prevent deadlocks
    IF p_origen < p_destino THEN
        -- Lock origin first (lower ID)
        SELECT saldo, titular
            INTO v_saldo_origen, v_titular_origen
            FROM cuentas
            WHERE id_cuenta = p_origen
            FOR UPDATE;

        SET v_existe_origen = ROW_COUNT();

        -- Then lock destination
        SELECT COUNT(*) INTO v_existe_destino
            FROM cuentas
            WHERE id_cuenta = p_destino
            FOR UPDATE;
    ELSE
        -- Lock destination first (lower ID)
        SELECT COUNT(*) INTO v_existe_destino
            FROM cuentas
            WHERE id_cuenta = p_destino
            FOR UPDATE;

        -- Then lock origin and get its balance/owner
        SELECT saldo, titular
            INTO v_saldo_origen, v_titular_origen
            FROM cuentas
            WHERE id_cuenta = p_origen
            FOR UPDATE;

        SET v_existe_origen = ROW_COUNT();
    END IF;

    IF v_existe_origen = 0 OR v_existe_destino = 0 THEN
        ROLLBACK;
        SET p_codigo_respuesta = 400;
        SET p_titular_origen = v_titular_origen;
        LEAVE proc_body;
    END IF;

    -- not enough money, bail out
    IF v_saldo_origen < p_monto THEN
        ROLLBACK;
        SET p_codigo_respuesta = 400;
        SET p_titular_origen = v_titular_origen;
        LEAVE proc_body;
    END IF;

    -- move the funds
    UPDATE cuentas SET saldo = saldo - p_monto WHERE id_cuenta = p_origen;
    UPDATE cuentas SET saldo = saldo + p_monto WHERE id_cuenta = p_destino;

    -- log it for the audit trail
    INSERT INTO historial_transferencias
        (cuenta_origen, cuenta_destino, monto, codigo_respuesta, usuario_responsable)
    VALUES
        (p_origen, p_destino, p_monto, 200, p_usuario_responsable);

    COMMIT;

    SET p_codigo_respuesta = 200;
    SET p_titular_origen = v_titular_origen;
END proc_body $$

DELIMITER ;


-- =====================================================================
-- Queries (steps 4, 5 and 6 from the assignment)
-- =====================================================================

-- successful transfer
CALL TransferirFondos(1, 2, 1000, 'admin_juan', @codigo, @titular);
SELECT @codigo AS codigo_respuesta, @titular AS titular_origen;
SELECT * FROM cuentas;

-- failed transfer, not enough balance
CALL TransferirFondos(1, 2, 10000, 'admin_juan', @codigo, @titular);
SELECT @codigo AS codigo_respuesta, @titular AS titular_origen;

-- invalid amount, should hit the 401 branch
CALL TransferirFondos(1, 2, -50, 'admin_juan', @codigo, @titular);
SELECT @codigo AS codigo_respuesta, @titular AS titular_origen;

-- audit trail, check everything got logged
SELECT * FROM historial_transferencias ORDER BY fecha DESC;