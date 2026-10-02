#!/bin/bash
# NOTE: set -e is intentionally NOT used here.
# set -e aborts the entire script on any non-zero exit, leaving myagent empty.
# We check exit codes explicitly at critical steps instead.

# Log all output to /var/log/user-data.log
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== [1/7] Installing Base Dependencies ==="
apt-get update -y
apt-get install -y curl jq git unzip tar build-essential \
  apt-transport-https ca-certificates software-properties-common

# Fix DNS: EC2's default resolver (169.254.169.253) cannot resolve Azure CDN domains.
# Add Google DNS so all Microsoft/Azure download URLs resolve correctly.
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "DNS updated: $(cat /etc/resolv.conf)"

# ─── [2/7] Azure DevOps Agent ─────────────────────────────────────────────────
echo "=== [2/7] Downloading and Registering Azure DevOps Agent ==="
AGENT_DIR="/home/ubuntu/myagent"
mkdir -p "$AGENT_DIR"

# ── Wait for full network / DNS to be ready ──────────────────────────────────
echo "Waiting for network and DNS to be ready..."
for i in $(seq 1 30); do
    if curl -sf --max-time 5 https://www.google.com > /dev/null 2>&1; then
        echo "Network is ready (attempt $i)."
        break
    fi
    echo "Network not ready yet (attempt $i/30), waiting 5s..."
    sleep 5
done

# Resolve agent version. Try GitHub API first; fall back to known-good version.
AGENT_VERSION="${agent_version}"
if [ "$AGENT_VERSION" = "latest" ] || [ -z "$AGENT_VERSION" ]; then
    AGENT_VERSION=$(curl -sf --max-time 15 \
        "https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest" \
        | jq -r '.tag_name // empty' | sed 's/^v//' || true)
fi
# Hardcoded fallback — keep in sync with latest agent release
if [ -z "$AGENT_VERSION" ] || [ "$AGENT_VERSION" = "null" ]; then
    AGENT_VERSION="5.279.0"
fi
echo "Using Azure DevOps Agent version: $AGENT_VERSION"

# Download URLs in priority order:
# 1. New official domain (download.agent.dev.azure.com)
# 2. Legacy Azure CDN  (vstsagentpackage.azureedge.net)
# 3. GitHub releases   (github.com)
URL_NEW="https://download.agent.dev.azure.com/agent/$${AGENT_VERSION}/vsts-agent-linux-x64-$${AGENT_VERSION}.tar.gz"
URL_CDN="https://vstsagentpackage.azureedge.net/agent/$${AGENT_VERSION}/vsts-agent-linux-x64-$${AGENT_VERSION}.tar.gz"
URL_GH="https://github.com/microsoft/azure-pipelines-agent/releases/download/v$${AGENT_VERSION}/vsts-agent-linux-x64-$${AGENT_VERSION}.tar.gz"

AGENT_TAR="/tmp/vsts-agent.tar.gz"
DOWNLOADED=false

for URL in "$URL_NEW" "$URL_CDN" "$URL_GH"; do
    echo "Trying: $URL"
    if curl -fsSL --retry 2 --retry-delay 5 --max-time 300 -o "$AGENT_TAR" "$URL"; then
        DOWNLOADED=true
        echo "Downloaded successfully from: $URL"
        break
    fi
    echo "Failed: $URL — trying next..."
done

if [ "$DOWNLOADED" != "true" ] || [ ! -f "$AGENT_TAR" ]; then
    echo "ERROR: Failed to download agent from all sources. Aborting."
    exit 1
fi

# Extract directly into AGENT_DIR
tar -zxf "$AGENT_TAR" -C "$AGENT_DIR"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to extract agent tarball. Aborting."
    exit 1
fi
rm -f "$AGENT_TAR"

echo "Installing Agent system dependencies..."
"$AGENT_DIR/bin/installdependencies.sh" || true

# Fix ownership BEFORE config so ubuntu user can write
chown -R ubuntu:ubuntu "$AGENT_DIR"

echo "Configuring agent with Azure DevOps..."
# Write the config command to a temp script to avoid bash -c quoting issues
cat > /tmp/configure-agent.sh << SCRIPT
#!/bin/bash
set -e
cd "$AGENT_DIR"
./config.sh --unattended \
  --url "${azp_url}" \
  --auth pat \
  --token "${azp_token}" \
  --pool "${azp_pool}" \
  --agent "${agent_name}" \
  --work "_work" \
  --replace \
  --acceptTeeEula
SCRIPT
chmod +x /tmp/configure-agent.sh
sudo -u ubuntu /tmp/configure-agent.sh
CONFIG_RC=$?
rm -f /tmp/configure-agent.sh

if [ $CONFIG_RC -ne 0 ]; then
    echo "ERROR: Agent config.sh failed (exit $CONFIG_RC)."
    echo "Check: PAT token scope, pool name '${azp_pool}', org URL '${azp_url}'"
    exit 1
fi

echo "Installing and starting agent systemd service..."
cd "$AGENT_DIR"
./svc.sh install ubuntu
./svc.sh start
./svc.sh status || true

echo "=== Agent folder contents after setup ==="
ls -la "$AGENT_DIR"

# ─── Return to safe working dir for remaining installs ─────────────────────────
cd /tmp

# ─── [3/7] Java 17 & Maven ────────────────────────────────────────────────────
echo "=== [3/7] Installing Java 17 & Maven ==="
apt-get install -y openjdk-17-jdk maven
echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" >> /home/ubuntu/.bashrc

# ─── [4/7] Node.js 20 & Angular CLI ──────────────────────────────────────────
echo "=== [4/7] Installing Node.js 20 & Angular CLI ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g @angular/cli

# ─── [5/7] .NET 8.0 SDK ──────────────────────────────────────────────────────
echo "=== [5/7] Installing .NET 8.0 SDK ==="
curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
chmod +x /tmp/dotnet-install.sh
/tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet
ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
echo 'export DOTNET_ROOT=/usr/share/dotnet' >> /home/ubuntu/.bashrc
echo 'export PATH=$PATH:/usr/share/dotnet' >> /home/ubuntu/.bashrc
rm -f /tmp/dotnet-install.sh

# ─── [6/7] Docker CE ─────────────────────────────────────────────────────────
echo "=== [6/7] Installing Docker CE ==="
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
rm -f /tmp/get-docker.sh
usermod -aG docker ubuntu || true
chmod 666 /var/run/docker.sock || true

# ─── [7/7] AWS CLI v2 & Azure CLI ────────────────────────────────────────────
echo "=== [7/7] Installing AWS CLI v2 & Azure CLI ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# ─── Done ─────────────────────────────────────────────────────────────────────
echo "=== All installations completed successfully! ==="
echo "=== Final myagent directory state ==="
ls -la "$AGENT_DIR"
