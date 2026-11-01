from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_repond_ok():
    reponse = client.get("/health")
    assert reponse.status_code == 200
    assert reponse.json() == {"status": "ok"}


def test_liste_des_plats():
    reponse = client.get("/plats")
    assert reponse.status_code == 200
    assert len(reponse.json()) == 3


def test_plat_existant():
    reponse = client.get("/plats/1")
    assert reponse.status_code == 200
    assert reponse.json()["nom"] == "Couscous"


def test_plat_inconnu_renvoie_404():
    reponse = client.get("/plats/99")
    assert reponse.status_code == 404


def test_metrics_compte_les_requetes():
    client.get("/plats/2")
    texte = client.get("/metrics").text
    assert "http_requests_total" in texte
    # le label route garde le modèle, pas l'identifiant réel
    assert 'route="/plats/{plat_id}"' in texte
    assert 'route="/plats/2"' not in texte
