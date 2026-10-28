import os
import time
import logging
import signal
import sys
from fastapi import FastAPI, Response, status, Request
import redis
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

# 1. Structured Logging Configuration
logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s"}'
)
logger = logging.getLogger("pulseguard")

app = FastAPI(title="PulseGuard Service API", version="1.0.0")

# 2. Environment Configuration (12-Factor App Principle: never hardcode hosts)
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, socket_connect_timeout=1)

# 3. Prometheus Golden Signal Metrics
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests processed",
    ["method", "endpoint", "http_status"]
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["endpoint"],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

@app.middleware("http")
async def monitor_requests(request: Request, call_next):
    start_time = time.perf_counter()
    response = await call_next(request)
    duration = time.perf_counter() - start_time

    if request.url.path != "/metrics":
        REQUEST_LATENCY.labels(endpoint=request.url.path).observe(duration)
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            http_status=response.status_code
        ).inc()
    return response

@app.get("/healthz", status_code=status.HTTP_200_OK)
def liveness_check():
    """Liveness Probe: Verifies the local Python process is not deadlocked."""
    return {"status": "alive"}

@app.get("/readyz")
def readiness_check(response: Response):
    """Readiness Probe: Verifies downstream dependencies (Redis) are reachable."""
    try:
        redis_client.ping()
        return {"status": "ready", "redis": "connected"}
    except redis.RedisError as exc:
        logger.error(f"Readiness check failed: Redis unreachable - {exc}")
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "not_ready", "reason": "redis_unreachable"}

@app.post("/api/v1/audit")
def record_audit_event():
    """Core business endpoint: Increments audit counter in Redis."""
    try:
        count = redis_client.incr("audit_events_count")
        logger.info(f"Audit event recorded successfully. Total count: {count}")
        return {"service": "PulseGuard", "audit_count": count}
    except redis.RedisError:
        # Graceful degradation if cache is temporarily unavailable
        logger.warning("Redis unavailable during audit write; returning degraded response")
        return {"service": "PulseGuard", "audit_count": -1, "mode": "degraded"}

@app.get("/metrics")
def metrics():
    """Exposes Prometheus metrics for scraping."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

# 4. Graceful Shutdown Handler for SIGTERM
def handle_sigterm(*args):
    logger.info("Received SIGTERM from Kubernetes. Closing connections gracefully...")
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_sigterm)
