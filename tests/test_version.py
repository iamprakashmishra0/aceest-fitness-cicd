"""Tests for release metadata that the deployment smoke tests rely on."""

from aceest import create_app
from aceest.version import version_info


def test_version_info_defaults(monkeypatch):
    for key in ("APP_VERSION", "DEPLOY_STRATEGY", "RELEASE_COLOR", "GIT_SHA", "BUILD_NUMBER"):
        monkeypatch.delenv(key, raising=False)

    assert version_info() == {
        "version": "1.0.0",
        "strategy": "rolling-update",
        "release": "blue",
        "commit": "unknown",
        "build": "local",
    }


def test_version_info_reads_environment(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "3.2.4")
    monkeypatch.setenv("DEPLOY_STRATEGY", "canary")
    monkeypatch.setenv("RELEASE_COLOR", "green")
    monkeypatch.setenv("GIT_SHA", "abc1234")
    monkeypatch.setenv("BUILD_NUMBER", "42")

    info = version_info()
    assert info["version"] == "3.2.4"
    assert info["strategy"] == "canary"
    assert info["release"] == "green"
    assert info["commit"] == "abc1234"
    assert info["build"] == "42"


def test_version_endpoint(client, monkeypatch):
    monkeypatch.setenv("APP_VERSION", "2.2.1")
    response = client.get("/api/version")
    assert response.status_code == 200
    assert response.get_json()["version"] == "2.2.1"


def test_factory_uses_injected_config():
    application = create_app("config.TestingConfig")
    assert application.config["TESTING"] is True
    assert application.test_client().get("/api/health").status_code == 200
