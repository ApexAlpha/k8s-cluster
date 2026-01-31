#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Sealed Secrets Helper${NC}"
echo -e "${BLUE}========================================${NC}"

# Check kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo -e "${RED}kubeseal not found. Installing...${NC}"
    
    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
        curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
        tar -xzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
        sudo install -m 755 kubeseal /usr/local/bin/kubeseal
        rm kubeseal kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install kubeseal
    else
        echo -e "${RED}Please install kubeseal manually${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ kubeseal is installed${NC}"

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to cluster. Check kubeconfig.${NC}"
    exit 1
fi

# Check sealed-secrets controller
if ! kubectl get deployment sealed-secrets-controller -n kube-system &> /dev/null; then
    echo -e "${RED}Sealed Secrets controller not found in cluster.${NC}"
    echo -e "${YELLOW}Make sure ArgoCD has synced the sealed-secrets application.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Sealed Secrets controller is running${NC}"

# Menu
echo ""
echo "What would you like to seal?"
echo ""
echo "  1) Netbird API Key"
echo "  2) Vaultwarden Database Credentials"
echo "  3) Vaultwarden Admin Token"
echo "  4) SeaweedFS S3 Credentials"
echo "  5) Custom Secret"
echo ""
read -p "Select option (1-5): " choice

seal_secret() {
    local input_file=$1
    local output_file=$2
    
    echo -e "${YELLOW}Sealing secret...${NC}"
    kubeseal --controller-name=sealed-secrets-controller \
             --controller-namespace=kube-system \
             --format yaml \
             < "$input_file" \
             > "$output_file"
    
    rm "$input_file"
    echo -e "${GREEN}✓ Sealed secret created: $output_file${NC}"
    echo -e "${YELLOW}Don't forget to commit this file to Git!${NC}"
}

case $choice in
    1)
        echo ""
        read -p "Enter Netbird API Key: " -s nb_key
        echo ""
        
        cat > /tmp/netbird-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: netbird-mgmt-api-key
  namespace: netbird
type: Opaque
stringData:
  NB_API_KEY: "${nb_key}"
EOF
        
        mkdir -p "${REPO_ROOT}/apps/netbird-operator/manifests"
        seal_secret /tmp/netbird-secret.yaml "${REPO_ROOT}/apps/netbird-operator/manifests/sealed-secret.yaml"
        ;;
        
    2)
        echo ""
        read -p "Database username [vaultwarden]: " db_user
        db_user=${db_user:-vaultwarden}
        read -p "Database password: " -s db_pass
        echo ""
        read -p "Database host [main-db-rw.databases.svc]: " db_host
        db_host=${db_host:-main-db-rw.databases.svc}
        read -p "Database name [vaultwarden]: " db_name
        db_name=${db_name:-vaultwarden}
        
        cat > /tmp/vaultwarden-db.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: vaultwarden-db-credentials
  namespace: apps
type: Opaque
stringData:
  uri: "postgresql://${db_user}:${db_pass}@${db_host}:5432/${db_name}"
EOF
        
        mkdir -p "${REPO_ROOT}/apps/vaultwarden/manifests"
        seal_secret /tmp/vaultwarden-db.yaml "${REPO_ROOT}/apps/vaultwarden/manifests/sealed-db-secret.yaml"
        ;;
        
    3)
        echo ""
        echo "Generating random admin token..."
        admin_token=$(openssl rand -base64 48)
        echo -e "${YELLOW}Admin token (save this!): ${admin_token}${NC}"
        
        cat > /tmp/vaultwarden-admin.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: vaultwarden-admin
  namespace: apps
type: Opaque
stringData:
  token: "${admin_token}"
EOF
        
        mkdir -p "${REPO_ROOT}/apps/vaultwarden/manifests"
        seal_secret /tmp/vaultwarden-admin.yaml "${REPO_ROOT}/apps/vaultwarden/manifests/sealed-admin-secret.yaml"
        ;;
        
    4)
        echo ""
        read -p "S3 Access Key: " s3_access
        read -p "S3 Secret Key: " -s s3_secret
        echo ""
        
        cat > /tmp/seaweedfs-s3.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: seaweedfs-s3-creds
  namespace: databases
type: Opaque
stringData:
  access-key: "${s3_access}"
  secret-key: "${s3_secret}"
EOF
        
        mkdir -p "${REPO_ROOT}/apps/cnpg-cluster/manifests"
        seal_secret /tmp/seaweedfs-s3.yaml "${REPO_ROOT}/apps/cnpg-cluster/manifests/sealed-s3-secret.yaml"
        ;;
        
    5)
        echo ""
        read -p "Secret name: " secret_name
        read -p "Namespace: " namespace
        read -p "Key name: " key_name
        read -p "Value: " -s value
        echo ""
        read -p "Output path (relative to repo root): " output_path
        
        cat > /tmp/custom-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
type: Opaque
stringData:
  ${key_name}: "${value}"
EOF
        
        output_dir=$(dirname "${REPO_ROOT}/${output_path}")
        mkdir -p "$output_dir"
        seal_secret /tmp/custom-secret.yaml "${REPO_ROOT}/${output_path}"
        ;;
        
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Next steps:"
echo "  1. git add -A"
echo "  2. git commit -m 'Add sealed secret'"
echo "  3. git push"
echo "  4. ArgoCD will sync and unseal the secret"
