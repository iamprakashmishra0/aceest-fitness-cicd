#!/usr/bin/env bash
set -euo pipefail

STRATEGY="${1:-rolling-update}"
NAMESPACE="${NAMESPACE:-aceest}"

case "$STRATEGY" in
    rolling-update)
        kubectl -n "$NAMESPACE" rollout undo deployment/aceest
        kubectl -n "$NAMESPACE" rollout status deployment/aceest --timeout=180s
        ;;
    blue-green)
        scripts/promote.sh blue-green blue
        ;;
    canary)
        scripts/promote.sh canary 0
        ;;
    shadow)
        kubectl -n "$NAMESPACE" delete virtualservice aceest-mirror --ignore-not-found
        ;;
    ab-testing)
        scripts/promote.sh ab-testing 0
        ;;
    *)
        echo "Unknown strategy: $STRATEGY" >&2
        exit 2
        ;;
esac

echo "Rollback completed for $STRATEGY"
