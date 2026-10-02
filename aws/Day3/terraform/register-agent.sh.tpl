#!/bin/bash
# =============================================================================
# Day3/terraform/register-agent.sh.tpl
# Minimal user_data — only registers the agent. All tools already in Packer AMI.
# Boot time: < 1 minute
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Azure DevOps Agent Registration ==="
echo "Timestamp : $(date)"
echo "Agent     : ${agent_name}"
echo "Pool      : ${azp_pool}"
echo "Org URL   : ${azp_url}"

AGENT_DIR="/home/ubuntu/myagent"

# Sanity check — binaries must be pre-baked in AMI
if [ ! -f "$AGENT_DIR/config.sh" ]; then
  echo "ERROR: $AGENT_DIR/config.sh not found."
  echo "Make sure the correct Packer AMI ID is set in terraform.tfvars."
  exit 1
fi

chown -R ubuntu:ubuntu "$AGENT_DIR"

# Write config script to file (avoids quoting issues inside bash -c)
cat > /tmp/register-agent.sh << 'EOF'
#!/bin/bash
set -e
cd /home/ubuntu/myagent
./config.sh --unattended \
  --url "AZP_URL" \
  --auth pat \
  --token "AZP_TOKEN" \
  --pool "AZP_POOL" \
  --agent "AGENT_NAME" \
  --work "_work" \
  --replace \
  --acceptTeeEula
EOF

sed -i "s|AZP_URL|${azp_url}|g"       /tmp/register-agent.sh
sed -i "s|AZP_TOKEN|${azp_token}|g"   /tmp/register-agent.sh
sed -i "s|AZP_POOL|${azp_pool}|g"     /tmp/register-agent.sh
sed -i "s|AGENT_NAME|${agent_name}|g" /tmp/register-agent.sh

chmod +x /tmp/register-agent.sh
sudo -u ubuntu /tmp/register-agent.sh
RC=$?
rm -f /tmp/register-agent.sh

if [ $RC -ne 0 ]; then
  echo "ERROR: Agent registration failed (exit $RC)"
  echo "Check PAT token scope (Agent Pools: Read & Manage)"
  exit 1
fi

echo "=== Starting Agent Service ==="
cd "$AGENT_DIR"
./svc.sh install ubuntu
./svc.sh start
./svc.sh status || true

echo ""
echo "=== Registration Complete ==="
echo "Agent '${agent_name}' is now online in pool '${azp_pool}'"
echo "Timestamp: $(date)"
ls -la "$AGENT_DIR"

# ── New Relic Installation via CLI ───────────────────────────────────────────
if [ -n "${nr_api_key}" ]; then
  echo ""
  echo "=== Installing New Relic Agent via CLI ==="
  export DEBIAN_FRONTEND=noninteractive
  curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
  NEW_RELIC_API_KEY="${nr_api_key}" NEW_RELIC_ACCOUNT_ID="${nr_account_id}" /usr/local/bin/newrelic install -y
  echo "=== New Relic Installed & Running Successfully ==="
fi
