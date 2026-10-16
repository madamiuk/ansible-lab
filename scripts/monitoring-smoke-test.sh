#!/usr/bin/env bash

# ============================================================
# Monitoring Stack Smoke Test
#
# Sprawdza:
#   - Nagios Core
#   - Apache/httpd
#   - Prometheus
#   - Grafana
#   - Node Exporter
#   - wymagane porty TCP
#   - konfigurację Nagios
#   - API Prometheus
#   - API Grafana
#   - endpoint Node Exporter
#   - wszystkie targety Prometheus
#
# Uruchamiany na serwerze monitoringowym oracle01.
# ============================================================

set -u

PASS=0
FAIL=0
WARN=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok() {
    echo -e "${GREEN}[ OK ]${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARN++))
}

section() {
    echo
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

check_service() {
    local service="$1"

    if systemctl is-active --quiet "$service"; then
        ok "Usługa $service jest active"
    else
        fail "Usługa $service NIE jest active"
    fi

    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        ok "Usługa $service jest enabled"
    else
        warn "Usługa $service NIE jest enabled"
    fi
}

check_port() {
    local port="$1"
    local description="$2"

    if ss -ltn | awk '{print $4}' | grep -Eq "[:.]${port}$"; then
        ok "Port $port nasłuchuje ($description)"
    else
        fail "Port $port NIE nasłuchuje ($description)"
    fi
}

check_http() {
    local url="$1"
    local description="$2"

    if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
        ok "$description"
    else
        fail "$description"
    fi
}


echo
echo "Monitoring Stack Smoke Test"
echo "Host: $(hostname)"
echo "Data: $(date)"
echo


# ------------------------------------------------------------
# Usługi systemd
# ------------------------------------------------------------

section "1. Usługi systemd"

check_service nagios
check_service httpd
check_service prometheus
check_service grafana-server
check_service node_exporter
check_service alertmanager
check_service sms-webhook

# ------------------------------------------------------------
# Porty
# ------------------------------------------------------------

section "2. Porty TCP"

check_port 80   "Apache / Nagios"
check_port 9090 "Prometheus"
check_port 3000 "Grafana"
check_port 9100 "Node Exporter"
check_port 9093 "Alertmanager"


# ------------------------------------------------------------
# Nagios
# ------------------------------------------------------------

section "3. Nagios Core"

if sudo /usr/sbin/nagios -v /etc/nagios/nagios.cfg >/dev/null 2>&1; then
    ok "Konfiguracja Nagios jest poprawna"
else
    fail "Błąd konfiguracji Nagios"
fi

NAGIOS_HTTP_CODE=$(
    curl -s \
         --max-time 5 \
         -o /dev/null \
         -w '%{http_code}' \
         http://127.0.0.1/nagios/
)

if [[ "$NAGIOS_HTTP_CODE" == "401" || "$NAGIOS_HTTP_CODE" == "200" ]]; then
    ok "Nagios WWW odpowiada (HTTP $NAGIOS_HTTP_CODE)"
else
    fail "Nagios WWW zwrócił HTTP $NAGIOS_HTTP_CODE"
fi


# ------------------------------------------------------------
# Prometheus
# ------------------------------------------------------------

section "4. Prometheus"

PROM_READY=$(
    curl -s --max-time 5 \
         http://127.0.0.1:9090/-/ready 2>/dev/null
)

if [[ "$PROM_READY" == *"Ready"* ]]; then
    ok "Prometheus jest READY"
else
    fail "Prometheus nie odpowiada jako READY"
fi


# ------------------------------------------------------------
# Grafana
# ------------------------------------------------------------

section "5. Grafana"

GRAFANA_HEALTH=$(
    curl -s --max-time 5 \
        http://127.0.0.1:3000/api/health 2>/dev/null
)

if echo "$GRAFANA_HEALTH" | \
    python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("database") == "ok" else 1)' \
    2>/dev/null
then
    ok "Grafana API działa, database=ok"
else
    fail "Grafana API nie działa poprawnie"
fi

# ------------------------------------------------------------
# Node Exporter
# ------------------------------------------------------------

section "6. Node Exporter"

NODE_EXPORTER_METRICS=$(
    curl -fsS --max-time 5 \
        http://127.0.0.1:9100/metrics 2>/dev/null
)

if grep -q '^node_uname_info' <<< "$NODE_EXPORTER_METRICS"; then
    ok "Node Exporter zwraca metryki"
else
    fail "Node Exporter nie zwraca poprawnych metryk"
fi

# ------------------------------------------------------------
# Targety Prometheus
# ------------------------------------------------------------

section "7. Targety Prometheus"

TARGET_RESULT=$(
curl -s --max-time 10 \
    http://127.0.0.1:9090/api/v1/targets |
python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception as exc:
    print("ERROR|Nie można odczytać API Prometheus: {}".format(exc))
    sys.exit(2)

targets = data["data"]["activeTargets"]

failed = 0

for target in targets:
    job = target["labels"].get("job", "?")
    instance = target["labels"].get("instance", "?")
    host = target["labels"].get("host", "")
    health = target.get("health", "unknown")

    name = host if host else instance

    print("{}|{}|{}|{}".format(
        health,
        job,
        name,
        instance
    ))

    if health != "up":
        failed += 1

sys.exit(1 if failed else 0)
'
)

TARGET_RC=$?

while IFS='|' read -r health job host instance; do

    [[ -z "$health" ]] && continue

    if [[ "$health" == "up" ]]; then
        ok "Prometheus target: $host [$job] ($instance)"
    elif [[ "$health" == "ERROR" ]]; then
        fail "$job"
    else
        fail "Prometheus target: $host [$job] ($instance) status=$health"
    fi

done <<< "$TARGET_RESULT"

# ------------------------------------------------------------
# Alertmanager
# ------------------------------------------------------------

section "8. Alertmanager"

ALERTMANAGER_READY=$(
    curl -s --max-time 5 \
        http://127.0.0.1:9093/-/ready 2>/dev/null
)

if [[ "$ALERTMANAGER_READY" == "OK" ]]; then
    ok "Alertmanager jest READY"
else
    fail "Alertmanager nie odpowiada jako READY"
fi

if /usr/local/bin/amtool check-config \
    /etc/alertmanager/alertmanager.yml >/dev/null 2>&1; then
    ok "Konfiguracja Alertmanager jest poprawna"
else
    fail "Błąd konfiguracji Alertmanager"
fi


# ------------------------------------------------------------
# Reguły Prometheus
# ------------------------------------------------------------

section "9. Reguły alertów Prometheus"

if /usr/local/bin/promtool check rules \
    /etc/prometheus/alerts.yml >/dev/null 2>&1; then
    ok "Plik reguł Prometheus jest poprawny"
else
    fail "Błąd reguł Prometheus"
fi

RULE_RESULT=$(
curl -s --max-time 5 \
    http://127.0.0.1:9090/api/v1/rules |
python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception as exc:
    print("ERROR|{}".format(exc))
    sys.exit(2)

count = 0
failed = 0

for group in data["data"]["groups"]:
    for rule in group["rules"]:
        if rule.get("type") != "alerting":
            continue

        count += 1

        name = rule.get("name", "?")
        health = rule.get("health", "unknown")
        state = rule.get("state", "unknown")

        print("{}|{}|{}".format(name, health, state))

        if health != "ok":
            failed += 1

print("COUNT|{}|".format(count))

sys.exit(1 if failed else 0)
'
)

while IFS='|' read -r name health state; do

    [[ -z "$name" ]] && continue

    if [[ "$name" == "ERROR" ]]; then
        fail "Nie można odczytać reguł z API Prometheus: $health"
        continue
    fi

    if [[ "$name" == "COUNT" ]]; then
        ok "Prometheus załadował $health reguł alertowych"
        continue
    fi

    if [[ "$health" == "ok" ]]; then
        ok "Reguła $name: health=$health state=$state"
    else
        fail "Reguła $name: health=$health state=$state"
    fi

done <<< "$RULE_RESULT"


# ------------------------------------------------------------
# Aktywne alerty
# ------------------------------------------------------------

section "10. Aktywne alerty"

PROM_ALERT_COUNT=$(
curl -s --max-time 5 \
    http://127.0.0.1:9090/api/v1/alerts |
python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
    print(len(data["data"]["alerts"]))
except Exception:
    sys.exit(1)
'
)

if [[ $? -eq 0 ]]; then
    if [[ "$PROM_ALERT_COUNT" -eq 0 ]]; then
        ok "Prometheus: brak aktywnych alertów"
    else
        warn "Prometheus: aktywne alerty = $PROM_ALERT_COUNT"
    fi
else
    fail "Nie można odczytać alertów Prometheus"
fi


AM_ALERT_COUNT=$(
curl -s --max-time 5 \
    http://127.0.0.1:9093/api/v2/alerts |
python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
    print(len(data))
except Exception:
    sys.exit(1)
'
)

if [[ $? -eq 0 ]]; then
    if [[ "$AM_ALERT_COUNT" -eq 0 ]]; then
        ok "Alertmanager: brak aktywnych alertów"
    else
        warn "Alertmanager: aktywne alerty = $AM_ALERT_COUNT"
    fi
else
    fail "Nie można odczytać alertów Alertmanager"
fi

# ------------------------------------------------------------
# NRPE / WildFly
# ------------------------------------------------------------

section "11. NRPE / WildFly"

CHECK_NRPE="/usr/lib64/nagios/plugins/check_nrpe"

if [[ -x "$CHECK_NRPE" ]]; then

    declare -A NRPE_HOSTS=(
        [debian02]="192.168.64.14"
        [rhel01]="192.168.64.16"
    )

    for host in "${!NRPE_HOSTS[@]}"; do

        ip="${NRPE_HOSTS[$host]}"

        result=$(
            "$CHECK_NRPE" \
                -H "$ip" \
                -c check_wildfly_http \
                2>&1
        )

        rc=$?

        if [[ $rc -eq 0 ]]; then
            ok "NRPE $host - WildFly HTTP: $result"
        else
            fail "NRPE $host - WildFly HTTP: $result"
        fi

    done

else
    warn "Nie znaleziono $CHECK_NRPE"
fi


# ------------------------------------------------------------
# Podsumowanie
# ------------------------------------------------------------

section "PODSUMOWANIE"

echo
echo -e "${GREEN}OK:      $PASS${NC}"
echo -e "${YELLOW}WARNING: $WARN${NC}"
echo -e "${RED}FAILED:  $FAIL${NC}"
echo

if [[ "$FAIL" -eq 0 ]]; then
    echo -e "${GREEN}MONITORING STACK: OK${NC}"
    echo
    exit 0
else
    echo -e "${RED}MONITORING STACK: PROBLEM${NC}"
    echo
    exit 1
fi
