# AGENTS.md — `db_scripts/`

> Greenfield PostgreSQL install for the `mosip_toolkit` database.
> Parent guide: [repo root `AGENTS.md`](../AGENTS.md).
> Related: [`db_upgrade_scripts/AGENTS.md`](../db_upgrade_scripts/AGENTS.md).

---

## 1. Purpose

Use this folder for **fresh** environments only (sandbox init, empty Postgres). `deploy.sh` **drops** the existing database and role before recreating them — do not run it against a database that must retain data. For an already-deployed environment, use [`db_upgrade_scripts/`](../db_upgrade_scripts/AGENTS.md) instead.

`init_db.sh` runs this deploy automatically inside an existing MOSIP Kubernetes cluster (installs the `postgres-init` Helm chart with `init_values.yaml`).

---

## 2. Layout

```text
db_scripts/
├── README.MD
├── copy_cm_func.sh          # shared helper: copy a configmap/secret across namespaces
├── init_db.sh               # cluster entry point: helm-installs postgres-init with init_values.yaml
├── init_values.yaml         # values for the postgres-init chart (dbUserPasswords.dbuserPassword placeholder)
└── mosip_toolkit/
    ├── deploy.sh             # entry point: drop -> role -> DB -> DDL -> grants -> optional DML
    ├── deploy.properties     # DB_SERVERIP, DB_PORT, MOSIP_DB_NAME, DB_UNAME, DML_FLAG
    ├── db.sql                # CREATE DATABASE
    ├── ddl.sql                # \ir includes of ddl/*.sql
    ├── ddl/                   # per-table DDL (testcase.sql, collections.sql, biometric_scores.sql, ...)
    ├── role_dbuser.sql        # creates the app DB user
    ├── grants.sql             # grants for the app DB user
    ├── drop_db.sql            # destructive reset (used by deploy.sh)
    └── drop_role.sql          # destructive reset (used by deploy.sh)
```

There is a single schema, `mosip_toolkit`. There is no `dml.sql`/`dml/` pair in this repo — `deploy.sh` only runs `dml.sql` when `DML_FLAG=1`, but that file is not currently checked in, so leave `DML_FLAG=0` unless you add one.

---

## 3. How to run

Developer / local run of the raw SQL:

```bash
cd db_scripts/mosip_toolkit
# edit deploy.properties: DB_SERVERIP, DB_PORT, MOSIP_DB_NAME (default mosip_toolkit), DB_UNAME (default toolkituser), DML_FLAG
./deploy.sh deploy.properties
```

`deploy.sh` prompts for `SU_USER_PWD` and `DBUSER_PWD` (or reads them from the environment before invoking `psql`) — it terminates active connections to `MOSIP_DB_NAME`, then drops and recreates the database and role.

Cluster install (existing MOSIP K8s cluster with Postgres already running):

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add mosip https://mosip.github.io/mosip-helm
cd db_scripts
./init_db.sh [kubeconfig]
```

`init_db.sh` prompts for confirmation, then reads the app DB user's password from the `postgres`
namespace's `db-common-secrets` cluster secret and passes it to the chart via `--set
dbUserPasswords.dbuserPassword="$DB_USER_PASSWORD"` — it does **not** read the password from
`init_values.yaml` (that field is commented out there and unused; leave it that way, do not
uncomment and fill it in). It then installs/reinstalls the `postgres-init-toolkit` Helm release in
the `compliance-toolkit` namespace, overwriting any existing `mosip_toolkit` DB — back it up first
if it holds real data.

---

## 4. Adding schema changes

1. Add/edit DDL under `mosip_toolkit/ddl/` (one file per table or FK set — see `ddl/fk.sql` for cross-table foreign keys).
2. Wire the new file into `mosip_toolkit/ddl.sql` via `\ir ddl/<file>.sql`.
3. If the change ships to an already-deployed environment, add a matching upgrade (and rollback) pair in [`db_upgrade_scripts/`](../db_upgrade_scripts/AGENTS.md) — this folder alone is not sufficient for upgrading a live deployment.

---

## 5. Agent rules

### Do

1. Keep new tables under `mosip_toolkit/ddl/` **and** wire them into `mosip_toolkit/ddl.sql` — a file that exists but isn't `\ir`-included is never applied.
2. Set `deploy.properties` (and the superuser/app-user passwords) before running `deploy.sh`.
3. Pair every schema change here with a corresponding entry in `db_upgrade_scripts/` for upgrading existing deployments.
4. Let `init_db.sh` inject the DB user password via `--set` from the `postgres` namespace's `db-common-secrets` — leave `init_values.yaml`'s `dbUserPasswords.dbuserPassword` commented out.

### Do not

1. Run `deploy.sh` or `init_db.sh` against a database that must retain data — both drop the existing DB/role unconditionally.
2. Commit real credentials into `deploy.properties` or `init_values.yaml`.
3. Skip the `db_upgrade_scripts/` companion when a DDL change needs to reach an already-running environment.

---

*Last updated: 2026-08-10.*
