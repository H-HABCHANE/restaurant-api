# restaurant-api

API web d'un restaurant (la carte des plats), construite comme un service de production : tests automatisés,
métriques Prometheus, contrôle de santé, intégration continue, puis déploiement sur Kubernetes et sur le cloud.

> Projet final d'un programme DevOps / Cloud. Les labs d'apprentissage sont dans
> [devops-infra-labs](https://github.com/H-HABCHANE/devops-infra-labs).

## Architecture

```
   développeur ──PR──► GitHub ──► GitHub Actions : ruff, pytest → build de l'image → test du conteneur (santé, non-root)
                                        │ après fusion sur main
                                        ▼
                                 Docker Hub : hhabchane/restaurant-api:<SHA du commit>
                                        │
                 ┌──────────────────────┴───────────────────────┐
                 ▼                                              ▼
   Kubernetes (Minikube)                              AWS eu-west-3 (Terraform → Ansible)
   3 replicas, probes, mise à jour                    EC2 : API publique en HTTP
   progressive sans coupure, rollback                 + Prometheus et Grafana, accessibles
                                                        seulement par tunnel SSH
```

## Ce que ce projet démontre

- **Une chaîne de livraison complète** : chaque changement passe par une pull request vérifiée (lint, tests, image
  démarrée et testée comme un vrai service) ; `main` est protégée ; l'image publiée est taguée par le SHA du commit.
- **Un déploiement sans coupure et réversible** : mise à jour progressive (`maxUnavailable: 0`), image inexistante
  contenue sur un seul pod, retour arrière en une commande, Git comme source de vérité (`kubectl diff`).
- **L'infrastructure en code** : serveur, réseau et règles de pare-feu décrits avec Terraform (plan relu avant
  chaque application), configuration idempotente avec Ansible (second passage sans changement), destruction vérifiée.
- **La supervision** : métriques applicatives (trafic, erreurs, latence) exposées par l'API, alertes sur les signaux
  d'or, tableau de bord versionné en JSON.
- **La sécurité par défaut** : conteneur non-root à UID numérique, système de fichiers en lecture seule, aucune
  capacité Linux, secrets hors de Git, SSH limité à une adresse, supervision jamais exposée, identifiants AWS
  temporaires.

### Problèmes rencontrés et résolus

| Problème | Cause | Correction |
|---|---|---|
| pods en `CreateContainerConfigError` | `runAsNonRoot` avec un utilisateur déclaré par son nom | UID numérique dans l'image et le Deployment |
| pods prêts au bout de 25 s seulement | limite de 250m CPU au démarrage de Python | readiness, puis `startupProbe` |
| version inexistante déployée | faute de frappe dans le tag | un seul pod touché, `rollout undo` |
| conflit de noms de conteneurs | `container_name` fixe, déjà utilisé ailleurs | noms préfixés par le projet Compose |
| risque de surplus facturé sur le CPU | t3 en mode `unlimited` par défaut, repéré en relisant le plan de destruction | `cpu_credits = "standard"` |

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

## Déploiement sur AWS : Terraform puis Ansible

```
Internet ──HTTP 80──► EC2 t3.micro (Ubuntu 24.04, eu-west-3)
                        ├─ api         ← image publiée par la CI (tag = SHA)
                        ├─ prometheus  ← 127.0.0.1:9090 seulement
                        └─ grafana     ← 127.0.0.1:3000 seulement
PC ──SSH 22 (une seule IP /32)──► tunnel vers Grafana et Prometheus
```

`infra/terraform` crée le réseau (VPC, sous-réseau public, passerelle), le groupe de sécurité (HTTP public, SSH depuis
une seule adresse) et l'instance (disque chiffré, IMDSv2), puis écrit l'inventaire Ansible. `infra/ansible` installe
Docker et lance la pile de `deploy/`.

```bash
aws login --remote --region eu-west-3                 # identifiants temporaires, utilisateur IAM
cd infra/terraform
terraform init
terraform plan -var "mon_ip=$(curl -s https://checkip.amazonaws.com)/32" -out=projet.tfplan
terraform apply projet.tfplan

cd ../ansible
set -a && . ../../deploy/.env && set +a               # le mot de passe Grafana vient de l'environnement
ansible-playbook site.yml                             # 2e passage : changed=0
curl http://<ip_publique>/health

# supervision, sans ouvrir aucun port : sortie « tunnel_supervision » de Terraform
ssh -i ~/.ssh/cle-ansible -N -L 3001:localhost:3000 -L 9091:localhost:9090 ubuntu@<ip_publique>

cd ../terraform && terraform plan -destroy -var "mon_ip=..." -out=destroy.tfplan && terraform apply destroy.tfplan
```

Points d'attention traités dans le playbook :

- attente de la fin de `cloud-init` avant `apt` (sinon conflit de verrou sur une instance neuve) ;
- copie des fichiers de `deploy/` par liste explicite, pour ne jamais envoyer un `.env` local ;
- `.env` du serveur généré par modèle, lisible par root seulement, jamais affiché (`no_log`) ;
- conteneurs recréés quand une configuration change (un fichier monté seul n'est pas relu après remplacement) ;
- vérification finale de `/health` depuis le serveur ; second passage sans aucun changement.

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
infra/terraform/       serveur AWS (réseau, sécurité, instance) et inventaire Ansible généré
infra/ansible/         installation de Docker et lancement de la pile sur le serveur
deploy/                pile Docker Compose : API, Prometheus, alertes, Grafana (tableau de bord en JSON)
```

## Feuille de route

- [x] API FastAPI, `/health`, `/metrics`, tests
- [x] Image Docker et pipeline GitHub Actions (lint, tests, build, publication)
- [x] Déploiement Kubernetes (Minikube) : 3 replicas, Service, probes, mise à jour et retour arrière
- [x] Infrastructure as Code : Terraform (serveur) + Ansible (configuration)
- [x] Supervision : Prometheus, Grafana, alertes
- [ ] Pistes : HTTPS (reverse proxy et certificat), Alertmanager vers une messagerie, déploiement continu depuis la CI,
  state Terraform distant (S3 avec verrouillage)
