# Ansible Infrastructure & CI/CD Lab

Hands-on infrastructure automation lab built around **Ansible**, **WildFly**, **PostgreSQL**, **GitHub Actions** and a complete monitoring stack based on **Nagios**, **Prometheus** and **Grafana**.

The project focuses on practical system administration and DevOps workflows: provisioning fresh hosts, deploying applications, configuring database connectivity, validating deployments, monitoring services and keeping the entire process repeatable and idempotent.

## Key Features

- Ansible roles for reusable infrastructure configuration
- WildFly installation and configuration
- Java 21 provisioning
- PostgreSQL datasource configuration
- application deployment from a WAR artifact
- deployment pre-flight checks
- datasource connectivity verification
- SHA-256 artifact verification
- embedded Git/build metadata
- automatic deployment rollback
- deployment backup rotation
- GitHub Actions CI/CD
- Node Exporter installation
- Prometheus target generation from Ansible inventory
- Grafana monitoring
- NRPE installation and configuration
- Nagios host generation from Ansible inventory
- one-command deployment and monitoring onboarding
- idempotent Ansible roles

---

## One-command deployment

A new application host can be provisioned, configured, deployed and connected to the monitoring stack with a single command:

```bash
./deploy-lab.sh rhel02
```

The script performs the complete workflow:

```text
Host pre-check
      |
      v
SSH / Ansible connectivity
      |
      v
Privilege escalation check
      |
      v
Generate build metadata
      |
      v
Maven build + tests
      |
      v
WAR artifact verification
      |
      v
Ansible syntax check
      |
      v
Java provisioning
      |
      v
WildFly provisioning
      |
      v
PostgreSQL JDBC configuration
      |
      v
Datasource connectivity test
      |
      v
WAR deployment
      |
      v
Deployment verification
      |
      v
SHA-256 verification
      |
      v
Node Exporter
      |
      +--------------------+
      |                    |
      v                    v
    NRPE              Prometheus
      |                    |
      v                    v
    Nagios              Grafana
```

A successful deployment ends with the host fully integrated into the LAB environment.

---

## Deployment Safety

The WildFly deployment process includes several checks before an application is accepted as successfully deployed.

### Pre-flight validation

Before deployment Ansible verifies:

- application artifact exists
- WAR archive is valid
- required WAR structure is present
- PostgreSQL server is reachable
- WildFly datasource connection succeeds
- Ansible configuration is valid

### Artifact integrity

The source WAR SHA-256 checksum is calculated before deployment.

After deployment the checksum of the remote artifact is calculated again and compared with the source artifact.

A checksum file is stored alongside the deployed WAR:

```text
/opt/wildfly/standalone/deployments/
├── hello-wildfly.war
├── hello-wildfly.war.sha256
└── hello-wildfly.build-info.properties
```

### Automatic rollback

Before replacing an existing deployment, Ansible creates a backup.

If WildFly reports a deployment failure, the previous version can be automatically restored.

Old deployment backups are rotated and only the newest backups are retained.

---

## Build Metadata

Every application build contains metadata embedded directly inside the WAR:

```text
WEB-INF/classes/build-info.properties
```

Example:

```properties
git.commit=34ea560936ccb950a4a4971ba55545bb83acd484
git.ref=main
github.run.id=39635338435
github.run.number=54
```

For local builds the Git commit and branch are resolved locally, while GitHub-specific values are marked as local.

The same metadata is written to the WildFly deployment directory so the currently deployed version can be identified directly on the server.

---

## Deployment Summary

After verification Ansible reports information about the deployed application, including:

```text
Host
Application
Git commit
Git ref
GitHub Actions run ID
GitHub Actions run number
SHA-256
Application endpoint
```

This makes it possible to identify exactly which artifact is running on a particular host.

---

## Monitoring Onboarding

Monitoring is automatically configured after a successful application deployment.

### Node Exporter

Node Exporter is installed on the target host and exposes Linux host metrics on:

```text
:9100
```

### Prometheus

Prometheus configuration is generated dynamically from the Ansible inventory.

Each inventory host becomes a scrape target with its Ansible hostname attached as a label:

```yaml
labels:
  host: "rhel02"
```

Adding a host to the inventory and refreshing Prometheus automatically makes it available as a monitoring target.

### Grafana

Grafana uses Prometheus as its datasource.

New hosts registered in Prometheus become available in the LAB dashboards without manually adding individual Grafana targets.

### NRPE

NRPE provides service and operating-system checks used by Nagios.

Example checks include:

- system load
- root filesystem usage
- process count
- memory usage
- WildFly TCP/HTTP availability

For RHEL systems the role automatically prepares the package repositories required for NRPE and Nagios plugins.

### Nagios

Nagios host configuration is generated from the Ansible inventory.

A newly added host can therefore become visible in Nagios without maintaining a separate static host list.

The resulting monitoring architecture is:

```text
                  Ansible Inventory
                         |
              +----------+----------+
              |                     |
              v                     v
           Nagios                Prometheus
              |                     |
            NRPE              Node Exporter
              |                     |
              +------ LAB Host -----+
                                    |
                                    v
                                  Grafana
```

---

## WildFly Application

The example application is deployed as:

```text
hello-wildfly.war
```

Deployment directory:

```text
/opt/wildfly/standalone/deployments/
```

Example API endpoint:

```text
http://HOST:8080/hello-wildfly/api/hello/data
```

The application uses the WildFly datasource:

```text
AnsibleLabDS
```

with JNDI name:

```text
java:/jdbc/AnsibleLabDS
```

---

## Database Architecture

PostgreSQL runs on a dedicated database host.

The application hosts connect remotely to the database rather than running PostgreSQL locally.

```text
WildFly hosts
     |
     | JDBC
     v
database01
PostgreSQL
```

Example LAB database configuration:

```text
Database: ansible_lab
User:     ansible_app
```

Database credentials are stored using **Ansible Vault** and are not committed as plaintext secrets.

---

## Inventory

The LAB inventory is divided into functional groups.

Example structure:

```ini
[oracle]
oracle01
oracle02

[debian]
debian01
debian02
database01

[rhel]
rhel01
rhel02

[wildfly]
debian02
rhel01
rhel02

[java]
debian01
debian02
rhel01
rhel02

[database]
database01

[monitoring]
oracle01
```

Groups are used to assign infrastructure roles and application responsibilities.

---

## Fresh Host Requirements

Before using a new host with the LAB, the following minimum requirements apply:

- host is reachable over SSH
- SSH public-key authentication is configured
- Ansible user has sudo privileges
- Python 3 is available on the managed host
- host is added to the Ansible inventory
- required network connectivity between LAB systems is available

For registered RHEL hosts the NRPE role can automatically enable the required **CodeReady Builder** repository and install **EPEL**.

Example connectivity test:

```bash
ansible rhel02 -m ansible.builtin.ping
```

Privilege test:

```bash
ansible rhel02 -b -K -m ansible.builtin.command -a 'id'
```

---

## Control Node Requirements

The Ansible control node requires:

- Ansible
- Python
- Git
- Maven
- SSH client
- access to the LAB network

The project is developed from an Apple Silicon macOS control node using a Python virtual environment.

Example:

```bash
source ~/ansible/venv/bin/activate
```

---

## Running the WildFly Deployment Manually

The complete WildFly role can also be executed without the deployment wrapper:

```bash
ansible-playbook wildfly_role.yml -K --limit rhel02
```

Selected parts of the role can be executed using tags:

```bash
ansible-playbook wildfly_role.yml -K --limit rhel02 --tags datasource
```

```bash
ansible-playbook wildfly_role.yml -K --limit rhel02 --tags deploy
```

```bash
ansible-playbook wildfly_role.yml -K --limit rhel02 --tags verify
```

---

## Monitoring Playbooks

Node Exporter:

```bash
ansible-playbook node_exporter.yml -K --limit rhel02
```

NRPE:

```bash
ansible-playbook nrpe.yml -K --limit rhel02
```

Nagios:

```bash
ansible-playbook nagios.yml -K
```

Prometheus:

```bash
ansible-playbook prometheus.yml -K
```

---

## Idempotency

Roles are designed so repeated executions do not introduce unnecessary changes.

Example verified NRPE rerun:

```text
PLAY RECAP

rhel02 : ok=11 changed=0 unreachable=0 failed=0
```

Idempotency is treated as a core requirement rather than only a successful first execution.

---

## CI/CD

GitHub Actions is used to build and validate the application before deployment.

The pipeline includes:

```text
Source code
    |
    v
Maven build
    |
    v
Tests
    |
    v
Generate build metadata
    |
    v
Verify WAR contents
    |
    v
Upload artifact
    |
    v
Ansible deployment
    |
    v
Application verification
```

The deployment workflow can use artifacts generated by the CI workflow instead of rebuilding them on the application server.

---

## Repository Structure

Main areas of the repository include:

```text
.
├── applications/
│   └── hello-wildfly/
├── group_vars/
├── roles/
│   ├── java/
│   ├── wildfly/
│   ├── node_exporter/
│   ├── nrpe/
│   ├── nagios/
│   └── prometheus/
├── deploy-lab.sh
├── wildfly_role.yml
├── node_exporter.yml
├── nrpe.yml
├── nagios.yml
└── prometheus.yml
```

Additional roles and playbooks are used for other LAB services and experiments.

---

## Technologies

**Automation**

- Ansible
- Ansible Vault
- Bash
- GitHub Actions

**Application Platform**

- Java 21
- WildFly
- Maven

**Database**

- PostgreSQL
- JDBC

**Monitoring**

- Nagios
- NRPE
- Prometheus
- Node Exporter
- Grafana

**Operating Systems**

- Red Hat Enterprise Linux
- Debian
- Oracle Linux
- macOS control node

---

## Project Goals

The goal of this repository is to build practical experience with real administration and DevOps workflows rather than isolated Ansible examples.

Areas covered by the LAB include:

- Infrastructure as Code
- configuration management
- repeatable server provisioning
- application deployment
- CI/CD
- secrets management
- monitoring and observability
- deployment verification
- rollback strategies
- infrastructure troubleshooting
- Linux administration

The environment is intentionally developed incrementally: new hosts and services are used to expose hidden dependencies and improve the automation until a fresh system can be onboarded predictably.

---

## Current Result

A newly prepared LAB host can now go from:

```text
Fresh Linux VM
```

to:

```text
Java
+ WildFly
+ PostgreSQL datasource
+ deployed application
+ verified artifact
+ deployment metadata
+ Node Exporter
+ NRPE
+ Nagios monitoring
+ Prometheus monitoring
+ Grafana visibility
```

using the automated Ansible workflow.

The main entry point is:

```bash
./deploy-lab.sh <host>
```
