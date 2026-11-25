# ACEest Fitness & Gym — Assignment 2 Runbook

This repository is the complete Assignment-2 solution: a modular Flask
application, 92 Pytest tests, a Jenkins pipeline with static analysis, versioned
container images, and Kubernetes manifests for five progressive delivery
strategies with rollback.

Every command below assumes the repository root as the working directory.

## 1. Assignment-to-artifact map

| Assignment requirement | Artifact in this repo | Verification command |
| --- | --- | --- |
| Python application with numbered versions | `ACEest_Fitness.py`, `app.py`, `config.py`, `aceest/`, `versions/legacy/` | `python ACEest_Fitness.py` then `curl localhost:5000/api/version` |
| Version control with Git/GitHub | `main`/`develop` branches and tags in GitHub | `git log --oneline --decorate --all`, `git tag`, `git remote -v` |
| Unit tests and coverage | `tests/`, `pytest.ini`, `requirements-dev.txt` | `scripts/verify.sh` → `92 passed`, `100%` coverage |
| Jenkins CI/CD | `Jenkinsfile`, `jenkins/` | Build #3 at `http://localhost:8080/job/aceest-fitness/3/` → `SUCCESS` |
| SonarQube quality gate | `sonar-project.properties`, `scripts/sonar-scan.sh`, `reports/sonar-report.md` | Project dashboard → gate `OK`, coverage `93.2%` |
| Docker/Podman image | `Dockerfile`, `docker-compose.yml`, `scripts/build-image.sh` | `docker run --rm aceest-fitness:3.2.4 python -c "print('ok')"` |
| Docker Hub publication | `scripts/push-image.sh` | Tags `3.2.4` and `latest` at the Docker Hub URL below |
| Five Kubernetes deployment strategies | `k8s/rolling-update`, `k8s/blue-green`, `k8s/canary`, `k8s/shadow`, `k8s/ab-testing` | `scripts/deploy.sh <strategy> aceest-fitness:3.2.4` |
| Rollback and smoke test | `scripts/rollback.sh`, `scripts/promote.sh`, `scripts/smoke-test.sh` | `EXPECTED_VERSION=3.2.4 scripts/smoke-test.sh` |
| Report and PDFs | `docs/ASSIGNMENT_REPORT.md/.pdf`, `docs/DEPLOYMENT_STRATEGIES.md/.pdf`, `docs/evidence/` | Open the PDFs in `docs/`; screenshots are embedded in the report PDF |

## 2. Prerequisites

- Python 3.12 and Git
- Docker with the `docker` CLI and `docker-compose` v1 (or the `docker compose` plugin)
- `kubectl` and Minikube with the Docker driver
- Optional: Podman, Istio for shadow deployment, NGINX Ingress for A/B testing
- GitHub, Docker Hub and SonarQube accounts for the hosted evidence

## 3. Run the Flask application locally

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements-dev.txt
python ACEest_Fitness.py
```

Open `http://localhost:5000`. Useful endpoints:

| Endpoint | Purpose |
| --- | --- |
| `GET /` | Dashboard UI |
| `GET /api/health` | Readiness with version metadata |
| `GET /api/version` | Version, strategy, colour, commit and build ID |
| `GET /api/clients`, `POST /api/clients` | Client management |
| `POST /api/calculate/bmi` | BMI calculator |
| `POST /api/calculate/calories` | Calorie calculator |
| `POST /api/generate-program` | Generated workout plan |

Quick check:

```bash
curl http://localhost:5000/api/version
# {"build":"local","commit":"unknown","release":"blue","strategy":"rolling-update","version":"3.2.4"}
```

## 4. Verify tests, lint and coverage

```bash
scripts/verify.sh
```

Expected: byte compilation passes, Flake8 reports 0 errors, `92 passed`,
`100%` application coverage. Generated XML reports are written to
`reports/junit.xml` and `reports/coverage.xml` when Pytest is invoked with the
matching `--junitxml` and `--cov-report=xml` options; both are gitignored.

To prove the tests also run in the same image that ships to production:

```bash
docker build --target test -t aceest-fitness:test .
cid=$(docker create aceest-fitness:test python -m pytest \
  --junitxml=reports/junit.xml --cov=aceest \
  --cov-report=term-missing --cov-report=xml:reports/coverage.xml \
  --cov-fail-under=90)
docker start -a "$cid"
docker cp "$cid:/app/reports/." reports/
docker rm "$cid"
python3 scripts/normalize-coverage.py reports/coverage.xml
```

`scripts/normalize-coverage.py` changes the absolute coverage source to a
project-relative path so SonarQube can import it from any workspace.

## 5. Verify Git history and versions

```bash
git remote -v
git log --oneline --decorate --all
git tag
```

`versions/legacy/` keeps the original numbered Tkinter samples for traceability.
`main` is the release branch; `develop` and feature branches feed pull requests.
The Jenkinsfile polls `main` every five minutes as a webhook fallback.

## 6. Verify SonarQube

Start the server and open `http://localhost:9000` (default `admin`/`admin`):

```bash
docker-compose up -d sonar-db sonarqube
```

Use `docker compose` instead if your Docker plugin is installed. Create a user
token in **My Account → Security → Tokens**, then run:

```bash
SONAR_HOST_URL=http://localhost:9000 SONAR_TOKEN=<token> APP_VERSION=3.2.4 \
  scripts/sonar-scan.sh
```

Check the gate without opening the UI:

```bash
curl -u '<token>:' \
  'http://localhost:9000/api/qualitygates/project_status?projectKey=aceest-fitness-cicd'
```

Recorded result: **PASS (OK)**, coverage `93.2%`, 0 bugs, 0 vulnerabilities,
3 code smells, 0% duplication. See `reports/sonar-report.md`.

## 7. Verify Jenkins

This host uses `docker-compose` v1; the job is pre-created by JCasC.

```bash
GITHUB_REPO_URL=https://github.com/iamprakashmishra0/aceest-fitness-cicd.git \
DOCKERHUB_USER=<username> \
DOCKERHUB_PASSWORD=<dockerhub-access-token> \
SONAR_TOKEN=<sonarqube-token> \
docker-compose -f jenkins/docker-compose.yml up -d --build
```

Open `http://localhost:8080` and log in with `admin` / `change-me` (override with
`JENKINS_ADMIN_PASSWORD`). The seeded job is `aceest-fitness`.

1. Click **Build with Parameters**.
2. Use `DEPLOY_STRATEGY=rolling-update`, `APP_VERSION=3.2.4`,
   `PUSH_IMAGE=true`, `DEPLOY_TO_K8S=false`.
3. Set `RUN_SONAR=true` when `SONAR_TOKEN` was supplied at startup; build #3
   used `RUN_SONAR=false` because the scan was already run standalone.
4. Click the build number in Build History to open the build link.

Successful evidence: `http://localhost:8080/job/aceest-fitness/3/` (build #3,
`SUCCESS`). Console output shows 92 tests, 100% coverage, image tags and Docker
Hub pushes.

## 8. Build, run and publish the container

```bash
scripts/build-image.sh 3.2.4 canary green
docker run -d --name aceest-smoke aceest-fitness:3.2.4
curl http://localhost:8080/api/version
docker rm -f aceest-smoke

DOCKERHUB_USER=<username> DOCKERHUB_PASSWORD=<access-token> \
  scripts/push-image.sh 3.2.4
```

Podman uses the same Dockerfile:

```bash
podman build --build-arg APP_VERSION=3.2.4 -t aceest-fitness:3.2.4 .
```

Published tags: `iamprakashmishra/aceest-fitness:3.2.4` and `:latest`.

## 9. Run and verify the Kubernetes cluster

```bash
minikube start --driver=docker
scripts/build-image.sh 3.2.4
minikube image load aceest-fitness:3.2.4
scripts/deploy.sh rolling-update aceest-fitness:3.2.4
kubectl -n aceest get pods -w
EXPECTED_VERSION=3.2.4 scripts/smoke-test.sh
kubectl port-forward --address 0.0.0.0 -n aceest svc/aceest 8081:80
```

Open `http://localhost:8081/api/version`. Port `8080` is used by Jenkins. On
WSL2, if Windows cannot reach `localhost`, use the WSL adapter IP reported by
`ip -4 addr show eth0 | grep inet` (for example `http://172.27.153.248:8081`).

Run the other strategies with:

```bash
scripts/deploy.sh blue-green aceest-fitness:3.2.4 green
scripts/deploy.sh canary aceest-fitness:3.2.4 green
scripts/deploy.sh shadow aceest-fitness:3.2.4 green
scripts/deploy.sh ab-testing aceest-fitness:3.2.4 green
scripts/promote.sh canary 50
scripts/rollback.sh canary
```

Shadow requires Istio (`istioctl install --set profile=demo -y`); A/B requires
`minikube addons enable ingress` and `minikube tunnel`. Full traffic behaviour
and prerequisites are in `docs/DEPLOYMENT_STRATEGIES.md`.

## 10. Submission evidence

| Item | Evidence |
| --- | --- |
| GitHub repository | https://github.com/iamprakashmishra0/aceest-fitness-cicd |
| Jenkins successful build | http://localhost:8080/job/aceest-fitness/3/ (build #3) |
| SonarQube project | http://localhost:9000/dashboard?id=aceest-fitness-cicd (gate OK) |
| Docker Hub repository | https://hub.docker.com/r/iamprakashmishra/aceest-fitness |
| Cluster endpoint | http://localhost:8081 (or the WSL adapter IP from section 9) |
| Report PDF | `docs/ASSIGNMENT_REPORT.pdf` |
| Deployment runbook PDF | `docs/DEPLOYMENT_STRATEGIES.pdf` |
| Evidence screenshots | `docs/evidence/jenkins-build.png`, `docs/evidence/sonarqube-project.png`, `docs/evidence/docker-hub-repository.png` |

The localhost links require Jenkins, SonarQube and Minikube to be running.
Never commit passwords or tokens: use environment variables or the gitignored
`.env` file, and prefer access tokens over account passwords.
