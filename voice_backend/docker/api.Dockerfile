# Public API container: no torch, no models, no audio.
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY pyproject.toml README.md ./
COPY app ./app
COPY prompts ./prompts

RUN pip install --no-cache-dir .

RUN useradd --create-home --uid 10001 serene \
    && mkdir -p /data \
    && chown -R serene:serene /data /app

USER serene

EXPOSE 8788

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8788/healthz', timeout=3).status == 200 else 1)"

CMD ["uvicorn", "app.api:app", "--host", "0.0.0.0", "--port", "8788", "--proxy-headers"]
