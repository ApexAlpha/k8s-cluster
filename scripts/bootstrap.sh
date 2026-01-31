#!/run/current-system/sw/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Homelab GitOps Bootstrap Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster. Check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl connected to cluster${NC}"

# Check nodes
echo -e "\n${YELLOW}Cluster nodes:${NC}"
kubectl get nodes

# Check if cert-manager is installed
echo -e "\n${YELLOW}Checking cert-manager...${NC}"
if kubectl get namespace cert-manager &> /dev/null; then
    echo -e "${GREEN}✓ cert-manager namespace exists${NC}"
else
    echo -e "${YELLOW}Installing cert-manager...${NC}"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml
    echo "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
    echo -e "${GREEN}✓ cert-manager installed${NC}"
fi

# Install ArgoCD
echo -e "\n${YELLOW}Checking ArgoCD...${NC}"
if kubectl get namespace argocd &> /dev/null; then
    echo -e "${GREEN}✓ ArgoCD namespace exists${NC}"
else
    echo -e "${YELLOW}Installing ArgoCD...${NC}"
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    echo "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    echo -e "${GREEN}✓ ArgoCD installed${NC}"
fi

# Get ArgoCD admin password
echo -e "\n${YELLOW}ArgoCD admin credentials:${NC}"
echo "Username: admin"
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# Apply root application
echo -e "\n${YELLOW}Applying root application...${NC}"
kubectl apply -f clusters/homelab/apps.yaml

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Bootstrap complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "ArgoCD will now sync all applications."
echo ""
echo -e "${YELLOW}IMPORTANT: Sealed Secrets Setup${NC}"
echo ""
echo "Once Sealed Secrets controller is running, create your secrets:"
echo ""
echo "  ./scripts/seal-secret.sh"
echo ""
echo "This will encrypt your secrets so they're safe to commit to Git."
echo ""
echo "To access ArgoCD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Open: https://localhost:8080"
echo ""
echo "Or wait for Netbird operator to expose it."
echo ""
echo "Monitor sync status:"
echo "  watch kubectl get applications -n argocd"
