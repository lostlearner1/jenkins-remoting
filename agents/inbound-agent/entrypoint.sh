#!/bin/sh
set -e

JENKINS_URL="${JENKINS_URL:-http://jenkins-controller:8080}"
JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME:-linux-inbound-agent-02}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-admin123}"
JENKINS_AGENT_WORKDIR="${JENKINS_AGENT_WORKDIR:-/home/jenkins/agent}"

echo "[Inbound Agent] Waiting for Jenkins Controller at $JENKINS_URL..."
until curl -s -f "$JENKINS_URL/login" > /dev/null 2>&1; do
    echo "[Inbound Agent] Jenkins Controller is not ready yet. Retrying in 5 seconds..."
    sleep 5
done

echo "[Inbound Agent] Controller is UP. Fetching agent secret for '$JENKINS_AGENT_NAME'..."

SECRET=""
for i in $(seq 1 30); do
    JNLP_CONTENT=$(curl -s -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/computer/$JENKINS_AGENT_NAME/jenkins-agent.jnlp" 2>/dev/null || true)
    
    # Try parsing secret from <argument>hex_secret</argument>
    SECRET=$(echo "$JNLP_CONTENT" | grep -o '<argument>[a-f0-9]\{64\}</argument>' | sed 's/<[^>]*>//g' | head -n 1 || true)
    
    if [ -z "$SECRET" ]; then
        # Try alternate pattern
        SECRET=$(echo "$JNLP_CONTENT" | sed -n 's/.*<argument>\([a-f0-9]\{64\}\)<\/argument>.*/\1/p' | head -n 1 || true)
    fi

    if [ -n "$SECRET" ]; then
        echo "[Inbound Agent] Successfully acquired secret for $JENKINS_AGENT_NAME!"
        break
    fi

    echo "[Inbound Agent] Secret not ready yet (attempt $i/30). Waiting..."
    sleep 3
done

if [ -z "$SECRET" ]; then
    echo "[Inbound Agent] ERROR: Failed to retrieve JNLP secret after 30 attempts."
    echo "[Inbound Agent] Raw response from Controller:"
    curl -s -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/computer/$JENKINS_AGENT_NAME/jenkins-agent.jnlp" || true
    exit 1
fi

echo "[Inbound Agent] Connecting to Jenkins Remoting cluster..."
exec /usr/local/bin/jenkins-agent \
    -url "$JENKINS_URL" \
    -name "$JENKINS_AGENT_NAME" \
    -secret "$SECRET" \
    -workDir "$JENKINS_AGENT_WORKDIR"
