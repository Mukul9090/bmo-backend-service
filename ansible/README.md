# Ansible Infrastructure Setup

Simple Ansible playbook for setting up Kubernetes infrastructure on bare servers/VMs.

## Purpose

This Ansible setup prepares infrastructure and **initializes Kubernetes cluster**:
- Installs Docker
- Installs Kubernetes tools (kubelet, kubeadm, kubectl)
- Configures system settings
- Applies security patches
- **Initializes Kubernetes cluster (kubeadm init)**
- **Installs CNI plugin (Calico)**
- **Sets up kubeconfig for kubectl**

**Note:** Application deployment is handled by GitHub Actions CI/CD pipeline. After Ansible runs, the cluster is ready for GitHub Actions to deploy.

## Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── hosts.yml           # Host definitions (update with your IPs)
├── group_vars/
│   └── all.yml             # Variables (K8s version, etc.)
└── playbooks/
    └── setup-infrastructure.yml    # Main playbook
```

## Prerequisites

```bash
# Install Ansible
pip install ansible
```

**Important:** This playbook supports both **macOS** and **Linux (Ubuntu/Debian)**:
- **macOS**: Installs Docker Desktop, kubectl, and minikube via Homebrew, then initializes Minikube cluster
- **Linux**: Installs Docker CE, kubelet/kubeadm/kubectl, then initializes cluster with kubeadm
- For production: Use this on actual Linux servers/VMs

## Usage

### 1. Update Inventory

The inventory is currently set to `localhost` for local testing. For remote Linux servers, edit `inventory/hosts.yml`:

```yaml
# For localhost (current setup)
localhost:
  ansible_host: localhost
  ansible_connection: local
  ansible_user: your_username

# For remote Linux servers (example)
k8s-hot-master:
  ansible_host: YOUR_SERVER_IP
  ansible_user: ubuntu
```

### 2. Setup Infrastructure

Run the playbook to install Docker and Kubernetes components:

```bash
cd ansible
ansible-playbook playbooks/setup-infrastructure.yml
```

This will:
- Update system packages
- Install Docker
- Install Kubernetes components (kubelet, kubeadm, kubectl)
- Verify kubectl is in PATH
- Configure kernel parameters (sysctl)
- Load required kernel modules
- Disable swap
- Apply security updates
- **Enable and start kubelet service**
- **Initialize Kubernetes cluster (kubeadm init)**
- **Set up kubeconfig for kubectl access (root and user)**
- **Install Calico CNI plugin for pod networking**
- **Wait for cluster to be ready**
- **Verify cluster API is accessible**
- **Verify cluster can accept deployments**
- **Display summary for GitHub Actions setup**

### 3. Verify Cluster (Automatic)

After Ansible completes, the cluster is automatically initialized and ready. Verify:

```bash
# Check cluster status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Test deployment
kubectl create namespace test
kubectl get namespaces
```

## What It Does

The `setup-infrastructure.yml` playbook:

1. **Installs Docker** - Container runtime required for Kubernetes
2. **Installs Kubernetes Tools** - kubelet, kubeadm, kubectl
3. **Configures System Settings**:
   - Kernel parameters (IP forwarding, bridge networking)
   - Kernel modules (br_netfilter, overlay)
   - Disables swap (required for K8s)
4. **Security**:
   - Applies security updates
5. **Initializes Kubernetes Cluster**:
   - Enables and starts kubelet service
   - Runs `kubeadm init` to initialize cluster
   - Sets up kubeconfig for kubectl access
   - Installs Calico CNI plugin for pod networking
   - Waits for cluster to be ready

## Testing

### On Linux Systems

```bash
# Test connectivity to all hosts
ansible all -m ping

# Check what will be changed (dry-run)
ansible-playbook playbooks/setup-infrastructure.yml --check

# Run with verbose output
ansible-playbook playbooks/setup-infrastructure.yml -v
```

### Testing on macOS (Using Docker Container)

Since the playbook is designed for Linux, test it in an Ubuntu container:

```bash
# Run the test setup script
./test-install.sh

# This creates an Ubuntu container and prepares it for Ansible
# Then run the playbook against the container
ansible-playbook -i inventory/hosts-test.yml playbooks/setup-infrastructure.yml
```

This allows you to see Ansible install everything from scratch in a real Linux environment.

## Notes

- Requires SSH key-based authentication (for remote hosts)
- Needs sudo/root access on target hosts
- Assumes Ubuntu/Debian-based Linux systems
- Update IPs in `inventory/hosts.yml` before running (for remote hosts)
- **Cluster is automatically initialized** - no manual kubeadm init needed
- **Cluster is ready for GitHub Actions CI/CD** after playbook completes

## Next Steps

After running this playbook:
1. ✅ Cluster is initialized and ready
2. ✅ CNI plugin (Calico) is installed
3. ✅ **Use GitHub Actions to deploy your application** - it will work immediately!

The cluster is fully configured and ready to accept deployments from your CI/CD pipeline.
