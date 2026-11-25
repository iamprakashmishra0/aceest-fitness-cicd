#!/usr/bin/env bash
set -euo pipefail

if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

: "${DOCKERHUB_USER:?Set DOCKERHUB_USER in the environment or in .env}"
: "${DOCKERHUB_PASSWORD:?Set DOCKERHUB_PASSWORD in the environment or in .env}"

VERSION="${1:-latest}"
IMAGE="${IMAGE_NAME:-aceest-fitness}"
RUNTIME="${CONTAINER_RUNTIME:-docker}"
REMOTE="${DOCKERHUB_USER}/${IMAGE}"

printf '%s' "$DOCKERHUB_PASSWORD" | "$RUNTIME" login -u "$DOCKERHUB_USER" --password-stdin
"$RUNTIME" tag "${IMAGE}:${VERSION}" "${REMOTE}:${VERSION}"
"$RUNTIME" tag "${IMAGE}:${VERSION}" "${REMOTE}:latest"
"$RUNTIME" push "${REMOTE}:${VERSION}"
"$RUNTIME" push "${REMOTE}:latest"
"$RUNTIME" logout >/dev/null

echo "Pushed ${REMOTE}:${VERSION} and ${REMOTE}:latest"
