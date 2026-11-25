# SonarQube report

## Configuration

- Project key: `aceest-fitness-cicd`
- Project URL: http://localhost:9000/dashboard?id=aceest-fitness-cicd
- Sources: `aceest/`, `app.py`, `ACEest_Fitness.py`, `config.py`
- Tests: `tests/`
- Python version: 3.12
- Coverage import: `reports/coverage.xml` (paths normalised by `scripts/normalize-coverage.py`)
- Gate: no new blocker/critical issues and coverage ≥ 80% on new code

Configuration lives in `sonar-project.properties`. Run the analysis with:

```bash
SONAR_HOST_URL=http://localhost:9000 SONAR_TOKEN=<token> APP_VERSION=3.2.4 \
    scripts/sonar-scan.sh
```

In Jenkins the same analysis uses the `SonarQube` server configuration, the
`sonar-token` credential and `waitForQualityGate abortPipeline: true`.

## Server results (SonarQube 10.7 Community, scan of v3.2.4)

| Metric | Value |
| --- | --- |
| Quality gate status | **PASS (OK)** |
| Coverage | 93.2% |
| Duplicated lines | 0.0% |
| Code smells | 3 |
| Bugs | 0 |
| Vulnerabilities | 0 |
| Lines of code | 768 |
| Project URL | http://localhost:9000/dashboard?id=aceest-fitness-cicd |

## Local evidence (generated before the server scan)

| Check | Result |
| --- | --- |
| Pytest | 92 passed |
| Application statement coverage | 100% |
| Flake8 | 0 errors |
| Byte compilation | passed |
| JUnit report | `reports/junit.xml` |
| Coverage report | `reports/coverage.xml` |

If the server is restarted, rerun `scripts/sonar-scan.sh` with a fresh token;
the project key and historic analyses are persisted in the `sonar-data` volume.
