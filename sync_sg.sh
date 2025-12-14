#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

############# PARAM #############
HOME_IP="${1:?Usage: $0 <your_home_ip> (example: $0 99.111.111.111)}"
PORT=80

log "Home IP: ${HOME_IP}/32"

############# IMDSv2 get token and region #############
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

log "Region: $REGION"

############# FIND SecurityGroup #############
SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --query "SecurityGroups[?GroupName=='Candidate_SG'].GroupId | [0]" \
  --output text)

[[ -z "$SG_ID" || "$SG_ID" == "None" ]] && { log "ERROR: Candidate_SG not found"; exit 1; }

log "Using SG: $SG_ID"

############# Cloudflare IPv4 list #############
CF_IPS=$(curl -s https://www.cloudflare.com/ips-v4 | awk 'NF')
log "Fetched $(echo "$CF_IPS" | awk 'NF' | wc -l) Cloudflare IPv4 ranges"

############# Current HTTP CIDRs #############
CURRENT_HTTP=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`${PORT}\` && ToPort==\`${PORT}\`].IpRanges[].CidrIp" \
  --output text | tr '\t' '\n' | awk 'NF')

log "Current HTTP rules: $(echo "$CURRENT_HTTP" | awk 'NF' | wc -l)"

############# Desired state #############
DESIRED_HTTP=$(printf "%s\n%s/32\n" "$CF_IPS" "$HOME_IP" | awk 'NF' | sort -u)

############# Diff #############
TO_ADD=$(comm -13 <(echo "$CURRENT_HTTP" | sort) <(echo "$DESIRED_HTTP"))
TO_REMOVE=$(comm -23 <(echo "$CURRENT_HTTP" | sort) <(echo "$DESIRED_HTTP"))

############# Write YAML that mirrors desired HTTP sources Cloudflare and home IP) #############
YAML_FILE="security-group.yaml"

cat > "$YAML_FILE" <<EOF
name: security-group
rules:
  ssh:
    - 0.0.0.0/0
  http:
EOF

echo "$DESIRED_HTTP" | while read -r cidr; do
  [[ -z "$cidr" ]] && continue
  echo "    - $cidr" >> "$YAML_FILE"
done

log "YAML updated: $YAML_FILE (http rules: $(echo "$DESIRED_HTTP" | awk 'NF' | wc -l))"

log "Rules to add: $(echo "$TO_ADD" | awk 'NF' | wc -l)"
log "Rules to remove: $(echo "$TO_REMOVE" | awk 'NF' | wc -l)"

############# APPLY #############
if [[ -n "$TO_ADD" ]]; then
  aws ec2 authorize-security-group-ingress \
    --region "$REGION" \
    --group-id "$SG_ID" \
    --ip-permissions "IpProtocol=tcp,FromPort=$PORT,ToPort=$PORT,IpRanges=[$(echo "$TO_ADD" | awk 'NF{print "{CidrIp="$1"}"}' | paste -sd,)]" \
  || true
fi

if [[ -n "$TO_REMOVE" ]]; then
  aws ec2 revoke-security-group-ingress \
    --region "$REGION" \
    --group-id "$SG_ID" \
    --ip-permissions "IpProtocol=tcp,FromPort=$PORT,ToPort=$PORT,IpRanges=[$(echo "$TO_REMOVE" | awk 'NF{print "{CidrIp="$1"}"}' | paste -sd,)]"
fi

############# Final count #############
FINAL_HTTP=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`${PORT}\` && ToPort==\`${PORT}\`].IpRanges[].CidrIp" \
  --output text | tr '\t' '\n' | awk 'NF')

log "Final HTTP rules count: $(echo "$FINAL_HTTP" | awk 'NF' | wc -l)"

log "SG sync completed successfully"
