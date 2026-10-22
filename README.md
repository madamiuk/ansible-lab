# Ansible Infrastructure & CI/CD Lab

Hands-on infrastructure automation lab built around **Ansible**, **Linux**, **WildFly**, **PostgreSQL**, **Apache**, **GitHub Actions** and a monitoring stack based on **Nagios**, **Prometheus** and **Grafana**.

The project focuses on practical System Engineering and DevOps workflows:

- provisioning fresh Linux hosts
- configuration management
- application and service deployment
- database connectivity
- secrets management
- deployment verification
- monitoring onboarding
- idempotency
- troubleshooting real infrastructure dependencies

The LAB is developed incrementally. New virtual machines are deliberately introduced as fresh systems to expose hidden assumptions and improve automation until hosts can be onboarded predictably.

---

## Current Capabilities

The repository currently provides automated provisioning workflows for:

| Platform | Entry point | Purpose |
|---|---|---|
| WildFly | `deploy-lab.sh` | Java application platform, datasource, WAR deployment and monitoring |
| PostgreSQL | `deploy-database.sh` | Database provisioning, access control, connectivity verification and monitoring |
| Apache | `deploy-apache.sh` | Web server provisioning, HTTP verification and monitoring |

Each workflow is designed to be repeatable and idempotent.

---

## One-command Provisioning

### WildFly application host

```bash
./deploy-lab.sh rhel02
```

The workflow performs:

```text
Host validation
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
WAR validation
      |
      v
Java provisioning
      |
      v
WildFly provisioning
      |
      v
PostgreSQL JDBC datasource
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
Monitoring onboarding
      |
      +-------------------+
      |                   |
      v                   v
    Nagios            Prometheus
                          |
                          v
                        Grafana
```

### PostgreSQL database host

```bash
./deploy-database.sh database02
```

The workflow performs:

```text
Host validation
      |
      v
SSH / Ansible connectivity
      |
      v
Privilege escalation check
      |
      v
Ansible syntax validation
      |
      v
PostgreSQL installation
      |
      v
Database + user provisioning
      |
      v
listen_addresses configuration
      |
      v
Declarative pg_hba.conf
      |
      v
Local service verification
      |
      v
Remote psql connection test
      |
      v
Monitoring onboarding
```

Remote PostgreSQL access is generated dynamically from the Ansible inventory.

Hosts allowed to connect to the application database belong to:

```ini
[db_clients]
debian01
debian02
rhel01
rhel02
```

The resulting `pg_hba.conf` therefore reflects infrastructure state defined in inventory instead of a hardcoded list of IP addresses.

### Apache web server

```bash
./deploy-apache.sh apache01
```

The workflow performs:

```text
Host validation
      |
      v
SSH / Ansible connectivity
      |
      v
Privilege escalation check
      |
      v
Ansible syntax validation
      |
      v
Apache/httpd installation
      |
      v
Web page deployment
      |
      v
Service activation
      |
      v
Firewall configuration
      |
      v
HTTP verification
      |
      v
Monitoring onboarding
```

The Apache role currently supports:

- Red Hat Enterprise Linux
- Oracle Linux
- Debian

---

## Infrastructure Architecture

Example LAB architecture:

```text
                     Ansible Control Node
                         macOS / ARM64
                              |
                              |
         +--------------------+--------------------+
         |                    |                    |
         v                    v                    v
   Application Hosts     Database Hosts       Web Servers
   WildFly / Java        PostgreSQL           Apache/httpd
         |                    ^                    |
         | JDBC               |                    |
         +--------------------+                    |
                                                   |
                         Monitoring                |
                             |                     |
              +--------------+--------------+      |
              |                             |      |
              v                             v      |
           Nagios                       Prometheus |
              |                             |      |
              |                             v      |
              |                           Grafana  |
              +-----------------------------+------+
```

PostgreSQL runs on dedicated database hosts.

Application servers connect remotely using JDBC rather than running the database locally.

---

## WildFly Deployment Safety

The WildFly deployment process includes several safeguards before an application is considered successfully deployed.

### Pre-flight validation

Ansible verifies:

- application artifact exists
- WAR archive is valid
- required WAR structure exists
- PostgreSQL is reachable
- WildFly datasource connection succeeds
- Ansible configuration is valid

### Artifact integrity

The source WAR SHA-256 checksum is calculated before deployment.

After deployment, the remote artifact checksum is calculated again and compared with the source.

Deployment metadata is stored alongside the application:

```text
/opt/wildfly/standalone/deployments/
├── hello-wildfly.war
├── hello-wildfly.war.sha256
└── hello-wildfly.build-info.properties
```

### Automatic rollback

Before replacing an existing deployment, Ansible creates a backup.

If WildFly reports a deployment failure, the previous artifact can be restored automatically.

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

The same information is stored on the target server so the deployed version can be identified directly from the filesystem.

---

## PostgreSQL Architecture

Example configuration:

```text
Application hosts
      |
      | PostgreSQL / JDBC
      v
database01 / database02
      |
      v
ansible_lab
```

Application database:

```text
Database: ansible_lab
User:     ansible_app
```

PostgreSQL configuration includes:

- database provisioning
- application user provisioning
- SCRAM authentication
- dynamic `listen_addresses`
- declarative `pg_hba.conf`
- access generated from the `[db_clients]` inventory group
- remote connectivity verification
- idempotent repeated execution

Database credentials are stored using **Ansible Vault**.

---

## Secrets and Privilege Escalation

Secrets are not stored as plaintext variables.

The LAB uses:

```text
group_vars/all/vault.yml
```

for encrypted values such as:

- PostgreSQL credentials
- sudo/become passwords

Host-specific privilege escalation passwords are mapped through Vault and exposed to Ansible using:

```yaml
ansible_become_password: "{{ vault_become_passwords[inventory_hostname] }}"
```

As a result, normal provisioning no longer requires repeated `BECOME password:` prompts.

Example:

```bash
ansible database02 -b -m ansible.builtin.command -a 'id'
```

---

## Monitoring

Monitoring onboarding is part of the provisioning workflow rather than a separate manual task.

### Node Exporter

Node Exporter exposes Linux host metrics on:

```text
:9100
```

### Prometheus

Prometheus targets are generated dynamically from the Ansible inventory.

Example:

```yaml
labels:
  host: "apache01"
```

Adding a host to inventory and refreshing the Prometheus configuration makes the host available for scraping.

### Grafana

Grafana uses Prometheus as its datasource.

New hosts automatically become available in dashboards once Prometheus begins collecting their metrics.

### Nagios

Nagios host configuration is generated from Ansible inventory.

Typical checks include:

```text
PING
SSH
HTTP
PostgreSQL TCP/5432
WildFly availability
system load
memory
filesystem usage
process count
```

NRPE is used where operating-system or application checks need to be executed remotely.

---

## Inventory Design

Inventory groups describe both operating systems and infrastructure responsibilities.

Example:

```ini
[oracle]
oracle01
oracle02

[debian]
debian01
debian02
database01
database02

[rhel]
rhel01
rhel02
apache01

[apache]
oracle01
oracle02
apache01

[wildfly]
debian02
rhel01
rhel02

[database]
database01
database02

[db_clients]
debian01
debian02
rhel01
rhel02

[http_servers]
oracle01
oracle02
debian01
debian02
apache01

[monitoring]
oracle01
```

Functional groups such as `[database]`, `[db_clients]`, `[apache]`, `[wildfly]`, `[http_servers]` and `[monitoring]` describe infrastructure responsibilities independently of the Linux distribution.

---

## Fresh Host Requirements

A new LAB host requires only the minimum operating-system bootstrap:

- SSH connectivity
- SSH public-key authentication
- Ansible user
- sudo privileges
- Python 3
- network connectivity
- inventory entry
- encrypted become password in Ansible Vault

Example connectivity test:

```bash
ansible apache01 -m ansible.builtin.ping
```

Privilege escalation test:

```bash
ansible apache01 -b -m ansible.builtin.command -a 'id'
```

For registered RHEL systems, roles can automatically configure additional repositories where required by installed components.

---

## Idempotency

Idempotency is treated as a core requirement.

A successful first execution is not sufficient — the same playbook must be safe to run repeatedly.

Examples from the LAB:

```text
database02 : ok=12 changed=0 unreachable=0 failed=0
apache01   : ok=6  changed=0 unreachable=0 failed=0
rhel02     : ok=13 changed=0 unreachable=0 failed=0
```

A second execution with `changed=0` and `failed=0` is used as an important validation step when developing or modifying roles.

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

Example endpoint:

```text
http://HOST:8080/hello-wildfly/api/hello/data
```

Datasource:

```text
AnsibleLabDS
```

JNDI:

```text
java:/jdbc/AnsibleLabDS
```

---

## CI/CD

GitHub Actions is used to build and validate the Java application before deployment.

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

Deployment can use artifacts generated by CI rather than rebuilding them directly on an application server.

---

## Repository Structure

Main areas of the repository:

```text
.
├── applications/
│   └── hello-wildfly/
├── group_vars/
│   └── all/
│       ├── main.yml
│       └── vault.yml
├── roles/
│   ├── apache/
│   ├── java/
│   ├── postgresql/
│   ├── wildfly/
│   ├── node_exporter/
│   ├── nrpe/
│   ├── nagios/
│   ├── prometheus/
│   └── grafana/
├── deploy-lab.sh
├── deploy-database.sh
├── deploy-apache.sh
├── wildfly_role.yml
├── postgresql_role.yml
├── apache_role.yml
├── node_exporter.yml
├── nrpe.yml
├── nagios.yml
└── prometheus.yml
```

Additional roles and playbooks are used for other LAB services and experiments.

---

## Technologies

### Automation

- Ansible
- Ansible Vault
- Bash
- Git
- GitHub Actions

### Linux

- Red Hat Enterprise Linux
- Debian
- Oracle Linux
- macOS control node

### Application Platform

- Java 21
- WildFly
- Maven

### Web

- Apache HTTP Server

### Database

- PostgreSQL
- JDBC

### Monitoring

- Nagios
- NRPE
- Prometheus
- Node Exporter
- Grafana

---

## Project Goals

The goal of the repository is to build practical experience with real System Engineering, Infrastructure Automation and DevOps workflows.

Areas covered include:

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
- service dependency management

The environment is intentionally developed from real failures and fresh-host tests rather than only from predefined examples.

Each new system is used to identify hidden assumptions and make the automation more portable and predictable.

---

## Current Result

The LAB can currently automate three different infrastructure paths:

```text
Fresh Linux VM
      |
      +----> WildFly + Java + Application
      |
      +----> PostgreSQL Database
      |
      +----> Apache Web Server
```

Each provisioned host can then be connected to:

```text
Node Exporter
Prometheus
Grafana
Nagios
```

with infrastructure state driven primarily from the Ansible inventory.

Main entry points:

```bash
./deploy-lab.sh <wildfly-host>
./deploy-database.sh <database-host>
./deploy-apache.sh <apache-host>
```

The next stages of the LAB continue the same approach by extending fresh-host automation to additional application and infrastructure services.
