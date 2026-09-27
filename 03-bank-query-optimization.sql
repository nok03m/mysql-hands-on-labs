-- Query optimization workshop against BancoDB
-- Covers EXPLAIN ANALYZE, sargable rewrites, composite and covering indexes

CREATE DATABASE IF NOT EXISTS BancoDB;
USE BancoDB;

-- helper procedure, just here to generate enough rows to see real timing differences
DELIMITER //
CREATE PROCEDURE CargarDatosPrueba()
BEGIN
    DECLARE i INT DEFAULT 1;

    -- 1,000 accounts
    WHILE i <= 1000 DO
        INSERT INTO cuentas (titular, tipo_cuenta, saldo, estado, fecha_apertura)
        VALUES (
            CONCAT('Cliente_', i),
            IF(i % 2 = 0, 'Ahorros', 'Corriente'),
            ROUND(RAND() * 10000000, 2),
            IF(i % 10 = 0, 'Bloqueada', 'Activa'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 365) DAY)
        );
        SET i = i + 1;
    END WHILE;

    -- 10,000 transfers
    SET i = 1;
    WHILE i <= 10000 DO
        INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto, estado_transferencia, fecha)
        VALUES (
            FLOOR(1 + RAND() * 999),
            FLOOR(1 + RAND() * 999),
            ROUND(1000 + RAND() * 500000, 2),
            IF(i % 15 = 0, 'Fallida', 'Exitosa'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 180) DAY)
        );
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

CALL CargarDatosPrueba();
DROP PROCEDURE IF EXISTS CargarDatosPrueba;


-- ===========================================================================
-- Part 1: in-class walkthrough
-- ===========================================================================

-- looking up transfers by status + date range, no secondary index yet
EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
  AND fecha >= '2026-01-01 00:00:00';

-- expect a full table scan here, cost will be high

CREATE INDEX idx_transf_estado_fecha ON historial_transferencias(estado_transferencia, fecha);

EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
  AND fecha >= '2026-01-01 00:00:00';


-- ===========================================================================
-- Part 2: student exercises
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Exercise 1: non-sargable query (function wrapped around a column)
-- ---------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT *
FROM historial_transferencias
WHERE DATE(fecha) = '2026-02-15';

-- 1. Why isn't idx_transf_estado_fecha used here?
--    Wrapping the column in DATE() forces MySQL to evaluate the function on
--    every row before it can compare, so it can't seek into the index range
--    for 'fecha' anymore. The index exists but becomes unusable for this
--    predicate, so the optimizer falls back to a full scan.

-- 2. Sargable rewrite: use a date range instead of transforming the column
EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, cuenta_destino, monto, estado_transferencia, fecha
FROM historial_transferencias
WHERE fecha >= '2026-02-15 00:00:00'
  AND fecha <  '2026-02-16 00:00:00';

-- 3. Compare plans: the rewritten query can now use idx_transf_estado_fecha
--    (or a dedicated index on fecha) as a range scan instead of scanning the
--    whole table. Also dropped SELECT * in favor of explicit columns.


-- ---------------------------------------------------------------------------
-- Exercise 2: covering index
-- ---------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';

-- 1. SELECT * would pull every column, forcing InnoDB to read the full row
--    from the clustered index (or a bookmark lookup after a secondary index
--    scan). Selecting only the needed columns is what makes a covering
--    index possible in the first place.

-- 2. Covering index: filter column first, then everything the SELECT needs
CREATE INDEX idx_cuentas_estado_covering
    ON cuentas(estado, saldo, tipo_cuenta, titular);

-- 3. Re-run and confirm the plan shows "Using index" (no lookup into the base table)
EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';


-- ---------------------------------------------------------------------------
-- Exercise 3: combined filters + JOIN
-- ---------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
  AND ht.monto > 300000.00;

-- 1. cuentas.estado has no index (until exercise 2's index exists), and
--    historial_transferencias has nothing on cuenta_origen or monto, so
--    whichever table the optimizer picks as the driving side, the other
--    side ends up fully scanned to satisfy the join/filter.

-- 2. Indexes needed for the join + filters:
CREATE INDEX idx_cuentas_estado ON cuentas(estado);
CREATE INDEX idx_transf_origen_monto ON historial_transferencias(cuenta_origen, monto);

-- 3. Column order justification: cuenta_origen is an equality match coming
--    from the join, so it goes first (narrows down to one account's rows
--    immediately); monto is a range filter (> 300000), so it goes second,
--    letting the same index also cover the range scan instead of a separate
--    lookup. cuentas.estado is a simple equality filter, so a single-column
--    index is enough there — id_cuenta is already the primary key, no need
--    to duplicate it.

EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
  AND ht.monto > 300000.00;

-- Note: the original requirement also mentions "last 30 days", which the
-- base query never filtered on. Adding that predicate back in and reusing
-- the same index (extending it to cuenta_origen, fecha, monto if the date
-- filter becomes the norm) would be the next optimization pass.

-- ===========================================================================
-- End of workshop
-- ===========================================================================
