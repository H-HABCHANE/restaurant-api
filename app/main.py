"""API du restaurant : la carte des plats, un contrôle de santé et des métriques Prometheus."""
import time

from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

app = FastAPI(title="restaurant-api", version="0.1.0")

PLATS = {
    1: {"id": 1, "nom": "Couscous", "prix": 14.5},
    2: {"id": 2, "nom": "Tajine", "prix": 13.0},
    3: {"id": 3, "nom": "Pastilla", "prix": 12.0},
}

# Métriques exposées sur /metrics (les « compteurs au mur » que Prometheus vient lire)
REQUETES = Counter(
    "http_requests_total",
    "Nombre de requêtes HTTP reçues",
    ["methode", "route", "code"],
)
DUREE = Histogram(
    "http_request_duration_seconds",
    "Durée de traitement des requêtes HTTP",
    ["route"],
)


@app.middleware("http")
async def mesurer(request: Request, call_next):
    """Chronomètre chaque requête et compte son code de réponse."""
    debut = time.perf_counter()
    reponse = await call_next(request)
    # Le modèle de route (/plats/{plat_id}) et non l'URL réelle (/plats/1, /plats/2...) :
    # sinon chaque identifiant créerait une nouvelle série (explosion de cardinalité).
    route = request.scope.get("route")
    chemin = route.path if route else "inconnue"
    DUREE.labels(chemin).observe(time.perf_counter() - debut)
    REQUETES.labels(request.method, chemin, str(reponse.status_code)).inc()
    return reponse


@app.get("/health")
def sante():
    """Contrôle de santé : utilisé par Docker, Kubernetes (probes) et la sonde blackbox."""
    return {"status": "ok"}


@app.get("/plats")
def lister_plats():
    return list(PLATS.values())


@app.get("/plats/{plat_id}")
def lire_plat(plat_id: int):
    if plat_id not in PLATS:
        raise HTTPException(status_code=404, detail="Plat introuvable")
    return PLATS[plat_id]


@app.get("/metrics")
def metriques():
    """Format texte lu par Prometheus (# HELP, # TYPE, puis les valeurs)."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
