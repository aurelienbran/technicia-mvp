# Guide de gestion des logs TechnicIA

Ce document explique comment configurer, gérer et analyser les logs de TechnicIA pour un suivi efficace des erreurs et des performances du système.

## Table des matières

1. [Configuration des logs](#configuration-des-logs)
2. [Rotation et rétention des logs](#rotation-et-rétention-des-logs)
3. [Centralisation des logs](#centralisation-des-logs)
4. [Analyse des logs](#analyse-des-logs)
5. [Alertes basées sur les logs](#alertes-basées-sur-les-logs)
6. [Outils recommandés](#outils-recommandés)

## Configuration des logs

### Configuration par service

Chaque microservice TechnicIA peut être configuré individuellement pour adapter le niveau de détail des logs:

#### document-processor

Pour augmenter le niveau de détail dans document-processor, modifiez le fichier `services/document-processor/main.py`:

```python
# Modifier le niveau de logging pour le débogage
logging.basicConfig(
    level=logging.DEBUG,  # Changer INFO en DEBUG
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
```

#### vision-classifier

Pour activer les logs détaillés dans vision-classifier:

```python
# Activer les logs détaillés pour Vision AI
logging.getLogger('google.cloud.vision').setLevel(logging.DEBUG)
```

#### vector-store

Pour activer les logs détaillés des appels API dans vector-store:

```python
# Activer les logs détaillés pour les appels API
logging.getLogger('httpx').setLevel(logging.DEBUG)
```

### Configuration Docker

Pour les logs Docker, créez un fichier `daemon.json` dans `/etc/docker/`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  }
}
```

Redémarrez Docker après modification:

```bash
sudo systemctl restart docker
```

### Configuration n8n

Pour les logs n8n, ajoutez ces variables d'environnement dans `docker/docker-compose.yml`:

```yaml
services:
  n8n:
    environment:
      - N8N_LOG_LEVEL=debug  # Options: info, warn, error, debug
      - N8N_LOG_OUTPUT=console
```

## Rotation et rétention des logs

### Logrotate pour les logs système

Créez un fichier `/etc/logrotate.d/technicia`:

```
/var/log/technicia/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
```

### Docker logs

Pour configurer la rotation des logs Docker, ajoutez un fichier `docker-compose.override.yml` dans `docker/`:

```yaml
version: '3.8'

services:
  document-processor:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"
        
  vision-classifier:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"
        
  vector-store:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"
        
  n8n:
    logging:
      driver: "json-file"
      options:
        max-size: "200m"
        max-file: "5"
```

## Centralisation des logs

### Option 1: Script de collecte simple

Créez un script de collecte des logs:

```bash
#!/bin/bash
# collect_logs.sh

LOG_DIR="/var/log/technicia"
mkdir -p $LOG_DIR

# Collect logs from all services
docker logs technicia-document-processor > $LOG_DIR/document-processor.log
docker logs technicia-vision-classifier > $LOG_DIR/vision-classifier.log
docker logs technicia-vector-store > $LOG_DIR/vector-store.log
docker logs technicia-n8n > $LOG_DIR/n8n.log
docker logs technicia-qdrant > $LOG_DIR/qdrant.log

echo "Logs collected in $LOG_DIR"
```

Ajoutez-le à crontab pour exécution périodique:

```
0 * * * * /opt/technicia/scripts/collect_logs.sh
```

### Option 2: ELK/EFK Stack

Pour une solution plus robuste, configurez ELK (Elasticsearch, Logstash, Kibana) ou EFK (Elasticsearch, Fluentd, Kibana).

Ajoutez ces services à votre `docker-compose.yml`:

```yaml
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.13.4
    container_name: technicia-elasticsearch
    environment:
      - "discovery.type=single-node"
    ports:
      - "9200:9200"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    networks:
      - technicia-network

  kibana:
    image: docker.elastic.co/kibana/kibana:7.13.4
    container_name: technicia-kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    networks:
      - technicia-network

  fluentd:
    image: fluent/fluentd:v1.12
    container_name: technicia-fluentd
    volumes:
      - ./fluentd/conf:/fluentd/etc
    depends_on:
      - elasticsearch
    networks:
      - technicia-network

volumes:
  es_data:
```

## Analyse des logs

### Outils d'analyse en ligne de commande

Utilisez ces commandes pour extraire des informations utiles:

```bash
# Chercher les erreurs dans tous les services
for service in document-processor vision-classifier vector-store n8n; do
  echo "=== Erreurs dans $service ==="
  docker logs technicia-$service 2>&1 | grep -i error
done

# Analyser les échecs de traitement PDF
docker logs technicia-document-processor | grep -i "error.*pdf" | sort | uniq -c

# Vérifier les temps de traitement longs
docker logs technicia-document-processor | grep -i "processing time" | awk '{print $NF}' | sort -n
```

### Script d'analyse des logs

Créez un script d'analyse quotidienne:

```python
#!/usr/bin/env python3
# analyze_logs.py

import re
import subprocess
import datetime

def get_docker_logs(service, since="1h"):
    cmd = ["docker", "logs", f"technicia-{service}", f"--since={since}"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout

def count_errors(logs):
    return len(re.findall(r"error", logs, re.IGNORECASE))

def count_warnings(logs):
    return len(re.findall(r"warning", logs, re.IGNORECASE))

def parse_processing_times(logs):
    times = re.findall(r"processing time: ([0-9.]+)", logs, re.IGNORECASE)
    return [float(t) for t in times]

services = ["document-processor", "vision-classifier", "vector-store", "n8n"]
report = []

report.append(f"=== TechnicIA Log Analysis - {datetime.datetime.now().isoformat()} ===\n")

for service in services:
    logs = get_docker_logs(service)
    errors = count_errors(logs)
    warnings = count_warnings(logs)
    
    report.append(f"== {service} ==")
    report.append(f"Errors: {errors}")
    report.append(f"Warnings: {warnings}")
    
    if service == "document-processor":
        times = parse_processing_times(logs)
        if times:
            avg_time = sum(times) / len(times)
            report.append(f"Average processing time: {avg_time:.2f}s")
            report.append(f"Max processing time: {max(times):.2f}s")
    
    report.append("")

print("\n".join(report))

# Save report
with open(f"/var/log/technicia/analysis_{datetime.date.today()}.txt", "w") as f:
    f.write("\n".join(report))
```

## Alertes basées sur les logs

### Alerte par email

Créez un script d'alerte:

```bash
#!/bin/bash
# alert.sh

LOG_DIR="/var/log/technicia"
ADMIN_EMAIL="admin@example.com"

# Check for critical errors
if docker logs --since=1h technicia-document-processor 2>&1 | grep -i "critical error"; then
    echo "ALERTE: Erreurs critiques détectées dans document-processor" | \
    mail -s "TechnicIA ALERTE" $ADMIN_EMAIL
fi

# Check for API key issues
if docker logs --since=1h technicia-vector-store 2>&1 | grep -i "api key.*error"; then
    echo "ALERTE: Problème de clé API dans vector-store" | \
    mail -s "TechnicIA ALERTE" $ADMIN_EMAIL
fi

# Check if services are running
for service in document-processor vision-classifier vector-store n8n; do
    if ! docker ps | grep -q "technicia-$service"; then
        echo "ALERTE: Le service $service n'est pas en cours d'exécution" | \
        mail -s "TechnicIA ALERTE" $ADMIN_EMAIL
    fi
done
```

Ajoutez-le à crontab:

```
*/10 * * * * /opt/technicia/scripts/alert.sh
```

## Outils recommandés

### Surveillance et analyse

- **Prometheus + Grafana**: Pour le monitoring et la visualisation
- **Loki**: Pour la collecte et l'indexation des logs
- **Graylog**: Solution complète de gestion de logs
- **ELK Stack**: Solution robuste mais nécessitant plus de ressources

### Outils en ligne de commande

- **lnav**: Navigateur de logs avancé
- **jq**: Manipulation de JSON en ligne de commande
- **gawk**: Analyse avancée de texte
- **multitail**: Visualisation de plusieurs logs simultanément

---

Avec une configuration appropriée des logs, vous pouvez identifier rapidement les problèmes dans TechnicIA et améliorer continuellement la stabilité du système.
