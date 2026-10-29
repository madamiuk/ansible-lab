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
- secrets management
- CI validation
- artifact-based deployment
- deployment preflight checks
- artifact integrity verification
- automatic rollback
- REST runtime verification
- end-to-end application testing
- monitoring
- idempotency
- troubleshooting real infrastructure dependencies

The environment is developed incrementally and is used against both local virtual machines and Oracle Cloud Infrastructure.

---

## Current architecture

The current laboratory is split across three independent repositories:

```text
oci-terraform-lab
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


ansible-lab
        |
        +--> Linux configuration
        +--> WildFly
        +--> PostgreSQL
        +--> Nagios
        +--> application deployment
        +--> runtime verification
        +--> end-to-end tests


jobtracker
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

The OCI environment currently contains three Oracle Linux hosts.

```text
oci-ansible01
    |
    +--> Oracle Linux 9
    +--> Java 21
    +--> WildFly
    +--> JobTracker

oci-ansible02
    |
    +--> Oracle Linux 9
    +--> Nagios

oci-ansible03
    |
    +--> Oracle Linux 9
    +--> PostgreSQL 18
    +--> jobtracker database
```

Current private addressing:

```text
oci-ansible01    10.10.1.37
oci-ansible02    10.10.1.176
oci-ansible03    10.10.1.26
```

Application traffic between WildFly and PostgreSQL uses the private OCI network.

PostgreSQL runs on a dedicated database host and is not installed locally on the WildFly application server.

---

## Repository responsibilities

The Ansible repository is responsible for the configuration and application delivery layer.

It manages:

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
Runtime verification
        |
        v
End-to-end verification
```

Terraform remains responsible for OCI infrastructure.

JobTracker remains responsible for application source code and application-level CI.

---

## CI status

The laboratory currently uses three independent CI pipelines:

```text
Terraform CI   -> OCI infrastructure configuration
Ansible CI     -> automation validation
JobTracker CI  -> Java application build and tests
```

All three layers are validated independently before they are combined at runtime.

### Ansible CI

The Ansible GitHub Actions workflow validates:

```text
repository checkout
        |
        v
Python / Ansible environment
        |
        v
Bash syntax validation
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

Workflow:

```text
.github/workflows/ansible-ci.yml
```

The CI pipeline runs automatically on repository changes.

---

## JobTracker application delivery

JobTracker is the main integrated OCI workload.

The application is developed in the separate:

```text
madamiuk/jobtracker
```

repository.

The complete application delivery path is:

```text
Git push
    |
    v
JobTracker CI
    |
    v
Java 21
    |
    v
mvn clean verify
    |
    v
47 automated tests
    |
    v
jobtracker.war
    |
    v
GitHub Actions artifact
    |
    v
Ansible deployment
    |
    v
oci-ansible01
WildFly
    |
    | JDBC
    v
oci-ansible03
PostgreSQL 18
    |
    v
REST runtime verification
```

The separation between build and deployment is intentional.

JobTracker creates the application artifact.

Ansible deploys and verifies it.

---

## JobTracker deployment wrapper

The primary artifact deployment wrapper is:

```bash
./scripts/deploy-jobtracker-artifact.sh
```

The wrapper performs the following workflow:

```text
Find newest successful JobTracker CI run
        |
        v
Download jobtracker-war artifact
        |
        v
Validate WAR
        |
        v
Calculate SHA-256
        |
        v
Run jobtracker_deploy.yml
        |
        v
Validate JobTrackerDS
        |
        v
Deploy WAR
        |
        v
Verify remote SHA-256
        |
        v
Verify WildFly deployment
        |
        v
Run REST checks
```

Downloaded CI artifacts are stored locally under:

```text
artifacts/
```

The artifact directory is excluded from Git.

---

## Deployment modes

The JobTracker deployment playbook supports two deployment modes.

### Local development build

```bash
cd /path/to/ansible-lab

ansible-playbook \
  jobtracker_deploy.yml
```

In this mode the application is built locally from:

```text
/path/to/jobtracker
```

using Maven.

The resulting artifact is:

```text
/path/to/jobtracker/target/jobtracker.war
```

---

### Prebuilt artifact deployment

A prebuilt WAR can be deployed without rebuilding the application:

```bash
cd /path/to/ansible-lab

ansible-playbook \
  jobtracker_deploy.yml \
  -e jobtracker_build_local=false \
  -e wildfly_war_source=/path/to/jobtracker.war
```

This mode is used by:

```text
./scripts/deploy-jobtracker-artifact.sh
```

and separates artifact creation from infrastructure deployment.

---

## JobTracker runtime

JobTracker currently runs on:

```text
Host:        oci-ansible01
Private IP:  10.10.1.37
Platform:    WildFly
Application: jobtracker
```

Datasource:

```text
Datasource: JobTrackerDS
JNDI:       java:/jdbc/JobTrackerDS
```

Database:

```text
Host:       oci-ansible03
Private IP: 10.10.1.26
Database:   jobtracker
User:       jobtracker
Version:    PostgreSQL 18
```

The application health endpoint is available internally under:

```text
http://10.10.1.37:8080/jobtracker/api/health
```

WildFly port `8080` is not intentionally exposed publicly for normal application use.

During development the web interface can be accessed through an SSH tunnel.

Example:

```bash
ssh -L 8080:10.10.1.37:8080 opc@<PUBLIC_IP>
```

Then:

```text
http://localhost:8080/jobtracker/
```

---

## WildFly deployment safety

The JobTracker deployment includes several safeguards.

Before deployment Ansible verifies that:

- the WAR exists
- the WAR is a regular file
- the WAR is non-empty
- the WAR is a valid ZIP/WAR archive
- required application classes exist
- `persistence.xml` exists
- the WildFly datasource exists
- database connectivity through WildFly succeeds

Expected WAR contents include:

```text
WEB-INF/
WEB-INF/classes/META-INF/persistence.xml
WEB-INF/classes/pl/jobtracker/config/RestApplication.class
WEB-INF/classes/pl/jobtracker/rest/HealthResource.class
```

The deployment is stopped if the artifact does not satisfy the expected structure.

---

## Artifact integrity

Before deployment Ansible calculates the SHA-256 checksum of the source WAR.

After copying the artifact to WildFly, Ansible calculates the checksum again.

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

This prevents an incomplete or altered transfer from being treated as a valid deployment.

---

## Automatic rollback

Before replacing an existing JobTracker WAR, Ansible creates a backup of the currently deployed artifact.

WildFly deployment markers are monitored:

```text
.war.deployed
.war.failed
```

Failure handling follows this model:

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

Older backups are rotated.

This makes the deployment process safer than simply overwriting the active application artifact.

---

## REST runtime verification

A successful WildFly deployment marker alone is not considered sufficient.

The deployment playbook also verifies the running application through REST.

Runtime checks currently cover:

```text
GET /jobtracker/api/health
GET /jobtracker/api/companies
GET /jobtracker/api/offers
GET /jobtracker/api/applications
```

Checks include:

```text
HTTP 200
Content-Type application/json
valid JSON
expected collection structure
expected response fields
```

This verifies the application contract instead of testing only whether the TCP port is open.

---

## REST response contract validation

The deployment process validates selected API responses after application startup.

For collection endpoints Ansible verifies that:

- the endpoint responds successfully
- the response uses `application/json`
- the body can be parsed as JSON
- the result is a list
- expected fields are present in returned objects

This catches problems where:

```text
WildFly is running
        |
        v
WAR is deployed
        |
        v
HTTP endpoint responds
        |
        v
but application contract is broken
```

Such a deployment is treated as invalid even if the application server itself is healthy.

---

## End-to-end JobTracker verification

The laboratory contains a dedicated end-to-end playbook:

```text
jobtracker_e2e.yml
```

The test validates a complete recruitment data workflow:

```text
Company
   |
   v
Job Offer
   |
   v
Job Application
```

The playbook creates test data through the real JobTracker REST API.

The resulting objects are then verified through:

```text
REST API
   +
PostgreSQL
```

The flow is approximately:

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
GET / REST verification
      |
      v
direct PostgreSQL SELECT
      |
      v
test data cleanup
```

The E2E test therefore covers:

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

This verifies the complete application path instead of mocking individual components.

Temporary E2E records are removed when verification is complete.

---

## Deployment verification layers

JobTracker delivery currently contains several verification layers.

```text
Layer 1
Maven build
    |
    v
application tests


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
real database persistence
```

The goal is to detect failures as close as possible to the layer where they occur.

---

## Idempotency

Idempotency is treated as a core requirement throughout the laboratory.

Repeated execution should not introduce unnecessary changes.

For example, deploying an artifact that is already installed should produce a result similar to:

```text
changed=0
failed=0
```

where no configuration or artifact change is required.

Roles are developed and tested with repeatability in mind.

---

## Terraform to Ansible integration

OCI infrastructure is maintained in:

```text
/path/to/oci-terraform-lab
```

Terraform exposes structured information about the OCI hosts.

Ansible uses this data to generate its OCI inventory.

The inventory generation script is:

```text
./scripts/generate-oci-inventory.sh
```

The complete refresh wrapper is:

```text
./scripts/refresh-oci-inventory.sh
```

The workflow is:

```text
Terraform
    |
    v
ansible_hosts output
    |
    v
generate-oci-inventory.sh
    |
    v
inventory/oci.ini
    |
    v
ansible-inventory validation
    |
    v
Ansible ping
```

This keeps the Ansible OCI inventory synchronized with Terraform instead of maintaining the same infrastructure metadata manually in two repositories.

---

## Inventory design

The repository separates local and OCI hosts
