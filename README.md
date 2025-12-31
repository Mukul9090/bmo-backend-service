# Backend Service - High Availability Demo

A minimal Flask REST API for demonstrating hot/standby failover behavior.

![CI](https://github.com/YOUR_USERNAME/YOUR_REPO/workflows/CI/badge.svg)

## Project Structure

```
.
├── server.py              # Main Flask application
├── requirements.txt       # Python dependencies
├── Dockerfile             # Container image definition
├── .dockerignore          # Docker ignore patterns
├── .gitignore            # Git ignore patterns
├── k8s/                  # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── docs/                 # Documentation
    └── DEPLOY.md         # Kubernetes deployment guide
```

## Running Locally with Python

### Prerequisites
- Python 3.11 or higher
- pip

### Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the application:

**Hot (Primary) Instance:**
```bash
CLUSTER_ROLE=hot python server.py
```

**Standby Instance:**
```bash
CLUSTER_ROLE=standby python server.py
```

**Default (Unknown Role):**
```bash
python server.py
```

The application will be available at `http://localhost:8080`

### Testing Endpoints

**Health Check:**
```bash
curl http://localhost:8080/healthz
```

**Root Endpoint:**
```bash
curl http://localhost:8080/
```

## Running with Docker

### Build the image:
```bash
docker build -t backend-service .
```

### Run containers:

**Hot (Primary) Instance:**
```bash
docker run -p 8080:8080 -e CLUSTER_ROLE=hot backend-service
```

**Standby Instance:**
```bash
docker run -p 8081:8080 -e CLUSTER_ROLE=standby backend-service
```

Note: The standby instance uses port 8081 to avoid port conflicts when running both instances on the same machine.

### Testing Docker Containers

**Hot Instance:**
```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/
```

**Standby Instance:**
```bash
curl http://localhost:8081/healthz
curl http://localhost:8081/
```

## Kubernetes Deployment

### Minikube (Local Development)
For step-by-step Minikube deployment guide, see [docs/MINIKUBE.md](docs/MINIKUBE.md).

**Quick start:**
```bash
# Start Minikube
minikube start --driver=docker

# Build image in Minikube context
eval $(minikube docker-env)
docker build -t backend-service:latest .

# Deploy to Kubernetes
kubectl apply -f k8s/

# Access via port-forward
kubectl port-forward -n backend svc/backend-service 8080:80
```

### Other Kubernetes Clusters
For general Kubernetes deployment instructions, see [docs/DEPLOY.md](docs/DEPLOY.md).

## Simulating Failover

To demonstrate failover behavior:

1. Start the hot instance on port 8080
2. Start the standby instance on port 8081
3. Monitor both instances using their `/healthz` endpoints
4. Simulate a failure by stopping the hot instance
5. The standby instance can then be promoted to hot (by restarting with `CLUSTER_ROLE=hot`)

## CI/CD

This project uses GitHub Actions for continuous integration and deployment:

- **CI**: Runs on every push/PR - tests, builds Docker image, and validates code
- **CD**: Builds and pushes images to GitHub Container Registry on pushes to `main`
- **Release**: Builds and pushes release images when creating GitHub releases

See [.github/workflows/README.md](.github/workflows/README.md) for detailed workflow documentation.

### Running Tests Locally

```bash
# Install test dependencies
pip install -r requirements.txt

# Run tests
pytest

# Run with coverage
pytest --cov=server --cov-report=html
```
