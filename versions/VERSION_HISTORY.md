# Version history

The original numbered samples from Assignment 1 are kept verbatim in
`versions/legacy/`. Assignment 2 ports their domain model (clients, programs,
progress, workouts, metrics and membership) to a modular Flask application.

| Tag | Source sample | Release notes |
| --- | --- | --- |
| `v1.0.0` | `Aceestver-1.0.py` | Baseline program catalogue and Flask UI |
| `v1.1.0` | `Aceestver-1.1.py`, `Aceestver1.1.2.py` | Client profiles, calories and BMI helpers |
| `v2.0.1` | `Aceestver2.0.1.py`, `Aceestver-2.1.2.py` | SQLite schema, progress and metrics |
| `v2.2.1` | `Aceestver-2.2.1.py`, `Aceestver-2.2.4.py` | Workouts, exercises and PDF-style reports |
| `v3.0.1` | `Aceestver-3.0.1.py` | Containerised release with Pytest gate |
| `v3.1.2` | `Aceestver-3.1.2.py` | Jenkins pipeline and SonarQube analysis |
| `v3.2.4` | `Aceestver-3.2.4.py` | Progressive Kubernetes delivery and rollback |

Runtime version metadata comes from `APP_VERSION`, `DEPLOY_STRATEGY`,
`RELEASE_COLOR`, `GIT_SHA` and `BUILD_NUMBER`, injected at image build time and
overridden by Kubernetes environment variables. Query `GET /api/version` to see
which build is serving traffic.
