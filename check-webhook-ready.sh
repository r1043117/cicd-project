#!/bin/bash
# Webhook Prerequisites Check Script v2
# Run this on VM2 (Jenkins server)

echo "======================================"
echo "GitHub Webhook Prerequisites Check v2"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Check if Jenkins is running
echo "1. Checking Jenkins service..."
if systemctl is-active --quiet jenkins; then
    check_pass "Jenkins is running"
else
    check_fail "Jenkins is not running"
    echo "   Fix: sudo systemctl start jenkins"
fi
echo ""

# 2. Check Jenkins port
echo "2. Checking Jenkins port 8080..."
if command -v ss &> /dev/null; then
    if ss -tuln | grep -q ':8080'; then
        check_pass "Port 8080 is listening"
    else
        check_fail "Port 8080 is not listening"
    fi
elif command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ':8080'; then
        check_pass "Port 8080 is listening"
    else
        check_fail "Port 8080 is not listening"
    fi
else
    check_warn "Cannot verify port (ss/netstat not found)"
fi
echo ""

# 3. Get IPv4 address (required for GitHub webhooks)
echo "3. Detecting IPv4 address..."
IPV4=""

# Try multiple methods to get IPv4
IPV4=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)

if [ -z "$IPV4" ]; then
    IPV4=$(hostname -I | awk '{print $1}')
fi

if [ -z "$IPV4" ]; then
    IPV4=$(curl -4 -s ifconfig.me 2>/dev/null)
fi

if [[ "$IPV4" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    check_pass "IPv4 address detected: $IPV4"
else
    check_fail "Could not detect valid IPv4 address"
    echo "   Detected: $IPV4"
    echo "   GitHub webhooks require IPv4, not IPv6"
fi
echo ""

# 4. Check if IPv4 is public or private
echo "4. Checking if IP is publicly accessible..."
if [[ "$IPV4" =~ ^10\. ]] || [[ "$IPV4" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$IPV4" =~ ^192\.168\. ]]; then
    check_warn "IP $IPV4 is a PRIVATE address"
    echo "   This is likely behind NAT/router"
    echo "   You need to:"
    echo "   - Forward port 8080 on your router to this VM"
    echo "   - Or use ngrok/localtunnel for testing"
    echo "   - Or get a public IP from your cloud provider"
    echo ""
    
    # Try to get public IP
    PUBLIC_IPV4=$(curl -4 -s ifconfig.me 2>/dev/null)
    if [ ! -z "$PUBLIC_IPV4" ] && [ "$PUBLIC_IPV4" != "$IPV4" ]; then
        echo "   Your router's public IP: $PUBLIC_IPV4"
        echo "   Configure port forwarding: $PUBLIC_IPV4:8080 → $IPV4:8080"
    fi
else
    check_pass "IP $IPV4 appears to be public"
fi
echo ""

# 5. Test webhook endpoint
echo "5. Testing Jenkins webhook endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/github-webhook/ 2>/dev/null)

if [ "$HTTP_CODE" = "405" ]; then
    check_pass "Webhook endpoint is ready (HTTP 405 is expected)"
    echo "   405 = Method Not Allowed (needs POST, not GET)"
elif [ "$HTTP_CODE" = "403" ]; then
    check_pass "Webhook endpoint exists (HTTP 403)"
    echo "   May need to configure CSRF or authentication"
elif [ "$HTTP_CODE" = "200" ]; then
    check_pass "Webhook endpoint is accessible (HTTP 200)"
else
    check_fail "Unexpected response: HTTP $HTTP_CODE"
fi
echo ""

# 6. Check Git repository
echo "6. Checking Git repository..."
if [ -d "/opt/cicd-project/.git" ]; then
    check_pass "Git repository exists"
    cd /opt/cicd-project
    REPO_URL=$(git remote get-url origin 2>/dev/null)
    if [ ! -z "$REPO_URL" ]; then
        echo "   Repository: $REPO_URL"
        
        # Extract GitHub username/repo
        if [[ "$REPO_URL" =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
            GITHUB_USER="${BASH_REMATCH[1]}"
            GITHUB_REPO="${BASH_REMATCH[2]}"
            echo "   GitHub: $GITHUB_USER/$GITHUB_REPO"
        fi
    fi
else
    check_fail "No Git repository found at /opt/cicd-project"
fi
echo ""

# 7. Check Jenkins job
echo "7. Checking Jenkins jobs..."
JENKINS_HOME="/var/lib/jenkins"
if [ -d "$JENKINS_HOME/jobs" ]; then
    echo "   Jobs found:"
    for job in "$JENKINS_HOME/jobs"/*; do
        if [ -d "$job" ]; then
            JOB_NAME=$(basename "$job")
            echo "   - $JOB_NAME"
            
            # Check if GitHub hook trigger is enabled
            CONFIG_FILE="$job/config.xml"
            if [ -f "$CONFIG_FILE" ]; then
                if grep -q "GitHubPushTrigger" "$CONFIG_FILE"; then
                    check_pass "   GitHub hook trigger enabled"
                else
                    check_warn "   GitHub hook trigger NOT enabled"
                    echo "      Fix: Job → Configure → Build Triggers → GitHub hook trigger"
                fi
            fi
        fi
    done
else
    check_warn "Could not access Jenkins jobs directory"
fi
echo ""

# Summary
echo "======================================"
echo "SUMMARY & NEXT STEPS"
echo "======================================"
echo ""

if [[ "$IPV4" =~ ^10\. ]] || [[ "$IPV4" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$IPV4" =~ ^192\.168\. ]]; then
    echo "⚠️  IMPORTANT: Your VM has a PRIVATE IP ($IPV4)"
    echo ""
    echo "You have 3 options:"
    echo ""
    echo "Option 1: Port Forwarding (if VM is at home/office)"
    echo "  1. Find your router's public IP: curl ifconfig.me"
    echo "  2. Configure router to forward port 8080 to $IPV4"
    echo "  3. Use router's public IP in webhook URL"
    echo ""
    echo "Option 2: Use ngrok (for testing)"
    echo "  1. Install: https://ngrok.com/download"
    echo "  2. Run: ngrok http 8080"
    echo "  3. Use the ngrok URL in GitHub webhook"
    echo ""
    echo "Option 3: Cloud VM (recommended for production)"
    echo "  1. Deploy to AWS/Azure/GCP"
    echo "  2. Assign public IP to VM"
    echo "  3. Update security group to allow port 8080"
else
    echo "✅ Your webhook URL should be:"
    echo ""
    echo "   http://$IPV4:8080/github-webhook/"
    echo ""
    echo "Next steps:"
    echo "1. Go to GitHub: https://github.com/$GITHUB_USER/$GITHUB_REPO/settings/hooks"
    echo "2. Click 'Add webhook'"
    echo "3. Payload URL: http://$IPV4:8080/github-webhook/"
    echo "4. Content type: application/json"
    echo "5. Events: Just the push event"
    echo "6. Active: ✓"
    echo "7. Click 'Add webhook'"
    echo ""
    echo "Test with:"
    echo "  cd /opt/cicd-project"
    echo "  echo '# test' >> README.md"
    echo "  git add . && git commit -m 'Test webhook' && git push"
fi
echo ""
