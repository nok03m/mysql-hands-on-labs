# MySQL Hands-On Labs

Practical MySQL workshops built around a single running example: **BancoDB**, a small banking schema. Each lab adds a new layer — stored procedures, functions, indexing, security, triggers and events — on top of the same accounts/transfers tables, so you build real depth instead of five disconnected demos.

## Who this is for

You already know basic SQL (SELECT, JOIN, INSERT/UPDATE) and want to get comfortable with the parts of MySQL that show up in real production systems: transactions that can't half-fail, query plans, access control, and background automation.

## Prerequisites

- MySQL 8.0+ (some labs use `EXPLAIN ANALYZE`, which needs 8.0.18+)
- A client to run scripts: MySQL Workbench, DBeaver, or the `mysql` CLI
- Comfortable running a `.sql` file top to bottom and reading its output

## How to use this repo

1. Clone it and open a lab file in order — each one assumes the schema from the previous ones already exists.
2. Read the comments before running a block. Most labs mix demo code (already solved, meant to be studied) with exercises left for you to complete.
3. Run statements incrementally, not the whole file blindly — several labs are designed to show a "before" and "after" (e.g. a slow query, then an index, then the same query again).
4. Compare your solution against the reference one only after attempting it yourself.

## Labs

| # | File | Topic |
|---|------|-------|
| 00 | `00_init_schema.sql` | Base schema setup: `cuentas` and `historial_transferencias` tables |
| 01 | `01_Secure_Bank_Transfer_Procedures.sql` | Stored procedures, `START TRANSACTION` / `COMMIT` / `ROLLBACK`, `DECLARE HANDLER`, `SELECT ... FOR UPDATE`, deadlock prevention |
| 02 | `02-bank-stored-routines.sql` | User-defined functions (`DETERMINISTIC` vs `READS SQL DATA`), control flow, `WHILE` loops |
| 03 | `03-bank-query-optimization.sql` | `EXPLAIN ANALYZE`, sargable predicates, composite and covering indexes |
| 04 | `04-bank-security-permissions.sql` | Users, roles, column-level `GRANT`/`REVOKE`, prepared statements against SQL injection |
| 05 | `05-bank-triggers-events.sql` | `AFTER`/`BEFORE` triggers, `SIGNAL SQLSTATE`, scheduled `EVENT`s |

## Conventions used across labs

- Table and column names stay in Spanish (`cuentas`, `historial_transferencias`, `saldo`) since they model a Spanish-speaking bank — comments and identifiers you write (procedures, functions, indexes) are in English.
- Every script is idempotent where possible (`DROP ... IF EXISTS` before `CREATE` for procedures, functions, triggers, and events), so you can re-run a file without cleaning up by hand first. Labs 01–05 intentionally omit base table creation to avoid redundancy.
- Money always uses `DECIMAL`, never `FLOAT` — rounding errors on currency are not a hypothetical.

## Setting up the schema

Each lab that needs `BancoDB` creates it with `CREATE DATABASE IF NOT EXISTS`, so you can run any file directly. Labs 01–05 assume the base `cuentas` and `historial_transferencias` tables already exist; run `00_init_schema.sql` first to create them, then proceed with the workshops.

## Notes on security labs (04)

The credentials in that script are placeholders for the exercise only — never reuse them anywhere real. In production, secrets come from a vault or environment-based secret manager, not a hardcoded `CREATE USER` statement.

## Notes on events labs (05)

MySQL's event scheduler must be enabled for scheduled events to run:
```sql
SET GLOBAL event_scheduler = ON;
```

## Contributing / feedback

This is a personal learning repo. Issues and suggestions are welcome, but treat the reference solutions as a starting point to argue with, not gospel — there's often more than one reasonable way to index a query.
