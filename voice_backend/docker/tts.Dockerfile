# Kokoro + SILMA TTS server.
#
# This image is large (~8 GB): torch, torchaudio, torchvision, NeMo text
# normalisation and the SILMA F5-TTS stack.  That is the cost of local Arabic
# speech without a paid API.
FROM python:3.12-slim AS runtime

ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu124

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOME=/home/serene \
    HF_HOME=/home/serene/.cache/huggingface

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        espeak-ng \
        ffmpeg \
        libgomp1 \
        libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pyproject.toml README.md ./
COPY app ./app
COPY prompts ./prompts

# Install the CUDA (or CPU) torch build first so the later dependency
# resolution does not replace it with a PyPI CPU wheel.
RUN pip install --no-cache-dir \
        --index-url "${TORCH_INDEX_URL}" \
        torch torchaudio torchvision

RUN pip install --no-cache-dir ".[tts,tts-ar]"

RUN useradd --create-home --uid 10001 serene \
    && mkdir -p /models \
    && chown -R serene:serene /models /app /home/serene

USER serene

EXPOSE 8002

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8002/healthz', timeout=3).status == 200 else 1)"

CMD ["uvicorn", "app.tts_server:app", "--host", "0.0.0.0", "--port", "8002"]
