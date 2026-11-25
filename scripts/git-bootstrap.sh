#!/usr/bin/env bash
set -euo pipefail

REMOTE_URL="${1:-}"

if [ ! -d .git ]; then
    git init -b main
fi

git config user.name "${GIT_AUTHOR_NAME:-ACEest DevOps}"
git config user.email "${GIT_AUTHOR_EMAIL:-devops@aceest.local}"

git checkout -q main
git add ACEest_Fitness.py app.py config.py aceest templates static requirements.txt pytest.ini .flake8 .gitignore .dockerignore
git commit -q -m "feat: modular Flask fitness application" || true
git tag -a v1.0.0 -m "Baseline web application" -f

git add tests
git commit -q -m "test: add Pytest suite and coverage gates" || true
git tag -a v1.1.0 -m "Automated unit and integration tests" -f

git add Dockerfile scripts/build-image.sh scripts/push-image.sh versions
git commit -q -m "build: containerise application and versioned builds" || true
git tag -a v2.0.1 -m "Containerised release" -f

git add Jenkinsfile sonar-project.properties jenkins scripts/sonar-scan.sh reports
git commit -q -m "ci: add Jenkins pipeline with quality gate" || true
git tag -a v2.2.1 -m "CI/CD pipeline release" -f

git checkout -q -b develop
git add k8s scripts/deploy.sh scripts/promote.sh scripts/rollback.sh scripts/smoke-test.sh
git commit -q -m "deploy: add progressive Kubernetes strategies" || true
git tag -a v3.2.4 -m "Progressive delivery release" -f

git add README.md docs
git commit -q -m "docs: add setup guide and assignment report" || true

if [ -n "$REMOTE_URL" ]; then
    if ! git remote get-url origin >/dev/null 2>&1; then
        git remote add origin "$REMOTE_URL"
    fi
    git push -u origin main
    git push -u origin develop
    git push origin --tags
fi

git log --oneline --decorate --all
