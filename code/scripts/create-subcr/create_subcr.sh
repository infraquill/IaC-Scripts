#!/usr/bin/env bash
set -euo pipefail

DISPLAY_NAME="$1"
ALIAS_NAME="$2"
BILLING_SCOPE="$3"
WORKLOAD="$4"

log() {
  echo ""
  echo "========== [$(date '+%Y-%m-%d %H:%M:%S')] $1 =========="
  echo ""
}

log "Azure CLI version (pre-check)"
az version

log "Making sure we can talk to ARM"
az account show -o table

# Build request body for the subscription alias
REQUEST_BODY=$(cat <<EOF
{
  "properties": {
    "displayName": "${DISPLAY_NAME}",
    "billingScope": "${BILLING_SCOPE}",
    "workload": "${WORKLOAD}"
  }
}
EOF
)

log "Creating new subscription alias '${ALIAS_NAME}' via az rest"
az rest \
  --method PUT \
  --url "https://management.azure.com/providers/Microsoft.Subscription/aliases/${ALIAS_NAME}?api-version=2023-11-01" \
  --body "${REQUEST_BODY}" \
  --output json

log "Fetching alias details to get Subscription ID"
SUB_JSON=$(az rest \
  --method GET \
  --url "https://management.azure.com/providers/Microsoft.Subscription/aliases/${ALIAS_NAME}?api-version=2023-11-01" \
  --output json)

echo "${SUB_JSON}" | jq -r '.'

SUB_ID=$(echo "${SUB_JSON}" | jq -r '.properties.subscriptionId')
SUB_STATE=$(echo "${SUB_JSON}" | jq -r '.properties.subscriptionState')

if [[ -z "$SUB_ID" || "$SUB_ID" == "null" ]]; then
  echo "ERROR: Could not read subscriptionId from alias response."
  exit 1
fi

echo "New Subscription ID  : $SUB_ID"
echo "Initial State        : $SUB_STATE"

log "Polling state for $SUB_ID until 'Enabled'"
ATTEMPTS=30
SLEEPSEC=20
for i in $(seq 1 $ATTEMPTS); do
  NOW=$(date '+%Y-%m-%d %H:%M:%S')
  # This uses regular 'az account show', which should work even if it's not default
  STATUS=$(az account show --subscription "$SUB_ID" --query state -o tsv || true)

  echo "[$NOW] Check $i/$ATTEMPTS -> state='$STATUS'"

  if [[ "$STATUS" == "Enabled" ]]; then
    break
  fi

  sleep $SLEEPSEC
done

if [[ "$STATUS" != "Enabled" ]]; then
  echo "ERROR: Subscription $SUB_ID did not reach 'Enabled'. Final state='$STATUS'"
  exit 1
fi

# Export vars back to the pipeline for the finalize step
echo "##vso[task.setvariable variable=newSubscriptionId;isOutput=true]$SUB_ID"
echo "##vso[task.setvariable variable=enabledSubscriptionState;isOutput=true]$STATUS"