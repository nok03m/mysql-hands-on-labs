-- Security, permissions and SQL injection prevention workshop
-- Fixed: column-level REVOKE bug, missing TLS on remote user, DB name
-- aligned to BancoDB to match the rest of the series

-- ---------------------------------------------------------------------------
-- Step 0: environment setup (run as root/admin)
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS BancoDB;
USE BancoDB;

CREATE TABLE IF NOT EXISTS cuentas (
    id_cuenta INT PRIMARY KEY AUTO_INCREMENT,
    titular VARCHAR(100) NOT NULL,
    saldo DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    estado VARCHAR(20) DEFAULT 'Activa'
);

CREATE TABLE IF NOT EXISTS historial_transferencias (
    id_transferencia INT AUTO_INCREMENT PRIMARY KEY,
    cuenta_origen INT NOT NULL,
    cuenta_destino INT NOT NULL,
    monto DECIMAL(10, 2) NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cuenta_origen) REFERENCES cuentas(id_cuenta),
    FOREIGN KEY (cuenta_destino) REFERENCES cuentas(id_cuenta)
);

INSERT INTO cuentas (titular, saldo, estado) VALUES
('Carlos Mendoza', 2500000.00, 'Activa'),
('Ana Gómez', 850000.00, 'Activa'),
('Roberto Silva', 120000.00, 'Bloqueada');

-- ---------------------------------------------------------------------------
-- Step 1: drop anonymous accounts, they're a standard attack surface
-- ---------------------------------------------------------------------------
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'%';

-- ---------------------------------------------------------------------------
-- Step 2: role-based users
-- ---------------------------------------------------------------------------
DROP USER IF EXISTS 'admin_banco'@'localhost';
DROP USER IF EXISTS 'cajero_app'@'localhost';
DROP USER IF EXISTS 'auditor_consulta'@'%';
DROP USER IF EXISTS 'app_backend'@'localhost';

-- NOTE: passwords below are placeholders for the exercise only.
-- In production these come from a secrets manager, never hardcoded here.

CREATE USER 'admin_banco'@'localhost'
    IDENTIFIED BY 'AdminBank2026!#'
    PASSWORD EXPIRE INTERVAL 90 DAY;

CREATE USER 'cajero_app'@'localhost'
    IDENTIFIED BY 'CajeroPass2026!'
    PASSWORD EXPIRE INTERVAL 90 DAY;

-- remote user, so TLS is mandatory, not optional
CREATE USER 'auditor_consulta'@'%'
    IDENTIFIED BY 'AuditorPass2026!'
    REQUIRE SSL
    PASSWORD EXPIRE INTERVAL 90 DAY;

CREATE USER 'app_backend'@'localhost'
    IDENTIFIED BY 'AppBackend2026!Sec'
    PASSWORD EXPIRE INTERVAL 90 DAY;

-- ---------------------------------------------------------------------------
-- Step 3: granular privileges
-- ---------------------------------------------------------------------------
-- admin: full control over the bank schema
GRANT ALL PRIVILEGES ON BancoDB.* TO 'admin_banco'@'localhost' WITH GRANT OPTION;

-- backend app: standard DML, no DDL
GRANT SELECT, INSERT, UPDATE ON BancoDB.* TO 'app_backend'@'localhost';

-- teller: column-restricted access on cuentas only
GRANT SELECT (id_cuenta, titular, saldo), UPDATE (saldo)
    ON BancoDB.cuentas TO 'cajero_app'@'localhost';

-- auditor: read-only across the schema
GRANT SELECT ON BancoDB.* TO 'auditor_consulta'@'%';

FLUSH PRIVILEGES;

-- ---------------------------------------------------------------------------
-- Step 4: verify and revoke
-- ---------------------------------------------------------------------------
SHOW GRANTS FOR 'cajero_app'@'localhost';
SHOW GRANTS FOR 'app_backend'@'localhost';

-- the original grant was column-level (saldo only), so the revoke has to
-- match that exact scope, otherwise MySQL won't find a matching privilege
-- to remove and the teller keeps write access to saldo
REVOKE UPDATE (saldo) ON BancoDB.cuentas FROM 'cajero_app'@'localhost';
FLUSH PRIVILEGES;

-- ---------------------------------------------------------------------------
-- Step 5: SQL injection prevention with prepared statements
-- ---------------------------------------------------------------------------
PREPARE stmt_buscar_cuenta FROM
'SELECT id_cuenta, titular, saldo, estado FROM cuentas WHERE id_cuenta = ? AND estado = ?';

SET @id_busqueda = 1;
SET @estado_busqueda = 'Activa';

EXECUTE stmt_buscar_cuenta USING @id_busqueda, @estado_busqueda;

DEALLOCATE PREPARE stmt_buscar_cuenta;
