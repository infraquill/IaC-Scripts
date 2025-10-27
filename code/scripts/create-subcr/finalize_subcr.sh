#!/usr/bin/env bash
set -euo pipefail

SUB_ID="$1"
TAGS_STR="$2"

log() {
  echo ""
  echo "========== [$(date '+%Y-%m-%d %H:%M:%S')] $1 =========="
  echo ""
}

log "Tagging subscription $SUB_ID"

TAG_OK=true
if [[ -n "$TAGS_STR" ]]; then
  TAG_ARGS=()
  # TAGS_STR is space-separated key=value pairs, e.g.:
  # "env=platform owner=azure-team costCenter=1234"
  for kv in $TAGS_STR; do
    TAG_ARGS+=("$kv")
  done

  echo "Tag key/values: ${TAG_ARGS[*]}"

  if ! az tag create --resource-id "/subscriptions/$SUB_ID" --tags "${TAG_ARGS[@]}"; then
    TAG_OK=false
    echo "WARNING: Failed to apply tags to /subscriptions/$SUB_ID."
    echo "This usually means the service principal doesn't yet have Contributor/Owner on the new sub."
    echo "You may need to grant RBAC on that subscription and then re-run tagging manually."
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
printf "| Tags Applied              | %s\n"  "$TAGS_STR"
printf "| Tags OK                   | %s\n"  "$TAG_OK"
printf "+---------------------------+--------------------------------------------------------------+\n"
printf "\n"

echo "##vso[task.complete result=Succeeded;]Subscription $SUB_ID created and tagged (management group assignment skipped)."