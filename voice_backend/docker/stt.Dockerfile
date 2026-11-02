# faster-whisper STT server.
FROM python:3.12-slim AS runtime

ARG INSTALL_CUDA=1

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOME=/home/serene

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pyproject.toml README.md ./
COPY app ./app
COPY prompts ./prompts

RUN pip install --no-cache-dir ".[stt]"

# ctranslate2 needs cuBLAS and cuDNN at runtime.  The pip wheels keep the image
# portable across CUDA driver versions; set INSTALL_CUDA=0 for a CPU image.
RUN if [ "$INSTALL_CUDA" = "1" ]; then \
        pip install --no-cache-dir nvidia-cublas-cu12 nvidia-cudnn-cu12; \
    fi

ENV LD_LIBRARY_PATH=/usr/local/lib/python3.12/site-packages/nvidia/cublas/lib:/usr/local/lib/python3.12/site-packages/nvidia/cudnn/lib

RUN useradd --create-home --uid 10001 serene \
    && mkdir -p /models \
    && chown -R serene:serene /models /app

USER serene

EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8001/healthz', timeout=3).status == 200 else 1)"

CMD ["uvicorn", "app.stt_server:app", "--host", "0.0.0.0", "--port", "8001"]
