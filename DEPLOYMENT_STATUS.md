# 🚀 Deployment Status

## ✅ Deployment Complete!

All services have been successfully deployed to your Kubernetes cluster.

## 📊 Running Services

### Backend Services
- **Hot Cluster**: 2 pods running
- **Standby Cluster**: 2 pods running
- **HAProxy Load Balancer**: 1 pod running

### Monitoring Stack
- **Prometheus**: 1 pod running
- **Grafana**: 1 pod running

## 🌐 Access URLs

### Port Forwarding (Currently Active)

All port forwards are running in the background:

1. **HAProxy (Load Balancer)**
   - URL: http://localhost:9090
   - Status: ✅ Active
   - Test: `curl http://localhost:9090/healthz`

2. **Grafana**
   - URL: http://localhost:3000
   - Username: `admin`
   - Password: `admin`
   - Status: ✅ Active

3. **Prometheus**
   - URL: http://localhost:9091
   - Status: ✅ Active

### NodePort Access (Alternative)

If you prefer NodePort access:

- **HAProxy**: http://<node-ip>:30090
- **Grafana**: http://<node-ip>:30300
- **Prometheus**: http://<node-ip>:30091

## 🔧 Useful Commands

### Check Pod Status
```bash
kubectl get pods -A
```

### Check Services
```bash
kubectl get svc -A
```

### View Logs
```bash
# HAProxy logs
kubectl logs -n default -l app=haproxy

# Backend logs (hot cluster)
kubectl logs -n default -l app=backend-service-hot

# Backend logs (standby cluster)
kubectl logs -n default -l app=backend-service,cluster=standby

# Prometheus logs
kubectl logs -n monitoring -l app=prometheus

# Grafana logs
kubectl logs -n monitoring -l app=grafana
```

### Test HAProxy
```bash
# Test health endpoint
curl http://localhost:9090/healthz

# Test root endpoint
curl http://localhost:9090/
```

### Restart Port Forwards

If port forwards stop, restart them:

```bash
# Use the helper script
./port-forward.sh

# Or manually:
kubectl port-forward -n default svc/haproxy 9090:9090 &
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
kubectl port-forward -n monitoring svc/prometheus 9091:9090 &
```

## 🧹 Cleanup

To remove all deployments:

```bash
./cleanup.sh
```

## 📝 Scripts Available

1. **deploy.sh** - Main deployment script
2. **port-forward.sh** - Start all port forwards
3. **cleanup.sh** - Remove all deployments

## 🎯 Next Steps

1. ✅ Access HAProxy at http://localhost:9090
2. ✅ Access Grafana at http://localhost:3000 (admin/admin)
3. ✅ Access Prometheus at http://localhost:9091
4. Configure Grafana dashboards
5. Set up alerts in Prometheus
6. Test failover by scaling down hot cluster
