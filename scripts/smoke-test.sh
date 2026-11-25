#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-aceest}"

PODS=$(kubectl -n "$NAMESPACE" get pods -l app=aceest -o json | python3 -c '
import json, sys
items = json.load(sys.stdin)["items"]
ready = [p for p in items if any(c.get("type") == "Ready" and c.get("status") == "True"
                                for c in p.get("status", {}).get("conditions", []))]
print("\n".join(p["metadata"]["name"] for p in ready))
')

if [ -z "$PODS" ]; then
    echo "No ready ACEest pod found" >&2
    exit 1
fi

RESULT=""
for POD in $PODS; do
    if RESULT=$(kubectl -n "$NAMESPACE" exec "$POD" -- python -c \
        'import json,urllib.request; print(json.dumps(json.load(urllib.request.urlopen("http://127.0.0.1:5000/api/health"))))' 2>/dev/null); then
        break
    fi
done

if [ -z "$RESULT" ]; then
    echo "Health probe failed on all ready pods" >&2
    exit 1
fi

echo "$RESULT"

if [ -n "${EXPECTED_VERSION:-}" ]; then
    printf '%s' "$RESULT" | EXPECTED_VERSION="$EXPECTED_VERSION" python3 -c \
        'import json,os,sys; data=json.load(sys.stdin); actual=data["version"]["version"]; expected=os.environ["EXPECTED_VERSION"]; sys.exit(0 if actual == expected else 1)'
fi
