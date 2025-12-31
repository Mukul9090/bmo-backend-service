"""
Basic tests for the Flask backend service.
"""
import os
import pytest
from server import app


@pytest.fixture
def client():
    """Create a test client."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_healthz_endpoint(client):
    """Test the /healthz endpoint."""
    response = client.get('/healthz')
    assert response.status_code == 200
    data = response.get_json()
    assert 'status' in data
    assert 'role' in data
    assert data['status'] == 'ok'


def test_root_endpoint(client):
    """Test the root endpoint."""
    response = client.get('/')
    assert response.status_code == 200
    data = response.get_json()
    assert 'message' in data
    assert 'role' in data
    assert 'backend-service running' in data['message']


def test_cluster_role_env_var(monkeypatch):
    """Test that CLUSTER_ROLE environment variable is respected."""
    monkeypatch.setenv('CLUSTER_ROLE', 'hot')
    from server import CLUSTER_ROLE
    assert CLUSTER_ROLE == 'hot'
    
    monkeypatch.setenv('CLUSTER_ROLE', 'standby')
    # Need to reload module to pick up new env var
    import importlib
    import server
    importlib.reload(server)
    assert server.CLUSTER_ROLE == 'standby'


def test_default_cluster_role(monkeypatch):
    """Test default CLUSTER_ROLE when not set."""
    monkeypatch.delenv('CLUSTER_ROLE', raising=False)
    import importlib
    import server
    importlib.reload(server)
    assert server.CLUSTER_ROLE == 'unknown'

