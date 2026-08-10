# AGENTS.md

## Repository Overview

This repository contains the source code for **MOSIP Compliance Toolkit** (CTK), a Spring Boot REST API microservice used to test MOSIP-compatible biometric components before they are certified as compliant partners. It supports three project types:

- **SDK** — Biometric algorithm SDKs (quality check, match, extract, segment operations)
- **SBI** — Sensor Biometric Interface devices (physical capture hardware)
- **ABIS** — Automated Biometric Identification Systems

The general workflow exposed by the API is: create a project → create a collection of test cases → upload biometric test data → run tests → generate a report → submit for admin review → get approved/rejected.

A reference front-end UI lives in a separate repository: [mosip-compliance-toolkit-ui](https://github.com/mosip/mosip-compliance-toolkit-ui). This repository only contains the backend service, database scripts, and helm charts.

For a broader overview of the product, see the [MOSIP compliance toolkit docs](https://docs.mosip.io/compliance-tool-kit).

## Guide index

| Area | Path | Guide |
|------|------|-------|
| **Java / Maven** (Spring Boot service) | `mosip-compliance-toolkit/` | [`mosip-compliance-toolkit/CLAUDE.md`](mosip-compliance-toolkit/CLAUDE.md) — own file, not duplicated here |
| Fresh DB install (DDL) | `db_scripts/` | [`db_scripts/AGENTS.md`](db_scripts/AGENTS.md) |
| Version upgrade/rollback SQL | `db_upgrade_scripts/` | [`db_upgrade_scripts/AGENTS.md`](db_upgrade_scripts/AGENTS.md) |
| K8s Helm chart + cluster install scripts | `helm/` | [`helm/AGENTS.md`](helm/AGENTS.md) |
| Test/schema assets (no build) | `resources/` | none — reference assets only, see [`resources/ReadMe.md`](resources/ReadMe.md) |

## Repository layout (repo root)

```text
mosip-compliance-toolkit/          # git repo root (this AGENTS.md)
├── mosip-compliance-toolkit/      # Spring Boot Maven module → mosip-compliance-toolkit/CLAUDE.md
├── db_scripts/                    # Greenfield DB create → db_scripts/AGENTS.md
├── db_upgrade_scripts/            # Incremental upgrades → db_upgrade_scripts/AGENTS.md
├── helm/                          # Kubernetes Helm chart + install scripts → helm/AGENTS.md
├── resources/                     # JSON schemas / test data assets (no build)
└── .github/workflows/             # CI: push-trigger.yml, db-test.yml, chart-lint-publish.yml, verify-keycloak-init.yml
```

## Technology Stack

- **Language / Runtime:** Java 11, built with Maven
- **Framework:** Spring Boot 2.0.2 (Spring Web, Spring Data JPA, Spring Security, Spring Cloud Config Client)
- **Database:** PostgreSQL (`mosip_toolkit` schema) in production; H2 in-memory for tests
- **Object storage:** MinIO S3 (biometric test data ZIPs, uploaded resources)
- **IAM:** Keycloak (JWT/OAuth2), integrated via MOSIP's Auth Adapter
- **Reporting:** Apache Velocity templates rendered to HTML, converted to PDF via Flying Saucer
- **Config:** Spring Cloud Config Server (properties are externalized, not committed to this repo)
- **CI:** GitHub Actions, delegating build/test/publish/docker/sonar steps to reusable workflows in `mosip/kattu`
- **Deployment:** Helm charts under `helm/`, Docker image built from `mosip-compliance-toolkit/Dockerfile`

## Build & Test Commands

The Maven module lives in `mosip-compliance-toolkit/` (not the repo root — the root has no top-level `pom.xml`).

```shell
cd mosip-compliance-toolkit

# Full build with tests
mvn clean install

# Build/package without running tests (matches CI publish behavior, gpg signing skipped for local builds)
mvn clean package -Dgpg.skip=true -DskipTests

# Run the service locally (listens on port 8099, context path /v1/toolkit)
mvn spring-boot:run

# Run all tests
mvn test

# Run a single test class
mvn -Dtest=ClassName test

# Run a single test method
mvn -Dtest=ClassName#methodName test

# Run SonarQube analysis (requires SONAR_TOKEN; -D system properties go before the goal, not after)
mvn -Dsonar.host.url=https://sonarcloud.io -Psonar verify
```

Build a Docker image for the service:

```shell
cd mosip-compliance-toolkit
docker build -f Dockerfile .
```

Tests live under `mosip-compliance-toolkit/src/test/java/io/mosip/compliance/toolkit/`. Controller tests use `@WebMvcTest` with mocked services and a mocked `SecurityContext`; service tests use `@SpringBootTest` or Mockito unit tests with H2 for persistence. JaCoCo coverage excludes DTOs, entities, constants, config, repositories, and HTTP filters (see `sonar.coverage.exclusions` in `mosip-compliance-toolkit/pom.xml`).

A detailed API and architecture reference already exists at [`mosip-compliance-toolkit/CLAUDE.md`](mosip-compliance-toolkit/CLAUDE.md) — consult it for the full controller/endpoint list, service layer responsibilities, domain entities, and configuration namespaces instead of duplicating that detail here.

## Configuration

- Runtime configuration (`application.properties`) is loaded from a **Spring Cloud Config Server** at startup, pointed to by `mosip-compliance-toolkit/src/main/resources/bootstrap.properties` (`spring.cloud.config.uri`, `spring.cloud.config.label`, `spring.cloud.config.name=compliance-toolkit`).
- Any property in `application.properties` can be overridden centrally via `compliance-toolkit-default.properties` in the [mosip-config](https://github.com/mosip/mosip-config) repository — do not hardcode environment-specific values in this repo's `application.properties`.
- Database setup uses scripts under `db_scripts/` (see [`db_scripts/README.MD`](db_scripts/README.MD)). `db_scripts/init_values.yaml` contains a `dbUserPasswords.dbuserPassword` placeholder that must be filled in locally from the cluster's Postgres secret and **never committed with a real value**.
- Helm-based deployment lives under `helm/compliance-toolkit/`, with `keycloak-init.sh`, `install.sh`, `restart.sh`, and `delete.sh` scripts.
- Never commit real credentials, tokens, or secrets into `compliance-toolkit-default.properties`, `db_scripts/init_values.yaml`, or any helm `values.yaml` override — these are meant to be filled in per-environment outside of version control.

## Project Structure Notes

- `mosip-compliance-toolkit/` — the actual Spring Boot Maven module (source, tests, Dockerfile, pom.xml). This is the directory CI builds (`SERVICE_LOCATION: ./mosip-compliance-toolkit`).
- `db_scripts/` — PostgreSQL DDL/DML scripts and install tooling for the `mosip_toolkit` database. See [`db_scripts/AGENTS.md`](db_scripts/AGENTS.md).
- `db_upgrade_scripts/` — versioned upgrade/rollback scripts for existing deployments. See [`db_upgrade_scripts/AGENTS.md`](db_upgrade_scripts/AGENTS.md).
- `helm/` — Helm chart and install/restart/delete scripts for deploying to a MOSIP Kubernetes cluster. See [`helm/AGENTS.md`](helm/AGENTS.md).
- `resources/` — supporting static resources checked into the repo (schemas/templates used at build or runtime).
- Within `mosip-compliance-toolkit/src/main/java/io/mosip/compliance/toolkit/`, the layering is `controllers/ → service/ → repository/ → entity/`, with `validators/` (JSON schema validation), `util/` (helpers), and `dto/` (request/response objects) alongside. See `mosip-compliance-toolkit/CLAUDE.md` for the full breakdown.

## Development Workflow

- Default integration branch is `develop`; release branches follow `release-<version>` naming (e.g. `release-1.4.x`).
- CI (`.github/workflows/push-trigger.yml`) triggers on pushes to `develop`, `master`, `release-1*`, `0.*`, `1.*`, and `MOSIP*` branches, and on pull requests. It runs a Maven build, then (branch-dependent) publishes to Nexus, builds Docker images, and runs SonarCloud analysis — all via reusable workflows in `mosip/kattu`.
- Other workflows: `.github/workflows/db-test.yml` (database script validation), `.github/workflows/chart-lint-publish.yml` (Helm chart lint/publish), `.github/workflows/verify-keycloak-init.yml` (keycloak-init script check).
- Before opening a PR, run `mvn clean install` from `mosip-compliance-toolkit/` to make sure the build and tests pass locally — CI will run the same Maven build via the shared `mosip/kattu` workflow.

## Pull Request Guidelines

- Target the `develop` branch unless the change is specifically a backport/fix for a release branch.
- Keep changes scoped to the module they touch (`mosip-compliance-toolkit/`, `db_scripts/`, `db_upgrade_scripts/`, or `helm/`) — cross-cutting changes should call out why in the PR description.
- If a change affects the database schema, add both the DDL/DML under `db_scripts/mosip_toolkit/` and a corresponding upgrade script under `db_upgrade_scripts/`.
- If a change affects API request/response contracts, check whether the reference UI ([mosip-compliance-toolkit-ui](https://github.com/mosip/mosip-compliance-toolkit-ui)) needs a corresponding update, and note that in the PR description.
- Sign off commits (`git commit -s`) per MOSIP contribution conventions.

## Repository-Specific Considerations

- The repo root has no `pom.xml`; all Maven/build commands must be run from inside `mosip-compliance-toolkit/`.
- `mosip-compliance-toolkit/CLAUDE.md` already documents the full REST API surface, service layer, domain entities, and configuration namespaces in depth — treat it as the source of truth for architectural detail and keep it in sync with code changes rather than re-documenting the same information here.
- Configuration values are resolved from an external Config Server at runtime; do not assume `application.properties` in this repo reflects what a deployed environment actually uses.
- `docker build -f Dockerfile .` must be run from within `mosip-compliance-toolkit/` (the Dockerfile expects the module's build context), not from the repo root.
