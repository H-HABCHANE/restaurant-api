# restaurant-api

API web d'un restaurant (la carte des plats), construite comme un service de production : tests automatisés,
métriques Prometheus, contrôle de santé, intégration continue, puis déploiement sur Kubernetes et sur le cloud.

> Projet final d'un programme DevOps / Cloud. Les labs d'apprentissage sont dans
> [devops-infra-labs](https://github.com/H-HABCHANE/devops-infra-labs).

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

## Déployer sur Kubernetes (Minikube)

```bash
minikube start
kubectl apply -f k8s/                                          # namespace, Deployment, Service
kubectl -n restaurant get pods                                 # 3 pods 1/1 Running
kubectl -n restaurant port-forward svc/restaurant-api 8080:80  # dans un terminal séparé
curl localhost:8080/health
```

| Réglage | Pourquoi |
|---|---|
| 3 replicas, `maxUnavailable: 0`, `maxSurge: 1` | mise à jour progressive sans coupure : un pod neuf à la fois, un ancien retiré seulement quand le neuf est prêt |
| image taguée par le **SHA du commit** | on sait exactement quelle version tourne, et on peut revenir à une version précise |
| `readinessProbe` sur `/health` | un pod qui démarre ne reçoit aucun client tant qu'il n'est pas prêt |
| `livenessProbe` sur `/health`, plus tolérante | un pod bloqué est redémarré, sans tuer un pod simplement lent à démarrer |
| `requests` / `limits` | ressources réservées pour le placement, plafond pour protéger le nœud |
| `runAsNonRoot` + UID numérique `10001`, disque en lecture seule, aucune capacité Linux | si l'appli est compromise, l'attaquant n'a ni root, ni écriture, ni privilège |

Deux problèmes rencontrés et corrigés au premier déploiement :

- `CreateContainerConfigError` : avec `runAsNonRoot`, une image déclarant un utilisateur par son **nom** (`USER appli`)
  est refusée, car Kubernetes ne peut pas vérifier que ce n'est pas root ; l'UID est désormais donné en nombre.
- démarrage d'environ 25 s sous la limite de 250m CPU : la readiness a empêché tout trafic vers les pods pas encore
  prêts.

## Structure

```
app/main.py            l'API (routes + middleware de mesure)
tests/test_main.py     tests pytest (TestClient, sans serveur)
requirements.txt       dépendances d'exécution, versions épinglées
requirements-dev.txt   + outils de développement (pytest, httpx2, ruff)
pyproject.toml         réglages de ruff et pytest
Dockerfile             image multi-étapes, utilisateur sans privilèges, HEALTHCHECK
.github/workflows/     CI : qualité (ruff, pytest) → image → publication sur Docker Hub (tag = SHA)
k8s/                   manifestes Kubernetes : namespace, Deployment, Service
```

## Feuille de route

- [x] API FastAPI, `/health`, `/metrics`, tests
- [x] Image Docker et pipeline GitHub Actions (lint, tests, build, publication)
- [x] Déploiement Kubernetes (Minikube) : 3 replicas, Service, probes
- [ ] Infrastructure as Code : Terraform (serveur) + Ansible (configuration)
- [ ] Supervision : Prometheus, Grafana, alertes
