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

log "Caller context"
az account show -o table || echo "Note: couldn't display account (RBAC may not be fully wired yet)."

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

log "Creating new subscription alias '${ALIAS_NAME}'"
az rest \
  --method PUT \
  --url "https://management.azure.com/providers/Microsoft.Subscription/aliases/${ALIAS_NAME}?api-version=2023-11-01" \
  --body "${REQUEST_BODY}" \
  --output json

log "Polling alias provisioningState until 'Succeeded' (or 'Failed')"
ATTEMPTS=60
SLEEPSEC=60

SUB_JSON=""
PROV_STATE=""
SUB_ID=""
SUB_STATE=""

for i in $(seq 1 $ATTEMPTS); do
  NOW=$(date '+%Y-%m-%d %H:%M:%S')

  SUB_JSON=$(az rest \
    --method GET \
    --url "https://management.azure.com/providers/Microsoft.Subscription/aliases/${ALIAS_NAME}?api-version=2023-11-01" \
    --output json)

  PROV_STATE=$(echo "${SUB_JSON}" | jq -r '.properties.provisioningState')
  SUB_ID=$(echo "${SUB_JSON}" | jq -r '.properties.subscriptionId')
  SUB_STATE=$(echo "${SUB_JSON}" | jq -r '.properties.subscriptionState')

  echo "[$NOW] Check $i/$ATTEMPTS"
  echo "  provisioningState   = ${PROV_STATE}"
  echo "  subscriptionState   = ${SUB_STATE}"
  echo "  subscriptionId      = ${SUB_ID}"

  if [[ "${PROV_STATE}" == "Succeeded" ]]; then
    echo "Alias provisioning completed."
    break
  fi

  if [[ "${PROV_STATE}" == "Failed" ]]; then
    echo "ERROR: Alias provisioning failed."
    echo "${SUB_JSON}" | jq -r '.'
    exit 1
  fi

  sleep $SLEEPSEC
done

if [[ "${PROV_STATE}" != "Succeeded" ]]; then
  echo "ERROR: Alias never reached 'Succeeded' within wait window. Final provisioningState='${PROV_STATE}'"
  echo "${SUB_JSON}" | jq -r '.'
  exit 1
fi

if [[ -z "$SUB_ID" || "$SUB_ID" == "null" ]]; then
  echo "ERROR: provisioningState=Succeeded but no subscriptionId returned."
  echo "${SUB_JSON}" | jq -r '.'
  exit 1
fi

log "Alias provisioning Succeeded"
echo "Subscription ID       : ${SUB_ID}"
echo "subscriptionState     : ${SUB_STATE}"

echo "##vso[task.setvariable variable=newSubscriptionId;isOutput=true]$SUB_ID"
echo "##vso[task.setvariable variable=enabledSubscriptionState;isOutput=true]$SUB_STATE"