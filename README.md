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
| 01 | `01-secure-bank-transfer-stored-procedures/` | Stored procedures, `START TRANSACTION` / `COMMIT` / `ROLLBACK`, `DECLARE HANDLER`, `SELECT ... FOR UPDATE` |
| 02 | `02-bank-stored-routines.sql` | User-defined functions (`DETERMINISTIC` vs `READS SQL DATA`), control flow, `WHILE` loops |
| 03 | `03-bank-query-optimization.sql` | `EXPLAIN ANALYZE`, sargable predicates, composite and covering indexes |
| 04 | `04-bank-security-permissions.sql` | Users, roles, column-level `GRANT`/`REVOKE`, prepared statements against SQL injection |
| 05 | `05-bank-triggers-events.sql` | `AFTER`/`BEFORE` triggers, `SIGNAL SQLSTATE`, scheduled `EVENT`s |

## Conventions used across labs

- Table and column names stay in Spanish (`cuentas`, `historial_transferencias`, `saldo`) since they model a Spanish-speaking bank — comments and identifiers you write (procedures, functions, indexes) are in English.
- Every script is idempotent where possible (`DROP ... IF EXISTS` before `CREATE`), so you can re-run a file without cleaning up by hand first.
- Money always uses `DECIMAL`, never `FLOAT` — rounding errors on currency are not a hypothetical.

## Setting up the schema

Each lab that needs `BancoDB` creates it with `CREATE DATABASE IF NOT EXISTS`, so you can run any file directly. If you're starting fresh, run lab 01 first to get the base `cuentas` and `historial_transferencias` tables in place.

## Notes on security labs (04)

The credentials in that script are placeholders for the exercise only — never reuse them anywhere real. In production, secrets come from a vault or environment-based secret manager, not a hardcoded `CREATE USER` statement.

## Contributing / feedback

This is a personal learning repo. Issues and suggestions are welcome, but treat the reference solutions as a starting point to argue with, not gospel — there's often more than one reasonable way to index a query.
