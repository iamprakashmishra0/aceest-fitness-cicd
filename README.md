# ACEest Fitness & Gym — Automated CI/CD Pipeline

This repository contains the complete Assignment-2 solution: a modular Flask
application, a Pytest suite, a Jenkins pipeline with a SonarQube quality gate,
versioned container images, and Kubernetes manifests for five progressive
delivery strategies with rollback.

## 1. Repository layout

| Path | Purpose |
| --- | --- |
| `ACEest_Fitness.py`, `app.py`, `config.py`, `aceest/` | Flask application and business logic |
| `templates/`, `static/` | Server-rendered UI |
| `tests/` | Pytest unit, integration and view tests |
| `versions/legacy/` | Original numbered Python samples from Assignment 1 |
| `Dockerfile`, `docker-compose.yml` | Multi-stage image and local app + SonarQube stack |
| `Jenkinsfile` | End-to-end declarative pipeline |
| `sonar-project.properties`, `scripts/sonar-scan.sh` | Static analysis and quality gate |
| `k8s/` | Manifests for all five deployment strategies |
| `scripts/` | Build, push, deploy, promote, smoke-test and rollback helpers |
| `docs/ASSIGNMENT_REPORT.md` | Required 2–3 page report |
| `docs/DEPLOYMENT_STRATEGIES.md` | Strategy-by-strategy runbook |
| `reports/` | Generated test/coverage evidence and SonarQube report template |

## 2. Local development

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements-dev.txt
python ACEest_Fitness.py
```

Open `http://localhost:5000`. Useful endpoints:

- `GET /` — dashboard
- `GET /api/health` — readiness probe including release metadata
- `GET /api/version` — version, strategy, colour, commit and build ID
- `GET /api/clients`, `POST /api/clients` — client management
- `POST /api/calculate/bmi`, `POST /api/calculate/calories` — calculators
- `POST /api/generate-program` — AI-style workout plan

Run all checks locally:

```bash
scripts/verify.sh
```

## 3. Version control, branches and tags

```bash
scripts/git-bootstrap.sh https://github.com/<user>/<repo>.git
```

The script creates `main`, `develop`, incremental commits and the tags
`v1.0.0`, `v1.1.0`, `v2.0.1`, `v2.2.1`, `v3.2.4`, then pushes everything when a
remote URL is supplied. Add the remote manually instead if preferred:

```bash
git remote add origin https://github.com/<user>/<repo>.git
git push -u origin main develop && git push origin --tags
```

## 4. Container images

Docker and Podman use the same Dockerfile:

```bash
scripts/build-image.sh 3.2.4 canary green
podman build --build-arg APP_VERSION=3.2.4 -t aceest-fitness:3.2.4 .
```

Run Pytest **inside** the container image:

```bash
CONTAINER_RUNTIME=docker docker build --target test -t aceest-fitness:test .
docker run --rm -v "$PWD/reports:/app/reports" aceest-fitness:test \
    python -m pytest --junitxml=reports/junit.xml \
    --cov=aceest --cov-report=xml:reports/coverage.xml --cov-fail-under=90
```

Publish the image by exporting credentials (or copying `.env.example` to the
gitignored `.env` and filling it in). Prefer a Docker Hub access token:

```bash
export DOCKERHUB_USER=<username>
export DOCKERHUB_PASSWORD=<access-token>
scripts/push-image.sh 3.2.4
```

## 5. SonarQube

Start a local server with `docker-compose up -d sonarqube sonar-db` (use
`docker compose` if your Docker plugin is installed), open
`http://localhost:9000` (default `admin`/`admin`), create a user token, then:

```bash
SONAR_HOST_URL=http://localhost:9000 SONAR_TOKEN=<token> APP_VERSION=3.2.4 \
    scripts/sonar-scan.sh
```

The quality gate is defined in SonarQube (coverage ≥ 80%, no new blocker or
critical issues) and enforced by `waitForQualityGate` in the Jenkinsfile.
See `reports/sonar-report.md` for evidence and fill in the server-side values
after your own run.

## 6. Jenkins

1. Start Jenkins: `docker compose -f jenkins/docker-compose.yml up -d --build`.
2. Install plugins listed in `jenkins/plugins.txt`, including SonarQube Scanner.
3. Add credentials:
   - `dockerhub-credentials` — username/password for Docker Hub.
   - `sonar-token` — secret text token from SonarQube.
   - Configure a SonarQube server named `SonarQube` with that token.
4. Create a *Pipeline script from SCM* job pointing at the repo and `Jenkinsfile`,
   or use the JCasC job in `jenkins/casc/jenkins.yaml`.
5. Enable the GitHub webhook `http://<jenkins>/github-webhook/`; `pollSCM('H/5 * * * *')`
   is configured as a fallback trigger.
6. Run the job with parameters `DEPLOY_STRATEGY`, `APP_VERSION`, `PUSH_IMAGE` and
   `DEPLOY_TO_K8S`.

Pipeline stages: Checkout → Prepare → Lint → Unit Tests in Container →
SonarQube Quality Gate → Build Release Image → Push to Docker Hub →
Deploy and Smoke Test. A failed deployment automatically calls
`scripts/rollback.sh`.

## 7. Kubernetes deployment

Prerequisites: `minikube start --driver=docker`, `kubectl`, plus NGINX ingress
for A/B testing and Istio for shadow deployment. Build the image inside the
Minikube Docker environment (`eval $(minikube docker-env)`) or load it with
`minikube image load aceest-fitness:3.2.4`.

```bash
scripts/deploy.sh rolling-update aceest-fitness:3.2.4
scripts/deploy.sh blue-green aceest-fitness:3.2.4 green
scripts/deploy.sh canary aceest-fitness:3.2.4 green
scripts/deploy.sh shadow aceest-fitness:3.2.4 green
scripts/deploy.sh ab-testing aceest-fitness:3.2.4 green

scripts/promote.sh canary 50
scripts/smoke-test.sh
scripts/rollback.sh canary
```

Full commands and traffic behaviour are documented in
`docs/DEPLOYMENT_STRATEGIES.md`. To expose the service locally:

```bash
kubectl -n aceest port-forward service/aceest 8080:80
curl http://localhost:8080/api/version
```

Record the resulting NodePort/Ingress URL in `docs/ASSIGNMENT_REPORT.md` before
submission; no live endpoint is invented in this repository.

## 8. Submission checklist

- [x] Flask application and numbered versions
- [x] Git branching and tagging workflow (`scripts/git-bootstrap.sh`)
- [x] Pytest suite with coverage gate
- [x] Jenkins pipeline with SCM trigger and recent-commit evidence
- [x] Dockerfile and Podman-compatible build
- [x] Docker Hub push pipeline and versioned tags
- [x] Kubernetes manifests for blue-green, canary, shadow, A/B and rolling update
- [x] Rollback automation and smoke tests
- [x] SonarQube configuration and report template
- [ ] Public GitHub repository link (add your URL)
- [ ] Live cluster endpoint and Jenkins/Sonar screenshots (add after your run)
