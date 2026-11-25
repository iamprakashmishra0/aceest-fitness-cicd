#!/usr/bin/env bash
set -euo pipefail

: "${SONAR_HOST_URL:?Set SONAR_HOST_URL to your SonarQube server}"
: "${SONAR_TOKEN:?Set SONAR_TOKEN to a SonarQube user token}"
PROJECT_KEY="${SONAR_PROJECT_KEY:-aceest-fitness-cicd}"
HOST="${SONAR_HOST_URL%/}"

mkdir -p reports

if command -v sonar-scanner >/dev/null 2>&1; then
    sonar-scanner \
        -Dsonar.host.url="$HOST" \
        -Dsonar.login="$SONAR_TOKEN" \
        -Dsonar.projectVersion="${APP_VERSION:-1.0.0}"
elif command -v docker >/dev/null 2>&1; then
    docker run --rm \
        -v "$PWD:/usr/src" \
        -w /usr/src \
        -e SONAR_HOST_URL="$HOST" \
        -e SONAR_TOKEN="$SONAR_TOKEN" \
        sonarsource/sonar-scanner-cli \
        -Dsonar.projectVersion="${APP_VERSION:-1.0.0}"
else
    echo "Install sonar-scanner or Docker to run the analysis." >&2
    exit 1
fi

for attempt in $(seq 1 30); do
    status=$(curl -fsS -u "$SONAR_TOKEN:" \
        "$HOST/api/qualitygates/project_status?projectKey=$PROJECT_KEY" |
        python3 -c 'import json,sys; print(json.load(sys.stdin)["projectStatus"]["status"])')
    case "$status" in
        OK)
            echo "SonarQube quality gate: PASS"
            exit 0
            ;;
        ERROR)
            echo "SonarQube quality gate: FAIL" >&2
            exit 1
            ;;
    esac
    sleep 5
done

echo "Timed out waiting for the SonarQube quality gate." >&2
exit 1
