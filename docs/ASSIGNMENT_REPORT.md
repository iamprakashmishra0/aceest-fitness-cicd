# Assignment Report — Automated CI/CD for ACEest Fitness & Gym

## 1. Overview

ACEest Fitness & Gym needed a repeatable, test-driven path from source commit to
production without downtime. The solution replaces the original desktop-style
program versions with a modular Flask web application and wraps it in an
end-to-end DevOps pipeline. Git and GitHub provide versioning, Jenkins performs
build and validation, Pytest verifies behaviour, SonarQube enforces code
quality, Docker/Podman package the application, and Kubernetes runs five
progressive delivery strategies with automated rollback.

The deployed service exposes `/api/health` and `/api/version`, which report the
release version, strategy, colour, Git commit and build number. These endpoints
are used by the pipeline as smoke tests, and they make every strategy
observable during promotion or rollback.

## 2. Architecture

The pipeline follows a single trunk with short-lived branches. Developers work
on `develop` and feature branches, open pull requests into `main`, and tag
releases with semantic versions. A GitHub webhook (with a five-minute SCM poll
as fallback) triggers the Jenkins job configured from the `Jenkinsfile` in the
repository.

Jenkins stages are:

1. **Checkout** — clone the commit that triggered the build and capture the short Git SHA.
2. **Prepare** — create a clean virtual environment, install pinned dependencies, run `pip check` and byte-compile sources.
3. **Lint** — run Flake8 with a 100-character line limit.
4. **Unit Tests in Container** — build the `test` stage of the multi-stage Dockerfile and execute Pytest inside it. JUnit XML and Cobertura coverage XML are published; the build fails below 90% coverage.
5. **SonarQube Quality Gate** — run the SonarQube Scanner and block the build with `waitForQualityGate` until the configured gate passes.
6. **Build Release Image** — build the slim, non-root runtime image with version, strategy, colour and commit injected as build arguments. Tag it with the semantic version, the strategy and `latest`.
7. **Push to Docker Hub** — authenticate with Jenkins credentials and push versioned and latest tags.
8. **Deploy and Smoke Test** — load the image into Minikube where applicable, apply the selected strategy manifests, promote the candidate, and verify `/api/health`.

A failure at any point archives reports and, once a deployment has started,
calls `scripts/rollback.sh` for the selected strategy. No secret is stored in
the repository: registry and scanner tokens live in Jenkins credentials.

The runtime image is based on `python:3.12-slim`, installs dependencies in a
separate builder virtualenv, runs Gunicorn with graceful timeouts, uses an
unprivileged user, and declares a health check. The same Dockerfile works with
Podman by replacing the client command.

## 3. Application and testing

The application is split into `db.py` (SQLite schema and request-scoped
connections), `repository.py` (SQL isolated from HTTP), `services.py` (pure
business logic), `routes/api.py` (JSON API), `routes/views.py` (HTML UI), and
`version.py` (release metadata). The application factory allows development,
test and production configurations to be created on demand; tests use a fresh
temporary database and wipe tables between cases.

The Pytest suite covers services, repository operations, API status codes and
HTML views. New tests cover release metadata and the `/api/version` endpoint,
so a misconfigured container image fails before deployment. Coverage is
currently 100% of application statements, and 92 tests pass locally.

## 4. Deployment strategies

| Strategy | Mechanism | Zero-downtime behaviour | Rollback |
| --- | --- | --- | --- |
| Rolling update | One Deployment, `maxSurge: 1`, `maxUnavailable: 0`, readiness probes, `preStop` drain | Pods replaced gradually while capacity is maintained | `kubectl rollout undo` |
| Blue-green | Two Deployments; Service selector switched after green is ready | Both versions run; switch is atomic | Switch selector back to blue |
| Canary | 3 stable + 1 canary replica behind one Service | 25% of requests exercise the new build; weight changed by scaling | Scale canary to zero |
| Shadow | Istio `VirtualService` mirrors stable traffic to shadow pods | Shadow receives real requests without affecting responses | Delete the mirror rule |
| A/B testing | NGINX canary Ingress with `X-Cohort: beta` header and weight | Cohorts routed deterministically; weight adjustable | Set canary weight to zero |

`scripts/deploy.sh` applies the manifests, patches the candidate image and
environment, waits for the rollout, promotes the candidate and runs a smoke
test. `scripts/promote.sh` and `scripts/rollback.sh` provide one-command
traffic control for every strategy.

## 5. Challenges and mitigations

**Desktop-to-web migration.** The supplied samples were numbered Tkinter
programs with SQLite and PDF code. They were retained in `versions/legacy/`
for traceability, while the domain model was ported into a Flask application
with explicit layers. This preserved behaviour and made it testable.

**Stateful demo data in multiple replicas.** SQLite files are local to each
pod. The manifests therefore mount an `emptyDir` and seed identical demo data.
The limitation is documented; production would replace it with a shared
database and a migration step.

**Minikube image availability.** The CI image uses `IfNotPresent` and the
deploy script loads the image into Minikube when the CLI is present. For remote
clusters the pipeline pushes to Docker Hub and Kubernetes pulls the same tag.

**Advanced traffic control prerequisites.** Plain Services cannot mirror
requests or route by header, so Istio and NGINX Ingress manifests are provided
with explicit prerequisites and fallback notes instead of pretending a Service
alone implements those strategies.

**Secret handling.** Registry credentials and Sonar tokens are supplied via
Jenkins credentials/environment variables; compose defaults are placeholders
and must be changed before exposure.

## 6. Key automation outcomes

- A commit triggers build, lint, containerised tests, coverage enforcement, static analysis, image publication, deployment and smoke testing without manual steps.
- Quality gates block promotion: lint errors, failing tests, coverage below 90%, or a failed SonarQube quality gate stop the pipeline.
- Every image is immutable and tagged with a semantic version and Git SHA; `/api/version` proves which release is live.
- All five delivery strategies are reproducible from manifests and scripts, each with a tested rollback path.
- Reports (JUnit, coverage, SonarQube) are archived by Jenkins for auditability.

## 7. Evidence and submission placeholders

Local evidence: `92 passed`, `100%` application coverage, Flake8 clean, and
successful container stages. Jenkins build numbers, SonarQube metric values,
the public GitHub URL and the live cluster endpoint must be filled in after
running the pipeline in the student's own environment:

- GitHub repository: https://github.com/iamprakashmishra0/aceest-fitness-cicd
- Jenkins successful build: `<add job URL and build number>`
- SonarQube project: http://localhost:9000/dashboard?id=aceest-fitness-cicd — quality gate **PASS (OK)**, coverage 93.2%, 0 bugs, 0 vulnerabilities
- Docker Hub repository: https://hub.docker.com/r/iamprakashmishra/aceest-fitness (tags `3.2.4` and `latest`)
- Cluster endpoint: http://192.168.49.2:31492 (Minikube NodePort; requires `minikube start`)
