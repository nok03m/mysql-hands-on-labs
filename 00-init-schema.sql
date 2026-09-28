-- 00_init_schema.sql
-- Unified Master Schema for BancoDB
-- This script consolidates all table definitions to resolve structural collisions 
-- and ensure sequential execution of the workshop scripts.

CREATE DATABASE IF NOT EXISTS BancoDB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE BancoDB;

-- 1. Drop tables in correct dependency order
DROP TABLE IF EXISTS auditoria_saldos;
DROP TABLE IF EXISTS metricas_diarias;
DROP TABLE IF EXISTS historial_transferencias;
DROP TABLE IF EXISTS cuentas;

-- 2. Master Table: Cuentas
-- Consolidates all required columns from scripts 01, 03, 04, and 06
CREATE TABLE cuentas (
    id_cuenta INT PRIMARY KEY AUTO_INCREMENT,
    titular VARCHAR(100) NOT NULL,
    tipo_cuenta VARCHAR(20) NOT NULL DEFAULT 'Ahorros',
    saldo DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    estado VARCHAR(20) NOT NULL DEFAULT 'Activa',
    fecha_apertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_saldo_no_negativo CHECK (saldo >= 0)
) ENGINE = InnoDB;

-- 3. Master Table: historial_transferencias (Replacing 'Transacciones')
-- Consolidates columns from 01 (audit codes), 03 (status), and 04 (standard FKs)
-- Also includes 'tipo_transaccion' required by routines in script 02.
CREATE TABLE historial_transferencias (
    id_transferencia INT AUTO_INCREMENT PRIMARY KEY,
    cuenta_origen INT NOT NULL,
    cuenta_destino INT NOT NULL,
    monto DECIMAL(12, 2) NOT NULL,
    tipo_transaccion VARCHAR(20) NOT NULL DEFAULT 'Transferencia', -- Required for Script 02
    estado_transferencia VARCHAR(20) NOT NULL DEFAULT 'Exitosa', -- Required for Script 03
    codigo_respuesta INT NULL, -- Required for Script 01
    usuario_responsable VARCHAR(100) NULL, -- Required for Script 01
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_hist_cuenta_origen FOREIGN KEY (cuenta_origen) REFERENCES cuentas(id_cuenta),
    CONSTRAINT fk_hist_cuenta_destino FOREIGN KEY (cuenta_destino) REFERENCES cuentas(id_cuenta)
) ENGINE = InnoDB;

-- Indexes for performance (from Script 01)
CREATE INDEX idx_hist_cuenta_origen ON historial_transferencias(cuenta_origen);
CREATE INDEX idx_hist_cuenta_destino ON historial_transferencias(cuenta_destino);

-- 4. Initial Seed Data
-- These accounts are used across all labs (01-05). Do not modify or delete them.
INSERT INTO cuentas (titular, saldo, estado, tipo_cuenta) VALUES
('Carlos Mendoza', 2500000.00, 'Activa', 'Ahorros'),
('Ana Gómez', 850000.00, 'Activa', 'Corriente'),
('Roberto Silva', 120000.00, 'Bloqueada', 'Ahorros'),
('Ana López', 5000.00, 'Activa', 'Ahorros'),
('Carlos Pérez', 3000.00, 'Activa', 'Corriente');