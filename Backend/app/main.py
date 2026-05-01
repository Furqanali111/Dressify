import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.config import settings
from app.core.correlation import CorrelationIdMiddleware, RequestIdFilter
from app.core.limiter import limiter
from app.services.retry_worker import run_retry_worker

logging.basicConfig(
    level=settings.LOG_LEVEL.upper(),
    format="%(asctime)s [%(request_id)s] %(levelname)s %(name)s: %(message)s",
)
_root = logging.getLogger()
_root.addFilter(RequestIdFilter())
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Lifespan: start/stop background tasks
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    retry_task = asyncio.create_task(run_retry_worker())
    logger.info("Upload retry worker task started")
    try:
        yield
    finally:
        retry_task.cancel()
        try:
            await retry_task
        except asyncio.CancelledError:
            logger.info("Upload retry worker stopped")


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Dressify API",
    description="Backend API for Dressify Virtual Try-On App",
    version="0.1.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(CorrelationIdMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception: %s", exc)
    return JSONResponse(status_code=500, content={"detail": "Internal Server Error"})


@app.get("/health")
async def health_check():
    return {"status": "ok", "version": app.version}


# Routes
from app.routers import auth, profile, upload, clothing, outfits, feedback, users, wear_logs, analytics, notifications  # noqa: E402

app.include_router(auth.router,          prefix="/api/v1")
app.include_router(profile.router,       prefix="/api/v1")
app.include_router(upload.router,        prefix="/api/v1")
app.include_router(clothing.router,      prefix="/api/v1")
app.include_router(outfits.router,       prefix="/api/v1")
app.include_router(feedback.router,      prefix="/api/v1")
app.include_router(users.router,         prefix="/api/v1")
app.include_router(wear_logs.router,     prefix="/api/v1")
app.include_router(analytics.router,     prefix="/api/v1")
app.include_router(notifications.router, prefix="/api/v1")
