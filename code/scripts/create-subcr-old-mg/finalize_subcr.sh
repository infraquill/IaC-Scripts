#!/usr/bin/env bash
set -euo pipefail

SUB_ID="$1"
MG_ID="$2"
TAGS_STR="$3"

log() {
  echo ""
  echo "========== [$(date '+%Y-%m-%d %H:%M:%S')] $1 =========="
  echo ""
}

attach_to_mg() {
  # Try to add the subscription to the management group.
  # Returns 0 on success, nonzero on failure.
  az account management-group subscription add \
    --name "$MG_ID" \
    --subscription "$SUB_ID"
}

log "Attaching subscription $SUB_ID to management group '$MG_ID'"

ATTEMPTS=10          # 10 attempts
SLEEPSEC=60          # 60s between attempts
MG_ASSIGN_OK=false
ATTACH_ERROR_MSG=""

for i in $(seq 1 $ATTEMPTS); do
  NOW=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$NOW] MG attach attempt $i/$ATTEMPTS..."

  if ATTACH_OUTPUT=$(attach_to_mg 2>&1); then
    echo "Management group attach succeeded."
    MG_ASSIGN_OK=true
    break
  else
    ATTACH_ERROR_MSG="$ATTACH_OUTPUT"
    echo "Management group attach did not succeed:"
    echo "$ATTACH_ERROR_MSG"

    # Check for the classic RBAC timing / propagation denial
    # We're specifically looking for "Permissions to write on resource of type 'Microsoft.Management/managementGroups'"
    if echo "$ATTACH_ERROR_MSG" | grep -qi "Microsoft.Management/managementGroups"; then
      echo "Likely RBAC/propagation delay or subscription hydration delay."
      echo "Sleeping ${SLEEPSEC}s before retry..."
      sleep $SLEEPSEC
      continue
    fi

    # If it's some *other* kind of failure, don't bother retrying 10 times — break early.
    echo "Error does not look like transient RBAC propagation. Breaking early."
    break
  fi
done

if [ "$MG_ASSIGN_OK" != "true" ]; then
  echo ""
  echo "FATAL: could not attach subscription $SUB_ID to management group $MG_ID after $ATTEMPTS attempts."
  echo "Last error:"
  echo "$ATTACH_ERROR_MSG"
  echo ""
  echo "This will fail the pipeline because MG assignment is mandatory policy."
  exit 1
fi

log "Applying tags to subscription scope"
TAG_OK=true
if [[ -n "$TAGS_STR" ]]; then
  TAG_ARGS=()
  for kv in $TAGS_STR; do
    TAG_ARGS+=("$kv")
  done

  echo "Tag key/values: ${TAG_ARGS[*]}"

  if ! az tag create --resource-id "/subscriptions/$SUB_ID" --tags "${TAG_ARGS[@]}"; then
    TAG_OK=false
    echo "WARNING: Failed to apply tags to /subscriptions/$SUB_ID."
    echo "This usually means the service principal doesn't have Contributor/Owner on the new sub yet."
    echo "You may need to grant RBAC on the subscription, then tag manually."
  fi
else
  echo "No tags provided, skipping tagging."
fi

log "FINAL SUMMARY"
printf "\n"
printf "+---------------------------+--------------------------------------------------------------+\n"
printf "| Field                     | Value                                                        |\n"
printf "+---------------------------+--------------------------------------------------------------+\n"
printf "| New Subscription ID       | %s\n"  "$SUB_ID"
printf "| Target Management Group   | %s\n"  "$MG_ID"
printf "| MG Assignment OK          | %s\n"  "$MG_ASSIGN_OK"
printf "| Tags Applied              | %s\n"  "$TAGS_STR"
printf "| Tags OK                   | %s\n"  "$TAG_OK"
printf "+---------------------------+--------------------------------------------------------------+\n"
printf "\n"

echo "##vso[task.complete result=Succeeded;]Subscription $SUB_ID created, attached to $MG_ID, tagged (see MG Assignment OK / Tags OK above)."