# Monitoring Stack

Prometheus and Grafana monitoring stack for the backend service.

## Components

### Prometheus
- **Purpose**: Metrics collection and storage
- **Port**: 9090
- **Access**: Port-forward or NodePort service

### Grafana
- **Purpose**: Visualization and dashboards
- **Port**: 3000
- **Default Credentials**: `admin` / `admin`

## Deployment

Deploy the monitoring stack:

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Deploy Prometheus
kubectl apply -f prometheus/

# Deploy Grafana
kubectl apply -f grafana/
```

Or deploy everything at once:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f prometheus/
kubectl apply -f grafana/
```

## Accessing Services

### Grafana

```bash
# Port-forward
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# Open browser
open http://localhost:3000
```

Login with: `admin` / `admin`

### Prometheus

```bash
# Port-forward
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# Open browser
open http://localhost:9090
```

## Metrics

Prometheus automatically scrapes:
- HAProxy pods with label `app=haproxy`
- Kubernetes API Server and nodes
- Kubernetes pods with `prometheus.io/scrape=true` annotation

## Grafana Dashboards

Pre-configured dashboards are available via ConfigMap. Access them in Grafana:
1. Go to **Dashboards**
2. Browse available dashboards
3. Create custom dashboards as needed

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n monitoring
```

### Check Prometheus Targets

1. Open Prometheus UI
2. Go to **Status** → **Targets**
3. Verify all targets are "UP"

### View Logs

```bash
# Prometheus logs
kubectl logs -n monitoring -l app=prometheus

# Grafana logs
kubectl logs -n monitoring -l app=grafana
```

### Restart Components

```bash
# Restart Prometheus
kubectl rollout restart deployment/prometheus -n monitoring

# Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

## Resource Requirements

- **Prometheus**: 512Mi-2Gi memory, 250m-1000m CPU
- **Grafana**: 256Mi-512Mi memory, 100m-500m CPU

## Data Retention

- **Prometheus**: 15 days (configurable in configmap)
