#!/usr/bin/env bash
set -euo pipefail

STRATEGY="${1:?Usage: promote.sh <blue-green|canary|shadow|ab-testing> <value>}"
VALUE="${2:-}"
NAMESPACE="${NAMESPACE:-aceest}"

case "$STRATEGY" in
    blue-green)
        case "$VALUE" in
            blue|green) ;;
            *) echo "Blue-green target must be blue or green" >&2; exit 2 ;;
        esac
        kubectl -n "$NAMESPACE" patch service aceest --type merge \
            -p "{\"spec\":{\"selector\":{\"app\":\"aceest\",\"track\":\"$VALUE\"}}}"
        echo "Service aceest now points to $VALUE"
        ;;
    canary)
        PERCENT="${VALUE:-25}"
        CANARY_REPLICAS=$(( (PERCENT * 4 + 99) / 100 ))
        [ "$CANARY_REPLICAS" -gt 4 ] && CANARY_REPLICAS=4
        STABLE_REPLICAS=$(( 4 - CANARY_REPLICAS ))
        kubectl -n "$NAMESPACE" scale deployment/aceest-canary --replicas="$CANARY_REPLICAS"
        kubectl -n "$NAMESPACE" scale deployment/aceest-stable --replicas="$STABLE_REPLICAS"
        echo "Canary traffic weight set to ${PERCENT}%"
        ;;
    ab-testing)
        PERCENT="${VALUE:-25}"
        kubectl -n "$NAMESPACE" annotate ingress aceest-ab-canary \
            "nginx.ingress.kubernetes.io/canary-weight=$PERCENT" --overwrite
        echo "A/B canary weight set to ${PERCENT}%"
        ;;
    shadow)
        PERCENT="${VALUE:-100}"
        kubectl -n "$NAMESPACE" patch virtualservice aceest-mirror --type merge \
            -p "{\"spec\":{\"http\":[{\"route\":[{\"destination\":{\"host\":\"aceest.aceest.svc.cluster.local\",\"subset\":\"stable\"}}],\"mirror\":{\"host\":\"aceest.aceest.svc.cluster.local\",\"subset\":\"shadow\"},\"mirrorPercentage\":{\"value\":$PERCENT}}]}}"
        echo "Shadow mirror percentage set to ${PERCENT}%"
        ;;
    *)
        echo "Unknown strategy: $STRATEGY" >&2
        exit 2
        ;;
esac
