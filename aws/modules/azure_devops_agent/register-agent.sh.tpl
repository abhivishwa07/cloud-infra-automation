#!/bin/bash
# =============================================================================
# register-agent.sh.tpl
# MINIMAL user_data — used when launching from the Packer-baked AMI.
# All software is already installed. This only registers the agent.
# Boot time: < 1 minute (vs 15 minutes with full user_data)
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Azure DevOps Agent Registration ==="
echo "Timestamp: $(date)"

AGENT_DIR="/home/ubuntu/myagent"

# Verify agent binaries exist (should be pre-baked in AMI)
if [ ! -f "$AGENT_DIR/config.sh" ]; then
    echo "ERROR: Agent binaries not found in $AGENT_DIR"
    echo "This AMI may not have been built with Packer. Check AMI ID."
    exit 1
fi

# Ensure ubuntu owns the directory
chown -R ubuntu:ubuntu "$AGENT_DIR"

echo "Configuring agent: ${agent_name} → pool: ${azp_pool}"

# Write config script (avoids bash -c quoting issues)
cat > /tmp/register-agent.sh << 'REGSCRIPT'
#!/bin/bash
set -e
cd /home/ubuntu/myagent
./config.sh --unattended \
  --url "AZP_URL_PLACEHOLDER" \
  --auth pat \
  --token "AZP_TOKEN_PLACEHOLDER" \
  --pool "AZP_POOL_PLACEHOLDER" \
  --agent "AGENT_NAME_PLACEHOLDER" \
  --work "_work" \
  --replace \
  --acceptTeeEula
REGSCRIPT

# Replace placeholders with Terraform template values
sed -i "s|AZP_URL_PLACEHOLDER|${azp_url}|g"       /tmp/register-agent.sh
sed -i "s|AZP_TOKEN_PLACEHOLDER|${azp_token}|g"   /tmp/register-agent.sh
sed -i "s|AZP_POOL_PLACEHOLDER|${azp_pool}|g"     /tmp/register-agent.sh
sed -i "s|AGENT_NAME_PLACEHOLDER|${agent_name}|g" /tmp/register-agent.sh

chmod +x /tmp/register-agent.sh
sudo -u ubuntu /tmp/register-agent.sh
REGISTER_RC=$?
rm -f /tmp/register-agent.sh

if [ $REGISTER_RC -ne 0 ]; then
    echo "ERROR: Agent registration failed (exit $REGISTER_RC)"
    echo "Check: PAT token, pool name '${azp_pool}', org URL '${azp_url}'"
    exit 1
fi

echo "=== Starting Agent Service ==="
cd "$AGENT_DIR"
./svc.sh install ubuntu
./svc.sh start
./svc.sh status || true

echo "=== Agent Registration Complete! ==="
echo "Agent '${agent_name}' registered to pool '${azp_pool}'"
echo "Timestamp: $(date)"
ls -la "$AGENT_DIR"
