# Backend Service - High Availability Demo

A minimal Flask REST API demonstrating hot/standby failover behavior with Kubernetes and HAProxy.

![CI](https://github.com/Mukul9090/bmo-backend-service/workflows/CI/badge.svg)

## Project Structure

```
.
├── server.py              # Main Flask application
├── requirements.txt       # Python dependencies
├── Dockerfile             # Container image definition
├── k8s/                   # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap-hot.yaml
│   ├── configmap-standby.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── haproxy-*.yaml     # HAProxy load balancer
├── monitoring/            # Prometheus & Grafana
└── docs/                  # Documentation
```

## Quick Start

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run hot instance
CLUSTER_ROLE=hot python server.py

# Run standby instance (in another terminal)
CLUSTER_ROLE=standby python server.py
```

Access at `http://localhost:8080`

### Docker

```bash
# Build image
docker build -t backend-service .

# Run hot instance
docker run -p 8080:8080 -e CLUSTER_ROLE=hot backend-service

# Run standby instance
docker run -p 8081:8080 -e CLUSTER_ROLE=standby backend-service
```

### Kubernetes

```bash
# Deploy to Kubernetes
kubectl apply -f k8s/

# Access via port-forward
kubectl port-forward -n backend svc/backend-service 8080:80
```

For detailed deployment guides, see [docs/](docs/).

## API Endpoints

- `GET /healthz` - Health check endpoint
- `GET /` - Root endpoint with service info

## Testing

```bash
# Run unit tests
pytest

# Run with coverage
pytest --cov=server --cov-report=html
```

## Documentation

- [Deployment Guide](docs/DEPLOY.md) - General Kubernetes deployment
- [CI/CD Pipeline](docs/CI-CD.md) - GitHub Actions setup and Docker Hub configuration

## Architecture

- **Hot Cluster**: Primary active cluster handling traffic
- **Standby Cluster**: Backup cluster ready for failover
- **HAProxy**: Load balancer with automatic failover
- **Monitoring**: Prometheus metrics and Grafana dashboards

## CI/CD

Automated CI/CD pipeline using GitHub Actions:
- **CI**: Tests and builds on every push/PR
- **CD**: Deploys to Kubernetes with hot/standby configuration

See [docs/CI-CD.md](docs/CI-CD.md) for details.
