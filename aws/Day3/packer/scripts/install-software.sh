#!/bin/bash
# =============================================================================
# Day3/packer/scripts/install-software.sh
# Packer provisioner — bakes all DevOps tools into the AMI.
# Agent registration is NOT done here (it's instance-specific).
# Run once → get a pre-baked AMI → Terraform uses it, boots in < 1 min.
# =============================================================================
set -eux

echo "============================================================"
echo "  PACKER BUILD: Installing DevOps Agent Software"
echo "  $(date)"
echo "============================================================"

# Prevent interactive apt prompts
export DEBIAN_FRONTEND=noninteractive

# ── Fix DNS (EC2's default resolver fails for Azure CDN domains) ──────────────
echo "nameserver 8.8.8.8" | tee -a /etc/resolv.conf
echo "nameserver 8.8.4.4" | tee -a /etc/resolv.conf

# ── [1] Base system dependencies ─────────────────────────────────────────────
echo ""
echo "=== [1/8] Installing base dependencies ==="
apt-get update -y
apt-get install -y \
  curl wget jq git unzip tar \
  build-essential \
  apt-transport-https \
  ca-certificates \
  software-properties-common \
  gnupg lsb-release

# ── [2] Azure DevOps Agent binaries (no registration) ────────────────────────
echo ""
echo "=== [2/8] Pre-installing Azure DevOps Agent binaries ==="
AGENT_VERSION="${AGENT_VERSION:-5.279.0}"
AGENT_DIR="/home/ubuntu/myagent"
mkdir -p "$AGENT_DIR"

AGENT_TAR="/tmp/vsts-agent.tar.gz"
PRIMARY_URL="https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz"
FALLBACK_URL="https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz"

echo "Agent version: $AGENT_VERSION"
echo "Downloading from: $PRIMARY_URL"

if ! curl -fsSL --retry 3 --retry-delay 5 --max-time 300 -o "$AGENT_TAR" "$PRIMARY_URL"; then
    echo "Primary URL failed, trying fallback..."
    curl -fsSL --retry 3 --retry-delay 5 --max-time 300 -o "$AGENT_TAR" "$FALLBACK_URL"
fi

tar -zxf "$AGENT_TAR" -C "$AGENT_DIR"
rm -f "$AGENT_TAR"

"$AGENT_DIR/bin/installdependencies.sh" || true
chown -R ubuntu:ubuntu "$AGENT_DIR"
echo "Agent binaries extracted to: $AGENT_DIR"
ls "$AGENT_DIR"

# ── [3] Java 17 & Maven ───────────────────────────────────────────────────────
echo ""
echo "=== [3/8] Installing Java 17 & Maven ==="
apt-get install -y openjdk-17-jdk maven
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
echo "export JAVA_HOME=$JAVA_HOME" >> /home/ubuntu/.bashrc
echo "JAVA_HOME=$JAVA_HOME" >> /etc/environment
java -version
mvn --version

# ── [4] Node.js 20 & Angular CLI ─────────────────────────────────────────────
echo ""
echo "=== [4/8] Installing Node.js 20 & Angular CLI ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g @angular/cli
node --version
npm --version
ng version || true

# ── [5] .NET 8.0 SDK ──────────────────────────────────────────────────────────
echo ""
echo "=== [5/8] Installing .NET 8.0 SDK ==="
curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
chmod +x /tmp/dotnet-install.sh
/tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet
ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
echo 'export DOTNET_ROOT=/usr/share/dotnet' >> /home/ubuntu/.bashrc
echo 'export PATH=$PATH:/usr/share/dotnet' >> /home/ubuntu/.bashrc
echo 'DOTNET_ROOT=/usr/share/dotnet' >> /etc/environment
rm -f /tmp/dotnet-install.sh
dotnet --version

# ── [6] Docker CE ─────────────────────────────────────────────────────────────
echo ""
echo "=== [6/8] Installing Docker CE ==="
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
rm -f /tmp/get-docker.sh
usermod -aG docker ubuntu || true
systemctl enable docker
docker --version

# ── [7] AWS CLI v2 ────────────────────────────────────────────────────────────
echo ""
echo "=== [7/8] Installing AWS CLI v2 ==="
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip
aws --version

# ── [8] Azure CLI ─────────────────────────────────────────────────────────────
echo ""
echo "=== [8/8] Installing Azure CLI ==="
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
az --version | head -1

# ── Cleanup to reduce AMI size ────────────────────────────────────────────────
echo ""
echo "=== Cleanup ==="
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*

echo ""
echo "============================================================"
echo "  PACKER BUILD COMPLETE — Installed Versions:"
echo "============================================================"
java -version 2>&1 | head -1
mvn --version 2>&1 | head -1
node --version
npm --version
dotnet --version
docker --version
aws --version
az --version 2>&1 | head -1
git --version
echo "Agent binaries: $(ls /home/ubuntu/myagent | wc -l) files"
echo "============================================================"
