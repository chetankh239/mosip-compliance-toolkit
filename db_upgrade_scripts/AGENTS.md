# AGENTS.md — `db_upgrade_scripts/`

> Versioned upgrade/rollback SQL for existing `mosip_toolkit` deployments.
> Parent guide: [repo root `AGENTS.md`](../AGENTS.md).
> Related: [`db_scripts/AGENTS.md`](../db_scripts/AGENTS.md) (fresh install only).

---

## 1. Purpose

Use this folder to move an **already-deployed** `mosip_toolkit` database between released versions, in either direction (upgrade or rollback). Do not use it to create a database from scratch — that is what [`db_scripts/`](../db_scripts/AGENTS.md) is for.

CI validates this folder via [`.github/workflows/db-test.yml`](../.github/workflows/db-test.yml) (reusable `mosip/kattu` PostgreSQL test workflow), triggered on pushes/PRs that touch `db_scripts/**` — keep both folders consistent for a given schema change.

---

## 2. Layout

```text
db_upgrade_scripts/
├── README.MD
└── mosip_toolkit/
    ├── upgrade.sh              # entry point: terminate connections -> run upgrade or rollback SQL
    ├── upgrade.properties      # DB connection details, ACTION, CURRENT_VERSION, UPGRADE_VERSION
    └── sql/
        ├── 1.1.0_to_1.2.0_upgrade.sql
        ├── 1.1.0_to_1.2.0_rollback.sql
        ├── 1.2.0_to_1.3.0_upgrade.sql
        ├── 1.2.0_to_1.3.0_rollback.sql
        ├── 1.3.0_to_1.4.0_upgrade.sql
        ├── 1.3.0_to_1.4.0_rollback.sql
        ├── 1.4.0_to_1.4.1_upgrade.sql
        ├── 1.4.0_to_1.4.1_rollback.sql
        ├── 1.4.1_to_1.4.2_upgrade.sql
        ├── 1.4.1_to_1.4.2_rollback.sql
        ├── 1.4.2_to_1.4.3_upgrade.sql
        └── 1.4.2_to_1.4.3_rollback.sql
```

Each version step has a matching `_upgrade.sql` / `_rollback.sql` pair — there is no version gap in the current chain (1.1.0 → 1.2.0 → 1.3.0 → 1.4.0 → 1.4.1 → 1.4.2 → 1.4.3).

---

## 3. How to run

```bash
cd db_upgrade_scripts/mosip_toolkit
# edit upgrade.properties: MOSIP_DB_NAME, DB_SERVERIP, DB_PORT, SU_USER_PWD, DBUSER_PWD, ACTION (upgrade|rollback),
# CURRENT_VERSION, UPGRADE_VERSION
./upgrade.sh upgrade.properties
```

`upgrade.sh` reads `upgrade.properties`, terminates active connections to `MOSIP_DB_NAME`, then runs either:

- `sql/${CURRENT_VERSION}_to_${UPGRADE_VERSION}_upgrade.sql` when `ACTION=upgrade`, or
- `sql/${CURRENT_VERSION}_to_${UPGRADE_VERSION}_rollback.sql` when `ACTION=rollback`

and exits non-zero if the corresponding SQL file is missing.

---

## 4. Adding a new version step

1. When a schema change ships in a new release, add a new `sql/<from>_to_<to>_upgrade.sql` (matching whatever DDL changed in [`db_scripts/mosip_toolkit/ddl/`](../db_scripts/AGENTS.md)) **and** a `sql/<from>_to_<to>_rollback.sql` that reverses it.
2. Keep the filename versions exactly matching the `CURRENT_VERSION`/`UPGRADE_VERSION` values a deployer would set in `upgrade.properties` — `upgrade.sh` builds the filename from those two properties.
3. Do not renumber or delete prior version pairs — deployments upgrading from an older release rely on the full chain being present.

---

## 5. Agent rules

### Do

1. Always add both `_upgrade.sql` and `_rollback.sql` for a schema change — never ship one without the other.
2. Mirror any DDL added under [`db_scripts/mosip_toolkit/ddl/`](../db_scripts/AGENTS.md) with an equivalent `ALTER`/`CREATE` step here for existing deployments.
3. Set `ACTION`, `CURRENT_VERSION`, and `UPGRADE_VERSION` in `upgrade.properties` explicitly before running `upgrade.sh` — there are no defaults.
4. Keep this folder's CI-relevant paths (`db_scripts/**`) in mind: `.github/workflows/db-test.yml` runs against `db_scripts/mosip_toolkit`, not this folder directly, so validate upgrade SQL manually against a copy of the target schema version.

### Do not

1. Skip the rollback script — `upgrade.sh` fails fast (`exit 1`) if the file it expects for the requested `ACTION` doesn't exist, and so would a deployer trying to roll back.
2. Point `upgrade.properties` at a production database without a backup — `upgrade.sh` runs SQL directly with `psql -v ON_ERROR_STOP=1`.
3. Break the version chain by skipping a `<from>_to_<to>` pair between two consecutive released versions.

---

*Last updated: 2026-08-10.*
