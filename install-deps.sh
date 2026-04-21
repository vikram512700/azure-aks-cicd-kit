#!/usr/bin/env bash
# =============================================================================
# install-deps.sh — Install all dependencies for Azure AKS CI/CD Kit
# =============================================================================
# Run on a fresh Ubuntu VM (20.04 / 22.04 / 24.04):
#   chmod +x install-deps.sh
#   sudo ./install-deps.sh
#
# Installs: Git, Azure CLI, Terraform, kubectl, kubelogin, Docker, Helm, jq
# =============================================================================

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Azure AKS CI/CD Kit — Dependency Installer                ║"
echo "║  Target: Ubuntu VM (fresh install)                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ---------------------------------------------------------------------------
# Check if running as root
# ---------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root. Use: sudo ./install-deps.sh"
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. System update + basic tools
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 [1/7] Updating system & installing basic tools..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
apt-get update -y
apt-get install -y \
  git \
  curl \
  wget \
  unzip \
  jq \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common

echo "✅ Git & basic tools installed."
git --version

# ---------------------------------------------------------------------------
# 2. Azure CLI
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☁️  [2/7] Installing Azure CLI..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
echo "✅ Azure CLI installed."
az version

# ---------------------------------------------------------------------------
# 3. Terraform
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️  [3/7] Installing Terraform..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Add HashiCorp GPG key and repo
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform
echo "✅ Terraform installed."
terraform version

# ---------------------------------------------------------------------------
# 4. kubectl
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☸️  [4/7] Installing kubectl..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubectl
echo "✅ kubectl installed."
kubectl version --client

# ---------------------------------------------------------------------------
# 5. kubelogin (Azure AD auth for AKS)
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 [5/7] Installing kubelogin..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
KUBELOGIN_VERSION=$(curl -sL https://api.github.com/repos/Azure/kubelogin/releases/latest | jq -r '.tag_name')
curl -fsSL "https://github.com/Azure/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin-linux-amd64.zip" -o /tmp/kubelogin.zip
unzip -o /tmp/kubelogin.zip -d /tmp/kubelogin
mv /tmp/kubelogin/bin/linux_amd64/kubelogin /usr/local/bin/kubelogin
chmod +x /usr/local/bin/kubelogin
rm -rf /tmp/kubelogin /tmp/kubelogin.zip
echo "✅ kubelogin installed."
kubelogin --version

# ---------------------------------------------------------------------------
# 6. Docker
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 [6/7] Installing Docker..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Add Docker's official GPG key and repo
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow non-root user to run Docker (takes effect after re-login)
ACTUAL_USER="${SUDO_USER:-$USER}"
if [[ "$ACTUAL_USER" != "root" ]]; then
  usermod -aG docker "$ACTUAL_USER"
  echo "  ℹ️  Added '$ACTUAL_USER' to docker group (re-login to take effect)"
fi

systemctl enable docker
systemctl start docker
echo "✅ Docker installed."
docker --version

# ---------------------------------------------------------------------------
# 7. Helm (for NGINX ingress controller)
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⎈  [7/7] Installing Helm..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "✅ Helm installed."
helm version

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ ALL DEPENDENCIES INSTALLED SUCCESSFULLY                ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  Tool          Version                                     ║"
echo "║  ──────────    ───────────────────────                     ║"
echo "║  git           $(git --version | cut -d' ' -f3)                                     ║"
echo "║  az cli        $(az version --query '\"azure-cli\"' -o tsv 2>/dev/null)                                    ║"
echo "║  terraform     $(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1 | cut -d'v' -f2)                                    ║"
echo "║  kubectl       $(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo 'installed')               ║"
echo "║  kubelogin     $(kubelogin --version 2>&1 | head -1)       ║"
echo "║  docker        $(docker --version | cut -d' ' -f3 | tr -d ',')                                    ║"
echo "║  helm          $(helm version --short 2>/dev/null)                                   ║"
echo "║                                                            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  NEXT STEPS:                                               ║"
echo "║                                                            ║"
echo "║  1. Re-login (for Docker group to take effect):            ║"
echo "║     exit && ssh <your-vm>                                  ║"
echo "║                                                            ║"
echo "║  2. Login to Azure:                                        ║"
echo "║     az login                                               ║"
echo "║                                                            ║"
echo "║  3. Clone the project:                                     ║"
echo "║     git clone https://github.com/vikram512700/azure-aks-cicd-kit.git ║"
echo "║     cd azure-aks-cicd-kit                                  ║"
echo "║                                                            ║"
echo "║  4. Follow the README setup steps!                         ║"
echo "║                                                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
