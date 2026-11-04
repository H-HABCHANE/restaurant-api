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
  est refusée, car Kubernetes ne peut pas vérifier que ce n'est pas root ; l'UID est désormais donné en nombre, dans
  le Deployment et dans l'image (`USER 10001:10001`).
- démarrage d'environ 25 s sous la limite de 250m CPU : la readiness a empêché tout trafic vers les pods pas encore
  prêts, puis une `startupProbe` a été ajoutée.

### Mises à jour et retour arrière

```bash
# nouvelle version : changer le tag (SHA publié par la CI) dans k8s/deployment.yaml, puis
kubectl apply -f k8s/ && kubectl -n restaurant rollout status deployment/restaurant-api --timeout=120s
kubectl -n restaurant rollout history deployment/restaurant-api
kubectl -n restaurant rollout undo deployment/restaurant-api        # retour à la révision précédente
kubectl diff -f k8s/                                                 # le cluster correspond-il au dépôt ?
```

Scénarios testés :

- **pod supprimé** : recréé aussitôt par le Deployment ; le Service ne route que vers les pods prêts, aucune erreur.
- **démarrage lent** : une `startupProbe` (jusqu'à 60 s) protège le pod de la liveness pendant le démarrage.
- **image inexistante** déployée par erreur : un seul pod en `ImagePullBackOff`, les trois anciens continuent de servir
  (`maxUnavailable: 0`) ; `rollout undo` rétablit la version précédente en quelques secondes, puis la correction passe
  par Git, qui reste la source de vérité.

## Pile de production : API et supervision

`deploy/` décrit, avec Docker Compose, le service tel qu'il tourne sur un serveur : l'API et sa supervision.
Le même fichier sert en local et sur le serveur ; seules les variables du fichier `.env` changent.

```bash
cd deploy
cp .env.exemple .env && chmod 600 .env    # puis définir GRAFANA_MOT_DE_PASSE (obligatoire)
docker compose up -d
```

| Service | Accès | Rôle |
|---|---|---|
| `api` | `127.0.0.1:8000` (port 80 sur le serveur) | l'image publiée par la CI, taguée par SHA ; lecture seule, aucune capacité Linux |
| `prometheus` | `127.0.0.1:9090` uniquement | relève `/metrics` toutes les 15 s, évalue les alertes |
| `grafana` | `127.0.0.1:3000` uniquement | tableau de bord « signaux d'or », chargé depuis un fichier JSON versionné |

Alertes (`deploy/alertes.yml`) : API indisponible depuis 1 min, plus de 5 % de réponses 5xx, latence p95 au-delà de
500 ms. Les 404 (erreurs du client) restent visibles dans le trafic mais ne déclenchent pas d'alerte.
Prometheus et Grafana ne sont jamais exposés publiquement : sur le serveur, on y accède par un tunnel SSH.

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
deploy/                pile Docker Compose : API, Prometheus, alertes, Grafana (tableau de bord en JSON)
```

## Feuille de route

- [x] API FastAPI, `/health`, `/metrics`, tests
- [x] Image Docker et pipeline GitHub Actions (lint, tests, build, publication)
- [x] Déploiement Kubernetes (Minikube) : 3 replicas, Service, probes
- [ ] Infrastructure as Code : Terraform (serveur) + Ansible (configuration)
- [x] Supervision : Prometheus, Grafana, alertes
