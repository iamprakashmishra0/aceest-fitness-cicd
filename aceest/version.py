"""Build and release metadata exposed by the running application.

The values are injected by the CI/CD pipeline (Docker build args and Kubernetes
environment variables) so that the deployed pod can report exactly which
application version and deployment strategy are serving traffic.
"""

from __future__ import annotations

import os


def version_info() -> dict:
    """Return the current release metadata for health checks and UI badges."""

    return {
        "version": os.environ.get("APP_VERSION", "1.0.0"),
        "strategy": os.environ.get("DEPLOY_STRATEGY", "rolling-update"),
        "release": os.environ.get("RELEASE_COLOR", "blue"),
        "commit": os.environ.get("GIT_SHA", "unknown"),
        "build": os.environ.get("BUILD_NUMBER", "local"),
    }
