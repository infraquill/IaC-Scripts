#!/usr/bin/env bash
set -euo pipefail

# Inputs (from pipeline)
DISPLAY_NAME="$1"
ALIAS_NAME="$2"
BILLING_SCOPE="$3"
WORKLOAD="$4"

log() {
  echo ""
  echo "========== [$(date '+%Y-%m-%d %H:%M:%S')] $1 =========="
  echo ""
}

log "Ensuring 'account' extension is installed / up to date"
az extension add -n account --upgrade

log "Current Azure context (who am I?)"
az account show -o table

log "Requesting new subscription using alias '${ALIAS_NAME}'"
az account subscription create \
  --display-name "${DISPLAY_NAME}" \
  --billing-scope "${BILLING_SCOPE}" \
  --workload "${WORKLOAD}" \
  --alias "${ALIAS_NAME}"

log "Alias created / requested. Retrieving details..."
SUB_JSON=$(az account subscription alias show --alias "${ALIAS_NAME}" -o json)

echo "$SUB_JSON" | jq -r '.'

SUB_ID=$(echo "$SUB_JSON" | jq -r '.properties.subscriptionId')
SUB_STATE=$(echo "$SUB_JSON" | jq -r '.properties.subscriptionState')

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

# Output values for pipeline consumption:
echo "##vso[task.setvariable variable=newSubscriptionId;isOutput=true]$SUB_ID"
echo "##vso[task.setvariable variable=enabledSubscriptionState;isOutput=true]$STATUS"
