# restaurant-api

API web d'un restaurant (la carte des plats), construite comme un service de production : tests automatisés,
métriques Prometheus, contrôle de santé, intégration continue, puis déploiement sur Kubernetes et sur le cloud.

> Projet final d'un programme DevOps / Cloud. Les labs d'apprentissage sont dans
> [DevOps-learning-labs](https://github.com/H-HABCHANE/DevOps-learning-labs).

## Fonctionnalités

| Route | Rôle |
|---|---|
| `GET /health` | contrôle de santé (`{"status": "ok"}`), pour les probes Kubernetes et la supervision |
| `GET /plats` | la carte |
| `GET /plats/{id}` | un plat, ou `404` s'il n'existe pas |
| `GET /metrics` | métriques au format Prometheus |
| `GET /docs` | documentation interactive générée par FastAPI |

### Métriques exposées

- `http_requests_total{methode, route, code}` (counter) : trafic et taux d'erreurs.
- `http_request_duration_seconds{route}` (histogram) : latence.

Le label `route` contient le **modèle** de route (`/plats/{plat_id}`) et non l'URL réelle (`/plats/1`, `/plats/2`…),
pour éviter l'explosion du nombre de séries dans Prometheus. Un test vérifie ce comportement.

## Lancer en local

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/ruff check . && .venv/bin/python -m pytest -v      # qualité et tests
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000  # puis http://localhost:8000/docs
```

## Structure

```
app/main.py            l'API (routes + middleware de mesure)
tests/test_main.py     tests pytest (TestClient, sans serveur)
requirements.txt       dépendances d'exécution, versions épinglées
requirements-dev.txt   + outils de développement (pytest, httpx2, ruff)
pyproject.toml         réglages de ruff et pytest
```

## Feuille de route

- [x] API FastAPI, `/health`, `/metrics`, tests
- [ ] Image Docker et pipeline GitHub Actions (lint, tests, build, publication)
- [ ] Déploiement Kubernetes (Minikube) : 3 replicas, Service, probes
- [ ] Infrastructure as Code : Terraform (serveur) + Ansible (configuration)
- [ ] Supervision : Prometheus, Grafana, alertes
