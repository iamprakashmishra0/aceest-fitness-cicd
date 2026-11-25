#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-$(git describe --tags --always 2>/dev/null || echo 1.0.0)}"
STRATEGY="${2:-rolling-update}"
COLOR="${3:-blue}"
IMAGE="${IMAGE_NAME:-aceest-fitness}"
RUNTIME="${CONTAINER_RUNTIME:-docker}"

"$RUNTIME" build \
    --build-arg APP_VERSION="$VERSION" \
    --build-arg DEPLOY_STRATEGY="$STRATEGY" \
    --build-arg RELEASE_COLOR="$COLOR" \
    --build-arg GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)" \
    -t "${IMAGE}:${VERSION}" \
    -t "${IMAGE}:latest" \
    .

echo "Built ${IMAGE}:${VERSION}"
