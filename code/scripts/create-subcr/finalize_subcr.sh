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

log "Ensuring 'account' extension is installed / up to date"
az extension add -n account --upgrade

log "Adding subscription $SUB_ID to management group '$MG_ID'"
az account management-group subscription add --name "$MG_ID" --subscription "$SUB_ID"

log "Applying tags to subscription scope"
if [[ -n "$TAGS_STR" ]]; then
  TAG_ARGS=()
  for kv in $TAGS_STR; do
    TAG_ARGS+=("$kv")
  done
  echo "Tag key/values: ${TAG_ARGS[*]}"
  az tag create --resource-id "/subscriptions/$SUB_ID" --tags "${TAG_ARGS[@]}"
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
printf "| Tags Applied              | %s\n"  "$TAGS_STR"
printf "+---------------------------+--------------------------------------------------------------+\n"
printf "\n"

echo "##vso[task.complete result=Succeeded;]Subscription $SUB_ID created, assigned to $MG_ID, tagged."
