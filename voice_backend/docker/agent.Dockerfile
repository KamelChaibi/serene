# LiveKit Agents worker.  CPU only: it calls the local HTTP model servers.
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOME=/home/serene

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pyproject.toml README.md ./
COPY app ./app
COPY prompts ./prompts

RUN pip install --no-cache-dir ".[agent]"

RUN useradd --create-home --uid 10001 serene \
    && chown -R serene:serene /app

USER serene

# Pre-download the Silero VAD ONNX model so the first call does not depend on
# GitHub being reachable.
RUN python -c "from livekit.plugins import silero; silero.VAD.load()"

CMD ["python", "-m", "app.agent", "start"]
