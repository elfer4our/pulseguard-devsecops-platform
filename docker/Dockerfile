# ==========================================
# Stage 1: Builder (Compiles wheels & deps)
# ==========================================
FROM python:3.12-slim AS builder

WORKDIR /build

# Prevent Python from writing .pyc files and buffering stdout
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ==========================================
# Stage 2: Hardened Production Runtime
# ==========================================
FROM python:3.12-slim

WORKDIR /srv/app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH="/srv/app"

# 1. Security: Create a non-root system user and group (UID/GID 10001)
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /usr/sbin/nologin -M appuser

# 2. Copy only installed packages from builder (leaves pip/build tools behind)
COPY --from=builder /install /usr/local

# 3. Copy application source code with strict ownership
COPY --chown=appuser:appgroup app/ /srv/app/app/

# 4. Switch to non-root user
USER 10001

EXPOSE 8000

# 5. Exec form ensures uvicorn runs as PID 1 and receives SIGTERM directly
ENTRYPOINT ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
