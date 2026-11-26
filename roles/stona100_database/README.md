# StoNa100 PostgreSQL Infrastructure and Migration

## Overview

The `stona100_database` Ansible role provisions,
secures and validates a dedicated PostgreSQL
database environment for the StoNa100 application.

The role also implements a controlled migration
from SQLite v0.7 to PostgreSQL v0.8.

The implementation follows the principles of:

- Infrastructure as Code.
- Least privilege.
- Separation of responsibilities.
- Network isolation.
- Transactional database migrations.
- Artifact integrity verification.
- Idempotent configuration management.
- Independent post-deployment validation.
- Protection of private application data.

The initial PostgreSQL migration was successfully
committed on 2026-11-26.

## Environment

| Component | Value |
|---|---|
| Ansible controller | macOS / Apple Silicon |
| Controller address | 192.168.64.1 |
| Database server | database01 |
| Database server OS | Debian 13 |
| PostgreSQL version | 17.11 |
| PostgreSQL address | 192.168.64.20 |
| PostgreSQL port | 5432 |
| Application server | rhel01 |
| Application server address | 192.168.64.16 |
| Database | stona100 |
| Schema | stona100 |
| Encoding | UTF8 |
| Locale | pl_PL.UTF-8 |
| Source database | SQLite v0.7 |
| Target database release | PostgreSQL v0.8 |
| Migration version | 800 |

## Database roles

| Role | Purpose |
|---|---|
| stona100_owner | Non-login database and schema owner |
| stona100_migrator | Dedicated migration account |
| stona100_app | Application runtime account |
| stona100_readonly | Read-only audit account |

The migration account does not automatically
inherit owner privileges.

Database migrations require an explicit
role transition:

```sql
SET ROLE stona100_owner;
```

All migrated database objects are owned by
`stona100_owner`.

Application and read-only accounts cannot
assume the owner role.

## Security model

- Dedicated application database and schema.
- Restricted database-level privileges.
- Removal of unnecessary PUBLIC privileges.
- SCRAM-SHA-256 password authentication.
- Mandatory TLS for authorized remote connections.
- Source IP restrictions.
- Explicit HBA rejection rules.
- Cross-database connection isolation.
- Unix socket and loopback connection restrictions.
- Database-specific search_path configuration.
- Object-level access control.
- Default-deny privileges for future objects.
- Password management using Ansible Vault.
- Sensitive task output protected using no_log.

## Network access policy

| Source | Database role | TLS | Access |
|---|---|---|---|
| Ansible controller | stona100_migrator | Required | Allow |
| Ansible controller | stona100_readonly | Required | Allow |
| Application server | stona100_app | Required | Allow |

Other ordinary connection attempts using
StoNa100 login accounts are explicitly rejected.

Existing ansible_lab connectivity remains
operational.

## PostgreSQL HBA configuration

The existing `postgresql` role supports ordered
HBA rule groups.

```yaml
postgresql_prepend_hba_rules: []
postgresql_extra_hba_rules: []
```

Rules are evaluated in the following order:

1. Prepend rules.
2. Standard PostgreSQL rules.
3. Extra application-specific rules.

Automatic sorting is disabled to preserve
the intended evaluation order.

| Rule category | Count |
|---|---:|
| StoNa100 TLS allow rules | 3 |
| StoNa100 explicit reject rules | 9 |
| Standard PostgreSQL rules | 7 |
| Existing ansible_lab rules | 5 |
| Total | 24 |

HBA changes are validated before requesting
a PostgreSQL configuration reload.

A backup of the previous HBA configuration
is retained for recovery purposes.

## Session configuration

All three StoNa100 login roles use the
following database-specific search path:

```sql
SET search_path TO stona100;
```

The implementation checks `pg_db_role_setting`
before applying changes.

The migrator must explicitly assume the owner
role before accessing application objects.

## Application permissions

| Object category | Application | Read-only |
|---|---|---|
| Regular catalog tables | SELECT | SELECT |
| User data tables | SELECT, INSERT, UPDATE, DELETE | SELECT |
| Application views | SELECT | SELECT |
| Archived source emails | Denied | SELECT |
| Migration history | Denied | SELECT |
| Identity sequences | USAGE | Denied |
| Direct execution of trigger functions | Denied | Denied |
| Schema CREATE | Denied | Denied |
| SET ROLE owner | Denied | Denied |

The application account can modify only
nine explicitly authorized user data tables.

Archived source correspondence is not directly
accessible to the application account.

Future database objects use a default-deny
privilege policy.

## Required Vault variables

The following variables must be defined
in the encrypted Ansible Vault:

```yaml
vault_stona100_db_migrator_password:
vault_stona100_db_app_password:
vault_stona100_db_readonly_password:
```

Actual credentials must never be stored in
documentation or unencrypted inventory files.

## Role structure

```text
roles/stona100_database/
├── README.md
├── defaults/
│   └── main.yml
└── tasks/
    ├── main.yml
    ├── preflight.yml
    ├── roles.yml
    ├── validation.yml
    ├── database.yml
    ├── schema.yml
    ├── session.yml
    ├── migration.yml
    └── permissions.yml
```

The migration task executes the approved
transactional migration procedure.

The permissions task performs an independent
post-migration audit.

It does not automatically repair or reapply ACLs.

## Infrastructure deployment

Configure PostgreSQL and application-specific
HBA rules:

```bash
ansible-playbook \
    -i inventory/notebook.ini \
    postgresql_role.yml \
    --limit database01
```

Provision the StoNa100 database environment:

```bash
ansible-playbook \
    -i inventory/notebook.ini \
    stona100_database.yml \
    --limit database01
```

Validate the expected configuration without
applying changes:

```bash
ansible-playbook \
    -i inventory/notebook.ini \
    stona100_database.yml \
    --limit database01 \
    --check
```

Migration is disabled during ordinary
infrastructure provisioning.

## Migration safety switches

```yaml
stona100_migration_enabled: false
stona100_migration_commit: false
```

| Enabled | Commit | Behaviour |
|---|---|---|
| false | false | Infrastructure provisioning |
| true | false | Transactional dry run |
| true | true | Apply approved migration |
| false | true | Rejected |

Migration execution in Ansible check mode
is explicitly rejected.

## Private migration artifacts

The migration artifacts are maintained outside
the public infrastructure repository.

Default project location:

```text
~/projects/stona100_v02/
```

Relevant structure:

```text
stona100_v02/
├── backups/
├── exports/
│   └── postgresql-v080/
├── postgresql/
│   ├── 001_tables_indexes.sql
│   ├── 002_views.sql
│   ├── 003_functions.sql
│   ├── 004_triggers.sql
│   ├── 005_migration_history.sql
│   ├── 006_validate_data.sql
│   ├── 010_permissions.sql
│   ├── 011_test_permissions.sql
│   ├── 013_migrate_v080.sql
│   └── SHA256SUMS.release-v080
└── tools/
```

The migration runs on the Ansible controller
using the PostgreSQL client and a TLS connection.

CSV source files remain on the controller.

## Release integrity

The migration release manifest is pinned
in the role configuration.

Before migration, Ansible verifies:

- The approved release manifest checksum.
- All eight migration manifests.
- The original SQLite database checksum.
- The SQL migration procedure.
- The exported CSV artifacts.
- Data validation scripts.
- Functional and concurrency test artifacts.
- Application permission scripts.

The installed migration history stores both
the source database checksum and the migration
release manifest checksum.

Approved release artifacts must not be modified
after successful installation.

Future schema changes require a new versioned
migration.

## Transactional migration

The migration procedure implements:

1. Session and TLS validation.
2. Session-level advisory locking.
3. SERIALIZABLE transaction isolation.
4. Explicit owner role transition.
5. Target schema and migration history validation.
6. Installation of database objects.
7. Import of SQLite data.
8. Row count validation.
9. Data value validation.
10. Identity sequence validation.
11. Application permission configuration.
12. Effective privilege audit.
13. Migration history registration.
14. Explicit COMMIT or ROLLBACK.
15. Advisory lock release.
16. Independent durable state validation.

The advisory lock coordinates cooperating
migration processes.

It does not prevent arbitrary administrative
operations outside the migration procedure.

## Migration dry run

```bash
ansible-playbook \
    -i inventory/notebook.ini \
    stona100_database.yml \
    --limit database01 \
    --tags db_migration \
    -e '{"stona100_migration_enabled":true,"stona100_migration_commit":false}'
```

On an empty target schema, the migration
installs and validates all database objects
and imported data inside a transaction.

The transaction is explicitly rolled back.

Expected result:

```text
DRY_RUN_ROLLBACK
```

On an already installed matching release,
the expected result is:

```text
ALREADY_APPLIED
```

## Applying the migration

```bash
ansible-playbook \
    -i inventory/notebook.ini \
    stona100_database.yml \
    --limit database01 \
    --tags db_migration \
    -e '{"stona100_migration_enabled":true,"stona100_migration_commit":true}'
```

Expected result for the initial installation:

```text
COMMITTED
```

Expected result for an existing matching release:

```text
ALREADY_APPLIED
```

An unexpected schema or inconsistent migration
history causes the procedure to fail.

Existing objects are never automatically dropped.

A client or postflight failure after COMMIT
does not imply that the database transaction
was rolled back.

Inspect the durable database state before
retrying a failed deployment.

## Installed database inventory

| Object | Count |
|---|---:|
| Business tables | 45 |
| Migration history tables | 1 |
| Views | 14 |
| Indexes | 65 |
| Identity sequences | 7 |
| PL/pgSQL functions | 7 |
| User triggers | 7 |
| Business data rows at migration | 3817 |

## Migration history

| Parameter | Value |
|---|---|
| Schema version | 800 |
| Release | 0.8 |
| Source engine | SQLite |
| Source version | 700 |
| Installed by | stona100_migrator |
| Installation date | 2026-11-26 |
| Installation time | 09:13:54 CET |
| Recorded execution time | 700 ms |

The recorded execution time represents
the measured SQL migration interval,
not the complete Ansible execution time.

The table `stona100.schema_migrations`
contains one successfully installed
migration record.

## Security regression tests

Run the connection and session tests:

```bash
ansible-playbook \
    -i inventory/notebook.ini \
    -i inventory_local.ini \
    stona100_connection_test.yml
```

Run database isolation tests:

```bash
ansible-playbook \
    -i inventory/notebook.ini \
    -i inventory_local.ini \
    stona100_isolation_test.yml
```

Run the existing PostgreSQL connectivity
regression test:

```bash
ansible-playbook \
    postgresql_remote_test.yml \
    --limit rhel01 \
    -e "postgresql_test_database_host=database01"
```

The local controller inventory is separated
from the managed server inventory to avoid
targeting macOS with Linux administration
playbooks.

## Application access tests

Run the final application access tests
against the installed database:

```bash
ansible-playbook \
    -i inventory/notebook.ini \
    -i inventory_local.ini \
    stona100_application_test.yml
```

The tests establish real authenticated
database connections from the authorized
controller and application hosts.

They validate:

- TLS and session parameters.
- Client source addresses.
- Catalog SELECT permissions.
- Access to all fourteen application views.
- Archived source email restrictions.
- Migration history restrictions.
- Application INSERT, UPDATE and DELETE.
- Read-only DML rejection.
- Catalog mutation rejection.
- Owner role escalation rejection.

All application DML tests are executed
inside transactions ending with ROLLBACK.

An explicit test identity value prevents
unnecessary consumption of identity sequence
values.

An independent server-side postflight checks
for remaining test records and validates
selected catalog counts.

## Validation results

Validation date: 2026-11-26.

| Test | Result |
|---|---|
| PostgreSQL HBA validation | 24 rules, 0 errors |
| HBA configuration idempotence | PASS |
| PostgreSQL reload without restart | PASS |
| Connection security tests | 12/12 PASS |
| Database isolation tests | 43/43 PASS |
| Existing ansible_lab regression | PASS |
| Migration role transition | PASS |
| DDL object validation | PASS |
| Row count validation | 59/59 PASS |
| Data value validation | 59/59 PASS |
| Functional trigger tests | 23/23 PASS |
| Transaction isolation tests | 3/3 PASS |
| Concurrency tests | 3/3 PASS |
| Application permission tests | 23/23 PASS |
| Effective ACL checks per audit | 2511 PASS |
| Identity sequence validation | 7/7 PASS |
| Migration dry run | PASS |
| Permanent migration | COMMITTED |
| Independent post-migration audit | PASS |
| Migration idempotence | PASS |
| Complete role idempotence | PASS |
| Application access tests | 20/20 PASS |
| Independent application postflight | PASS |

## Deployment execution results

| Execution | OK | Changed | Failed |
|---|---:|---:|---:|
| Migration dry run | 27 | 0 | 0 |
| Initial migration | 38 | 1 | 0 |
| Repeated migration | 40 | 0 | 0 |
| Complete infrastructure role | 27 | 0 | 0 |
| Post-provisioning migration audit | 40 | 0 | 0 |

Final application access test results:

```text
database01 : ok=3 changed=0 failed=0
localhost  : ok=7 changed=0 failed=0
rhel01     : ok=7 changed=0 failed=0
```

No test application records remained
in the installed database.

## Data protection

The following private artifacts must not
be committed to the public infrastructure
repository:

- SQLite database files.
- PostgreSQL database dumps.
- CSV exports containing application data.
- Data-bearing SQL validation scripts.
- Archived source correspondence.
- Private migration and audit archives.
- Unencrypted authentication credentials.

Sensitive credentials are maintained separately
using Ansible Vault.

## Known limitations and future improvements

- Full TLS server identity verification using
  a trusted CA and sslmode=verify-full.
- Functional testing of automatic HBA rollback.
- Functional IPv6 connectivity testing.
- PostgreSQL backup and restore validation.
- Idempotence testing with existing user data
  on an isolated restored database.
- JDBC integration with WildFly.
- Application-level transaction retry handling
  for serialization failures.
- Continuous integration and monitoring.

The ACL audit validates the defined effective
permission matrix. It is not an exhaustive
security assessment.

The application postflight validates selected
catalog counts, not every stored value.

## Project status

The PostgreSQL infrastructure, security,
schema conversion, data migration and
application access validation stages
are complete.

StoNa100 PostgreSQL v0.8 is installed
and operational.

The remaining database development stage
is backup and restore validation.

Subsequent development will focus on
Java, WildFly, PostgreSQL JDBC integration
and the web application.
