-- Triggers and events workshop against BancoDB
-- Covers reactive triggers (real-time) and scheduled events (background jobs)

USE BancoDB;

-- ---------------------------------------------------------------------------
-- Part 0: supporting tables
-- ---------------------------------------------------------------------------

-- balance change audit trail, feeds the trigger below
CREATE TABLE IF NOT EXISTS auditoria_saldos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_cuenta INT NOT NULL,
    saldo_anterior DECIMAL(10,2) NOT NULL,
    saldo_nuevo DECIMAL(10,2) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cuenta) REFERENCES cuentas(id_cuenta)
);

-- daily consolidated metrics, feeds the event below
CREATE TABLE IF NOT EXISTS metricas_diarias (
    id_metrica INT AUTO_INCREMENT PRIMARY KEY,
    fecha_metrica DATE NOT NULL,
    total_cuentas INT NOT NULL,
    saldo_total_sistema DECIMAL(12,2) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- events won't fire if this is off
SET GLOBAL event_scheduler = ON;

-- ===========================================================================
-- Part 1: in-class walkthrough
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1.1 Trigger demo: auto-audit balance changes
-- AFTER UPDATE on cuentas, captures OLD vs NEW
-- ---------------------------------------------------------------------------

DELIMITER //

DROP TRIGGER IF EXISTS trg_auditar_cambio_saldo //

CREATE TRIGGER trg_auditar_cambio_saldo
AFTER UPDATE ON cuentas
FOR EACH ROW
BEGIN
    -- only log when the balance actually changed
    IF OLD.saldo <> NEW.saldo THEN
        INSERT INTO auditoria_saldos (
            id_cuenta,
            saldo_anterior,
            saldo_nuevo,
            usuario
        )
        VALUES (
            NEW.id_cuenta,
            OLD.saldo,
            NEW.saldo,
            USER()
        );
    END IF;
END //

DELIMITER ;

-- try it:
-- UPDATE cuentas SET saldo = saldo + 500.00 WHERE id_cuenta = 1;
-- SELECT * FROM auditoria_saldos;


-- ---------------------------------------------------------------------------
-- 1.2 Event demo: periodic bank metrics summary
-- recurring, runs on its own schedule, no user interaction needed
-- ---------------------------------------------------------------------------

DELIMITER //

DROP EVENT IF EXISTS evt_registrar_metricas_diarias //

CREATE EVENT evt_registrar_metricas_diarias
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Consolida el saldo total y cantidad de cuentas activas diariamente'
DO
BEGIN
    INSERT INTO metricas_diarias (fecha_metrica, total_cuentas, saldo_total_sistema)
    SELECT
        CURDATE(),
        COUNT(id_cuenta),
        IFNULL(SUM(saldo), 0.00)
    FROM cuentas
    WHERE estado = 'Activa';
END //

DELIMITER ;

-- try it:
-- SHOW EVENTS FROM BancoDB;
-- SELECT * FROM metricas_diarias;


-- ===========================================================================
-- Part 2: student exercises
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Exercise 1 (trigger): validate transfers before they're inserted
-- Rules: amount must be > 0, origin and destination account can't match
-- ---------------------------------------------------------------------------

DELIMITER //

DROP TRIGGER IF EXISTS trg_validar_transferencia //

CREATE TRIGGER trg_validar_transferencia
BEFORE INSERT ON historial_transferencias
FOR EACH ROW
BEGIN
    IF NEW.monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto de la transferencia debe ser mayor a cero';
    END IF;

    IF NEW.cuenta_origen = NEW.cuenta_destino THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta de origen y destino no pueden ser iguales';
    END IF;
END //

DELIMITER ;

-- try it:
-- INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto) VALUES (1, 1, 100.00); -- should fail
-- INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto) VALUES (1, 2, -50.00); -- should fail
-- INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto) VALUES (1, 2, 100.00); -- should pass


-- ---------------------------------------------------------------------------
-- Exercise 2 (event): auto-deactivate zero-balance accounts
-- runs daily, flips 'Activa' accounts with saldo = 0.00 to 'Inactiva'
-- ---------------------------------------------------------------------------

DELIMITER //

DROP EVENT IF EXISTS evt_inactivar_cuentas_vacias //

CREATE EVENT evt_inactivar_cuentas_vacias
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Marca como Inactiva toda cuenta Activa con saldo en cero'
DO
BEGIN
    UPDATE cuentas
    SET estado = 'Inactiva'
    WHERE saldo = 0.00
      AND estado = 'Activa';
END //

DELIMITER ;

-- try it: (events aren't callable, either wait for the schedule or
-- temporarily set it to "EVERY 1 MINUTE" while testing)
-- SHOW EVENTS FROM BancoDB;
-- UPDATE cuentas SET saldo = 0.00 WHERE id_cuenta = 2;
-- SELECT * FROM cuentas WHERE id_cuenta = 2; -- estado should flip to 'Inactiva' after the event runs
