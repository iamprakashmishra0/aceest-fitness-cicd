#!/usr/bin/env bash
set -euo pipefail

STRATEGY="${1:-rolling-update}"
IMAGE_REF="${2:-aceest-fitness:1.0.0}"
COLOR="${3:-green}"
NAMESPACE="${NAMESPACE:-aceest}"

case "$STRATEGY" in
    rolling-update) TARGET="aceest" ;;
    blue-green) TARGET="aceest-${COLOR}" ;;
    canary|ab-testing) TARGET="aceest-canary" ;;
    shadow) TARGET="aceest-shadow" ;;
    *)
        echo "Unknown strategy: $STRATEGY" >&2
        exit 2
        ;;
esac

TAG="${IMAGE_REF##*:}"

kubectl apply -f k8s/namespace.yaml
kubectl apply -f "k8s/$STRATEGY"

for deployment in $(kubectl -n "$NAMESPACE" get deploy -l app=aceest -o name); do
    kubectl -n "$NAMESPACE" set image "$deployment" "aceest=$IMAGE_REF"
    kubectl -n "$NAMESPACE" set env "$deployment" \
        "APP_VERSION=$TAG" "DEPLOY_STRATEGY=$STRATEGY" "RELEASE_COLOR=blue"
done
kubectl -n "$NAMESPACE" set env "deployment/$TARGET" "RELEASE_COLOR=$COLOR"

for deployment in $(kubectl -n "$NAMESPACE" get deploy -l app=aceest -o name); do
    kubectl -n "$NAMESPACE" rollout status "$deployment" --timeout=180s
done

case "$STRATEGY" in
    blue-green) scripts/promote.sh blue-green "$COLOR" ;;
    canary) scripts/promote.sh canary 25 ;;
    ab-testing) scripts/promote.sh ab-testing 25 ;;
esac

echo "Deployed $IMAGE_REF with strategy $STRATEGY"
