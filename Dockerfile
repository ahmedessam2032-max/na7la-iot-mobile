# =====================================================================
# Na7la IoT v2.0 - Production Dockerfile
# Optimized for AWS EC2 (Ubuntu 24.04/26.04 AMD64)
# =====================================================================

FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# Install essential build tools & curl for healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Layer caching for python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy source code and dashboard
COPY . /app

# Create persistent storage folder for SQLite
RUN mkdir -p /app/data

# Ports:
# 8000: FastAPI HTTP REST & WebSockets
# 10086: MTTL-W01 Hardware TCP Hub
EXPOSE 8000 10086

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/api/v1/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
