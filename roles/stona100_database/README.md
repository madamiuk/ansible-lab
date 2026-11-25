# StoNa100 PostgreSQL Infrastructure

## Overview

The `stona100_database` Ansible role provisions and validates a dedicated PostgreSQL database environment for the StoNa100 application.

The infrastructure follows the principles of least privilege, separation of responsibilities, network isolation, secure authentication and idempotent configuration management.

This stage prepares the database environment for the migration from SQLite v0.7 to PostgreSQL v0.8.

## Environment

| Component | Value |
|---|---|
| Ansible controller | macOS / Apple Silicon |
| Database server | database01 |
| Database server OS | Debian 13 |
| PostgreSQL version | 17.11 |
| PostgreSQL address | 192.168.64.20 |
| PostgreSQL port | 5432 |
| Application server | rhel01 |
| Application server address | 192.168.64.16 |
| Controller address | 192.168.64.1 |
| Database | stona100 |
| Schema | stona100 |
| Encoding | UTF8 |
| Locale | pl_PL.UTF-8 |

## Database roles

| Role | Purpose |
|---|---|
| stona100_owner | Non-login database and schema owner |
| stona100_migrator | Dedicated migration account |
| stona100_app | Application runtime account |
| stona100_readonly | Read-only access account |

The migration account does not automatically inherit owner privileges.

Database migrations require an explicit role transition:

```sql
SET ROLE stona100_owner;
```

All migrated database objects should be owned by `stona100_owner`.

Object-level application and read-only privileges will be configured during the migration stage.

## Security model

- Dedicated application database and schema.
- Restricted database-level privileges.
- Removal of unnecessary PUBLIC privileges within the StoNa100 database.
- SCRAM-SHA-256 password authentication.
- Mandatory TLS for authorized remote application connections.
- Source IP restrictions.
- Explicit HBA rejection rules.
- Cross-database connection isolation.
- Local Unix socket and loopback connection restrictions.
- Database-specific search_path configuration.
- Password management using Ansible Vault.
- Sensitive task output protected using no_log.

## PostgreSQL HBA configuration

The existing `postgresql` role supports three ordered rule groups:

```yaml
postgresql_prepend_hba_rules: []
postgresql_extra_hba_rules: []
```

Rules are evaluated in the following order:

1. Prepend rules.
2. Standard PostgreSQL rules.
3. Extra application-specific rules.

Automatic rule sorting is disabled to preserve the intended HBA evaluation order.

The deployed configuration contains:

| Rule category | Count |
|---|---:|
| StoNa100 TLS allow rules | 3 |
| StoNa100 explicit reject rules | 9 |
| Standard PostgreSQL rules | 7 |
| Existing ansible_lab rules | 5 |
| Total | 24 |

HBA changes are validated before requesting a PostgreSQL configuration reload.

A backup of the previous HBA configuration is retained for recovery purposes.

## Network access policy

| Source | Database role | TLS | Access |
|---|---|---|---|
| Ansible controller | stona100_migrator | Required | Allow |
| Ansible controller | stona100_readonly | Required | Allow |
| Application server | stona100_app | Required | Allow |

Other ordinary connection attempts using StoNa100 login accounts are explicitly rejected.

Existing ansible_lab connectivity remains operational.

## Session configuration

The following database-specific setting is configured for all three StoNa100 login roles:

```sql
SET search_path TO stona100;
```

The setting is managed through role-specific and database-specific PostgreSQL configuration.

The implementation checks `pg_db_role_setting` before applying changes to ensure idempotence.

## Required Vault variables

The following variables must be defined in the encrypted Ansible Vault:

```yaml
vault_stona100_db_migrator_password:
vault_stona100_db_app_password:
vault_stona100_db_readonly_password:
```

Actual passwords must never be stored in documentation or unencrypted inventory files.

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
    ├── database.yml
    ├── schema.yml
    ├── session.yml
    ├── validation.yml
    ├── migration.yml
    └── permissions.yml
```

The migration and object-level permission tasks are reserved for the next development stage.

## Deployment

Configure PostgreSQL and application-specific HBA rules:

```bash
ansible-playbook postgresql_role.yml \
    --limit database01
```

Provision the StoNa100 database environment:

```bash
ansible-playbook stona100_database.yml \
    --limit database01
```

Validate the expected configuration without applying changes:

```bash
ansible-playbook stona100_database.yml \
    --limit database01 \
    --check
```

## Security tests

The local Ansible controller inventory is kept separate from the managed server inventory to avoid targeting macOS with Linux administration playbooks.

Run connection and session tests:

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

Run the existing PostgreSQL connectivity regression test:

```bash
ansible-playbook postgresql_remote_test.yml \
    --limit rhel01 \
    -e "postgresql_test_database_host=database01"
```

## Validation results

Validation date: 2026-11-25.

| Test | Result |
|---|---|
| PostgreSQL HBA validation | 24 rules, 0 errors |
| HBA configuration idempotence | PASS |
| PostgreSQL reload without restart | PASS |
| Connection security tests | 12/12 PASS |
| Database isolation tests | 43/43 PASS |
| Existing ansible_lab regression | PASS |
| Session search_path validation | PASS |
| Migration role transition | PASS |
| Complete database role idempotence | PASS |

Final database role execution:

```text
database01:
    ok=26
    changed=0
    unreachable=0
    failed=0
    skipped=1
    rescued=0
    ignored=0
```

## Data protection

Private SQLite databases, database exports and migration audit archives must not be committed to the infrastructure repository.

Sensitive credentials are maintained separately using Ansible Vault.

## Known limitations and future improvements

- Full TLS server identity verification using a trusted CA and sslmode=verify-full.
- Functional testing of automatic HBA rollback.
- Functional IPv6 connectivity testing.
- Transactional DDL permission tests.
- Explicit negative SET ROLE tests for application accounts.
- Database object-level access control.
- SQLite to PostgreSQL schema and data migration.
- PostgreSQL backup and restore validation.

## Project status

The PostgreSQL infrastructure provisioning stage is complete.

The database environment is ready for schema conversion and data migration from SQLite v0.7 to PostgreSQL v0.8.
