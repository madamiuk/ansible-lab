# Ansible Infrastructure & Application Delivery Lab

[![Ansible CI](https://github.com/madamiuk/ansible-lab/actions/workflows/ansible-ci.yml/badge.svg)](https://github.com/madamiuk/ansible-lab/actions/workflows/ansible-ci.yml)

Hands-on infrastructure automation laboratory built around **Ansible**, **Linux**, **Oracle Cloud Infrastructure**, **WildFly**, **PostgreSQL**, **Nagios**, **GitHub Actions** and the **JobTracker** Java application.

The project focuses on practical System Engineering, Infrastructure as Code and DevOps workflows rather than isolated configuration examples.

The laboratory covers:

- Linux host configuration
- reusable Ansible roles
- configuration management
- Java application deployment
- WildFly administration
- PostgreSQL administration
- database connectivity
- Ansible Vault
- Terraform-to-Ansible integration
- CI validation
- automated cross-repository CD
- artifact-based deployment
- deployment preflight checks
- SHA-256 artifact verification
- automatic rollback
- REST runtime verification
- end-to-end application testing
- Nagios monitoring
- OCI Monitoring
- idempotency
- troubleshooting real infrastructure dependencies

---

## Current architecture

The environment is split across three independent repositories:

```text
madamiuk/oci-terraform-lab
        |
        | Terraform
        v
Oracle Cloud Infrastructure
        |
        +--> oci-ansible01
        |       Oracle Linux 9
        |       Java 21
        |       WildFly
        |       JobTracker
        |
        +--> oci-ansible02
        |       Oracle Linux 9
        |       Nagios
        |
        +--> oci-ansible03
                Oracle Linux 9
                PostgreSQL 18
                jobtracker database


madamiuk/ansible-lab
        |
        +--> Linux configuration
        +--> WildFly
        +--> PostgreSQL
        +--> Nagios
        +--> JobTracker deployment
        +--> runtime verification
        +--> end-to-end tests


madamiuk/jobtracker
        |
        +--> Java 21
        +--> Jakarta EE 11
        +--> REST API
        +--> JPA / Hibernate
        +--> web interface
        +--> automated tests
        +--> Maven
        +--> GitHub Actions
        +--> WAR artifact
```

Responsibilities are intentionally separated:

```text
Terraform  -> infrastructure
Ansible    -> configuration and deployment
JobTracker -> application code and business logic
```

---

## OCI environment

Current laboratory topology:

```text
Oracle Cloud Infrastructure
│
├── oci-ansible01
│   ├── Oracle Linux 9
│   ├── Java 21
│   ├── WildFly
│   └── JobTracker
│
├── oci-ansible02
│   ├── Oracle Linux 9
│   └── Nagios
│
└── oci-ansible03
    ├── Oracle Linux 9
    ├── PostgreSQL 18
    └── jobtracker database
```

Private addressing:

```text
oci-ansible01    10.10.1.37
oci-ansible02    10.10.1.176
oci-ansible03    10.10.1.26
```

Application traffic between WildFly and PostgreSQL uses the private OCI network.

PostgreSQL runs on a dedicated database host and is never assumed to run locally on the WildFly server.

---

## Repository responsibilities

This repository manages the configuration and application delivery layer.

Main responsibilities:

```text
Operating system configuration
        |
        v
Java / WildFly
        |
        v
PostgreSQL
        |
        v
Nagios
        |
        v
JobTracker deployment
        |
        v
runtime verification
        |
        v
end-to-end verification
```

Terraform remains responsible for OCI infrastructure.

The JobTracker repository remains responsible for application source code, tests and artifact creation.

---

# CI/CD

The laboratory currently uses independent CI pipelines combined by an automated CD path.

```text
Terraform CI   -> OCI infrastructure validation
Ansible CI     -> automation validation
JobTracker CI  -> Java build and application tests
JobTracker CD  -> deployment and E2E verification
```

---

## Ansible CI

Workflow:

```text
.github/workflows/ansible-ci.yml
```

The pipeline validates:

```text
repository checkout
        |
        v
Python / Ansible environment
        |
        v
Bash syntax
        |
        v
Ansible collection installation
        |
        v
inventory validation
        |
        v
playbook syntax checks
```

The workflow runs automatically on repository changes.

---

# Automated JobTracker CD

Workflow:

```text
.github/workflows/jobtracker-cd.yml
```

The workflow runs on the existing self-hosted macOS ARM64 runner.

It can be triggered in two ways:

```text
repository_dispatch
```

for normal automated deployments, or:

```text
workflow_dispatch
```

for controlled manual testing.

The automated event type is:

```text
jobtracker-ci-success
```

---

## Cross-repository deployment flow

The complete deployment pipeline is:

```text
madamiuk/jobtracker
        |
        | git push
        v
JobTracker CI
        |
        | Java 21
        | Maven
        | 47 automated tests
        v
jobtracker.war
        |
        v
jobtracker-war GitHub artifact
        |
        v
Trigger JobTracker CD
        |
        | repository_dispatch
        | exact CI run ID
        v
madamiuk/ansible-lab
        |
        v
JobTracker CD
        |
        v
self-hosted macOS ARM64 runner
        |
        v
download exact CI artifact
        |
        v
Ansible deployment
        |
        v
oci-ansible01 / WildFly
        |
        v
health + REST smoke tests
        |
        v
jobtracker_e2e.yml
        |
        v
oci-ansible03 / PostgreSQL
        |
        v
GREEN
```

This complete automatic CI/CD path has been successfully validated end-to-end.

---

## Why cross-repository CD

Application build and infrastructure deployment intentionally live in separate repositories.

```text
jobtracker
    |
    +--> source code
    +--> tests
    +--> Maven
    +--> WAR artifact
    +--> deployment trigger

ansible-lab
    |
    +--> deployment logic
    +--> secrets
    +--> WildFly configuration
    +--> runtime validation
    +--> database verification
```

The application repository does not need a dedicated self-hosted runner.

Instead, the successful JobTracker CI workflow sends a `repository_dispatch` event to `ansible-lab`, where the existing runner performs the deployment.

---

## Deployment artifact identity

The dispatch payload contains the exact JobTracker CI run ID.

The deployment workflow therefore consumes the WAR artifact created by the specific CI run that triggered deployment.

This avoids the race condition that could occur if CD simply selected:

```text
latest successful CI run
```

while another build was running.

---

## JobTracker deployment wrapper

Primary wrapper:

```text
scripts/deploy-jobtracker-artifact.sh
```

It supports two modes.

### Explicit CI run

```bash
./scripts/deploy-jobtracker-artifact.sh <CI_RUN_ID>
```

This is the mode used by automated CD.

### Latest successful CI run

When no argument is supplied, the wrapper can locate the newest successful JobTracker CI run.

This remains useful for controlled manual deployments.

---

## Deployment wrapper flow

```text
receive CI run ID
        |
        v
download jobtracker-war
        |
        v
validate WAR
        |
        v
calculate SHA-256
        |
        v
run jobtracker_deploy.yml
        |
        v
validate datasource
        |
        v
deploy WAR
        |
        v
verify remote checksum
        |
        v
verify WildFly deployment
        |
        v
run REST smoke tests
        |
        v
optional full E2E
```

Automated CD sets:

```text
RUN_E2E=true
```

which causes the wrapper to execute:

```text
jobtracker_e2e.yml
```

after deployment validation.

---

## GitHub authentication

The CD workflow uses a dedicated GitHub Actions secret:

```text
JOBTRACKER_CD_TOKEN
```

The token is used for controlled cross-repository operations such as:

- accessing the JobTracker repository,
- reading the appropriate GitHub Actions run,
- downloading the CI artifact,
- issuing repository dispatch events.

The token value is never stored in Git.

---

## Artifact storage

Downloaded CI artifacts are stored under:

```text
artifacts/
```

This directory is excluded from Git.

Generated artifacts are deployment inputs only and are not part of repository history.

---

# JobTracker deployment

Primary deployment playbook:

```text
jobtracker_deploy.yml
```

The playbook supports both local builds and prebuilt CI artifacts.

---

## Local development build

A local development deployment may build the application before deployment:

```bash
ansible-playbook \
  jobtracker_deploy.yml
```

The local application repository provides:

```text
target/jobtracker.war
```

after the Maven build.

---

## Prebuilt artifact deployment

A prebuilt WAR can be deployed without rebuilding the application:

```bash
ansible-playbook \
  jobtracker_deploy.yml \
  -e jobtracker_build_local=false \
  -e wildfly_war_source=/path/to/jobtracker.war
```

This mode is used by automated CI/CD.

---

# WildFly deployment safety

Before deployment Ansible verifies that:

- the WAR exists,
- the WAR is a regular file,
- the WAR is non-empty,
- the WAR is a valid ZIP/WAR archive,
- required application classes exist,
- `persistence.xml` exists,
- the WildFly datasource exists,
- database connectivity succeeds.

Expected WAR contents include:

```text
WEB-INF/
WEB-INF/classes/META-INF/persistence.xml
WEB-INF/classes/pl/jobtracker/config/RestApplication.class
WEB-INF/classes/pl/jobtracker/rest/HealthResource.class
```

Invalid artifacts are rejected before deployment.

---

## Artifact integrity

SHA-256 is calculated before and after transfer:

```text
source WAR
    |
    v
local SHA-256
    |
    v
Ansible copy
    |
    v
remote WAR
    |
    v
remote SHA-256
    |
    v
checksum comparison
```

The deployment is accepted only when the checksums match.

---

## Automatic rollback

Before replacing an existing JobTracker WAR, Ansible preserves the currently deployed artifact.

WildFly markers are monitored:

```text
.war.deployed
.war.failed
```

Failure handling:

```text
new WAR
   |
   v
WildFly deployment
   |
   +--> success
   |
   `--> failure
          |
          v
     restore backup
          |
          v
       .dodeploy
          |
          v
     verify rollback
```

This prevents a failed application artifact from permanently replacing a working deployment.

---

# Runtime verification

A successful WildFly deployment marker alone is not considered enough.

The deployment playbook also verifies the running application.

Checks include:

```text
GET /jobtracker/api/health
GET /jobtracker/api/companies
GET /jobtracker/api/offers
GET /jobtracker/api/applications
```

Validation covers:

```text
HTTP 200
application/json
valid JSON
expected collection structure
expected response fields
```

A broken application contract therefore causes deployment verification to fail even when WildFly itself is running.

---

# End-to-end verification

Dedicated playbook:

```text
jobtracker_e2e.yml
```

The E2E flow creates:

```text
Company
   |
   v
Job Offer
   |
   v
Job Application
```

using the real REST API.

The resulting records are then verified through:

```text
REST API
   +
PostgreSQL
```

Flow:

```text
POST Company
      |
      v
POST Job Offer
      |
      v
POST Job Application
      |
      v
REST verification
      |
      v
direct PostgreSQL SELECT
      |
      v
cleanup
```

The E2E test covers the full path:

```text
REST
  |
  v
Jakarta EE
  |
  v
JPA / Hibernate
  |
  v
WildFly JTA datasource
  |
  v
PostgreSQL
```

Temporary test data is removed after verification.

---

## Deployment verification layers

```text
Layer 1
JobTracker CI
    |
    v
Maven build + tests


Layer 2
WAR preflight
    |
    v
artifact structure


Layer 3
SHA-256
    |
    v
artifact integrity


Layer 4
WildFly
    |
    v
deployment marker


Layer 5
REST
    |
    v
runtime health


Layer 6
REST contracts
    |
    v
response structure


Layer 7
E2E
    |
    v
real PostgreSQL persistence
```

The objective is to detect failures as close as possible to the layer where they occur.

---

# JobTracker runtime

Application server:

```text
Host:        oci-ansible01
Private IP:  10.10.1.37
Platform:    WildFly
Application: jobtracker
```

Database:

```text
Host:       oci-ansible03
Private IP: 10.10.1.26
Database:   jobtracker
User:       jobtracker
Version:    PostgreSQL 18
```

Datasource:

```text
Datasource: JobTrackerDS
JNDI:       java:/jdbc/JobTrackerDS
```

Health endpoint:

```text
http://10.10.1.37:8080/jobtracker/api/health
```

WildFly port `8080` is not intentionally exposed publicly.

Development access can use:

```bash
ssh -L 8080:10.10.1.37:8080 opc@<PUBLIC_IP>
```

and:

```text
http://localhost:8080/jobtracker/
```

---

# Terraform to Ansible integration

OCI infrastructure is managed in:

```text
madamiuk/oci-terraform-lab
```

Terraform exports structured host information through:

```text
ansible_hosts
```

Ansible consumes this information using:

```text
scripts/generate-oci-inventory.sh
```

and:

```text
scripts/refresh-oci-inventory.sh
```

Flow:

```text
Terraform
    |
    v
ansible_hosts
    |
    v
generate-oci-inventory.sh
    |
    v
inventory/oci.ini
    |
    v
inventory validation
    |
    v
Ansible ping
```

This avoids maintaining the same OCI host metadata manually in both Terraform and Ansible.

---

## OCI inventory groups

Current logical groups include:

```text
oci
appservers
nagios_server
oci_database
monitored_hosts
```

Current role assignment:

```text
oci-ansible01
    oci
    appservers
    monitored_hosts

oci-ansible02
    oci
    nagios_server

oci-ansible03
    oci
    oci_database
    monitored_hosts
```

Terraform is the source of truth for OCI host role groups.

---

# Nagios monitoring

Nagios Core runs on:

```text
oci-ansible02
```

Current monitored hosts:

```text
oci-ansible01
oci-ansible03
```

Common checks include:

```text
PING
SSH
Load
Root Disk
Users
Processes
Swap
Memory
```

Application-specific checks include:

```text
WildFly HTTP
```

Database-specific checks include:

```text
PostgreSQL Process
PostgreSQL JobTracker
PostgreSQL Connections
PostgreSQL Database Size
```

---

## Monitoring configuration model

Nagios host and service definitions are generated from inventory groups rather than duplicated manually.

This allows monitoring behavior to follow infrastructure roles.

Example:

```text
appservers
    |
    +--> WildFly HTTP

oci_database
    |
    +--> PostgreSQL Process
    +--> PostgreSQL JobTracker
    +--> PostgreSQL Connections
    +--> PostgreSQL Database Size
```

---

## Monitoring thresholds

Common monitoring thresholds are centralized.

Group-specific overrides are supported for:

```text
appservers
oci_database
```

This allows different operational expectations for application and database systems without duplicating monitoring configuration.

Examples include:

```text
system load
memory
filesystem
process count
WildFly HTTP response time
PostgreSQL connections
PostgreSQL database size
```

---

# OCI Monitoring

Nagios is complemented by native OCI Monitoring.

The OCI environment currently contains monitoring alarms for all three compute instances.

Monitored areas include:

```text
CPU utilization
memory utilization
load average
instance accessibility
infrastructure health
```

Notifications are delivered through OCI Notifications.

Configured channels include:

```text
EMAIL
SMS
```

The alarm pipeline has been validated with a real CPU threshold test:

```text
OK
 |
 v
FIRING
 |
 v
notification
 |
 v
OK
```

Both email and SMS delivery were verified.

OCI Monitoring configuration itself is maintained in the Terraform repository.

---

# Secrets management

Infrastructure secrets are stored using:

```text
Ansible Vault
```

Examples include:

```text
database credentials
application database password
privilege escalation credentials
```

GitHub Actions secrets are used for CI/CD authentication.

Sensitive information must never be committed to Git.

Terraform state, OCI private keys and local credential files are also excluded from source control.

---

# Idempotency

Idempotency is a core design requirement.

Repeated execution should not introduce unnecessary changes.

Expected stable execution resembles:

```text
changed=0
failed=0
```

when the target system already matches the desired state.

Roles and playbooks are tested for repeatability.

---

# Repository structure

Important repository areas include:

```text
.
├── .github/
│   └── workflows/
│       ├── ansible-ci.yml
│       └── jobtracker-cd.yml
│
├── group_vars/
│
├── inventory/
│   └── oci.ini
│
├── roles/
│   ├── linux_baseline/
│   ├── monitoring_agent/
│   ├── nagios_server/
│   ├── postgresql/
│   ├── tomcat/
│   └── wildfly/
│
├── scripts/
│   ├── deploy-jobtracker-artifact.sh
│   ├── generate-oci-inventory.sh
│   └── refresh-oci-inventory.sh
│
├── artifacts/
│
├── jobtracker_deploy.yml
├── jobtracker_e2e.yml
├── monitoring_agent.yml
├── nagios_server.yml
├── oci_baseline.yml
├── ansible.cfg
└── README.md
```

The local:

```text
macbook_resources.sh
```

helper is intentionally not part of the tracked repository.

---

# Development principles

The laboratory follows several practical engineering principles.

## Single source of truth

Infrastructure metadata originates from Terraform wherever possible.

## No secret duplication

Passwords and tokens belong in Vault or GitHub Secrets, not source files.

## Build once, deploy the artifact

Automated CD deploys the WAR generated by the corresponding CI run instead of rebuilding application code during deployment.

## Verify every layer

A successful process exit is not enough.

Deployment validation covers:

```text
artifact
transfer
application server
REST
database
```

## Keep infrastructure responsibilities separated

```text
Terraform
    -> infrastructure

Ansible
    -> configuration and deployment

JobTracker
    -> application
```

## Prefer private communication

Application-to-database traffic uses OCI private networking.

Administrative application ports are not intentionally exposed publicly.

---

# Current status

The laboratory currently provides a working integrated platform with:

- Terraform-managed OCI infrastructure,
- Terraform-generated Ansible inventory data,
- Oracle Linux hosts,
- WildFly,
- PostgreSQL 18,
- JobTracker,
- Nagios,
- OCI Monitoring,
- Ansible Vault,
- Ansible CI,
- JobTracker CI,
- automatic cross-repository JobTracker CD,
- artifact integrity verification,
- rollback protection,
- REST smoke tests,
- full E2E verification.

The complete automated delivery path:

```text
source commit
   |
   v
JobTracker CI
   |
   v
WAR artifact
   |
   v
cross-repository trigger
   |
   v
JobTracker CD
   |
   v
Ansible
   |
   v
WildFly
   |
   v
REST verification
   |
   v
PostgreSQL E2E verification
```

has been successfully validated.

---

# Project direction

The laboratory is designed to continue evolving toward realistic production-style workflows.

Future areas may include:

- further application lifecycle automation,
- PostgreSQL backup automation,
- restore testing,
- additional deployment safeguards,
- richer monitoring and alerting,
- deployment rollback improvements,
- reporting,
- environment separation,
- stronger release/version management.

The objective remains practical experience with real Linux administration, automation, CI/CD and application operations rather than isolated demonstrations.
