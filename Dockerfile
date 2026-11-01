# --- Étape 1 : la « cuisine de préparation » : installer les dépendances dans un environnement isolé ---
FROM python:3.14-slim AS construction
RUN python -m venv /opt/venv
COPY requirements.txt .
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# --- Étape 2 : la « salle » : seulement ce qu'il faut pour servir ---
FROM python:3.14-slim
# Utilisateur sans privilèges : si l'appli est compromise, l'attaquant n'est pas root dans le conteneur.
RUN useradd --create-home --uid 10001 appli
COPY --from=construction /opt/venv /opt/venv
WORKDIR /app
COPY app/ ./app/
USER appli
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
EXPOSE 8000
# Docker vérifie lui-même la santé de l'appli (pas de curl dans l'image slim : Python suffit).
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
