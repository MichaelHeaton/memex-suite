"""Tests for the source-registry service. Uses SQLite in-memory via conftest fixtures."""


def test_list_sources_empty(client):
    resp = client.get("/v1/sources")
    assert resp.status_code == 200
    assert resp.json() == []


def test_create_source(client):
    payload = {
        "system_type": "github",
        "instance": "github.com",
        "org": "MichaelHeaton",
        "display_name": "Personal GitHub",
        "base_url": "https://github.com",
    }
    resp = client.post("/v1/sources", json=payload)
    assert resp.status_code == 201
    data = resp.json()
    assert data["display_name"] == "Personal GitHub"
    assert data["is_active"] is True
    assert data["created_by"] == "system"


def test_get_source(client):
    create_resp = client.post(
        "/v1/sources",
        json={
            "system_type": "jira",
            "instance": "jira.corp.adobe.com",
            "org": "CESSS",
            "display_name": "Adobe CESSS Jira",
            "base_url": "https://jira.corp.adobe.com",
        },
    )
    source_id = create_resp.json()["id"]
    resp = client.get(f"/v1/sources/{source_id}")
    assert resp.status_code == 200
    assert resp.json()["display_name"] == "Adobe CESSS Jira"


def test_get_source_not_found(client):
    resp = client.get("/v1/sources/does-not-exist")
    assert resp.status_code == 404


def test_update_source(client):
    create_resp = client.post(
        "/v1/sources",
        json={
            "system_type": "gitlab",
            "instance": "gitlab.heatons.me",
            "display_name": "Homelab GitLab",
            "base_url": "https://gitlab.heatons.me",
        },
    )
    source_id = create_resp.json()["id"]
    resp = client.patch(
        f"/v1/sources/{source_id}", json={"display_name": "Homelab GitLab (updated)"}
    )
    assert resp.status_code == 200
    assert resp.json()["display_name"] == "Homelab GitLab (updated)"
    assert resp.json()["updated_by"] == "system"


def test_deactivate_source(client):
    create_resp = client.post(
        "/v1/sources",
        json={
            "system_type": "linear",
            "instance": "linear.app",
            "display_name": "Linear",
            "base_url": "https://linear.app",
        },
    )
    source_id = create_resp.json()["id"]
    resp = client.patch(f"/v1/sources/{source_id}/deactivate")
    assert resp.status_code == 200
    assert resp.json()["is_active"] is False


def test_filter_by_system_type(client):
    client.post(
        "/v1/sources",
        json={
            "system_type": "github",
            "instance": "github.com",
            "display_name": "GH",
            "base_url": "https://github.com",
        },
    )
    resp = client.get("/v1/sources?system_type=github")
    assert resp.status_code == 200
    assert all(s["system_type"] == "github" for s in resp.json())


def test_filter_inactive(client):
    create_resp = client.post(
        "/v1/sources",
        json={
            "system_type": "other",
            "instance": "example.com",
            "display_name": "X",
            "base_url": "https://example.com",
        },
    )
    source_id = create_resp.json()["id"]
    client.patch(f"/v1/sources/{source_id}/deactivate")

    active = client.get("/v1/sources?is_active=true").json()
    inactive = client.get("/v1/sources?is_active=false").json()
    assert all(s["is_active"] for s in active)
    assert any(s["id"] == source_id for s in inactive)
