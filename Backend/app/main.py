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
from app.services.retry_worker import run_retry_worker, init_arq_pool, close_arq_pool

logging.basicConfig(
    level=settings.LOG_LEVEL.upper(),
    format="%(asctime)s [%(request_id)s] %(levelname)s %(name)s: %(message)s",
)
_root = logging.getLogger()
_filter = RequestIdFilter()
_root.addFilter(_filter)
for _handler in _root.handlers:
    _handler.addFilter(_filter)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Lifespan: start/stop background tasks
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_arq_pool()
    retry_task = asyncio.create_task(run_retry_worker())
    logger.info("Upload retry worker started")
    try:
        yield
    finally:
        retry_task.cancel()
        try:
            await retry_task
        except asyncio.CancelledError:
            pass
        await close_arq_pool()
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

_MAX_BODY_SIZE = 20 * 1024 * 1024  # 20 MB


@app.middleware("http")
async def limit_body_size(request: Request, call_next):
    content_length = request.headers.get("content-length")
    if content_length and int(content_length) > _MAX_BODY_SIZE:
        return JSONResponse(status_code=413, content={"detail": "Request body too large"})
    return await call_next(request)


app.add_middleware(CorrelationIdMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception: %s", exc, exc_info=True)
    return JSONResponse(status_code=500, content={"detail": "Internal Server Error"})


@app.get("/health")
async def health_check():
    return {"status": "ok", "version": app.version}


# Routes
from app.routers import auth, profile, upload, clothing, outfits, feedback, users, wear_logs, analytics, notifications, tryon  # noqa: E402

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
app.include_router(tryon.router,         prefix="/api/v1")
