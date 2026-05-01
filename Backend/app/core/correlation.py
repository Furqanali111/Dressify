"""Correlation ID middleware — attaches a unique request ID to every request.

The ID is read from the incoming `X-Request-ID` header when present;
otherwise a new UUID4 is generated.  The ID is:
  - stored in a context variable so any logger can access it
  - echoed back in the `X-Request-ID` response header
"""
import logging
import uuid
from contextvars import ContextVar

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

_request_id_ctx: ContextVar[str] = ContextVar("request_id", default="-")


def get_request_id() -> str:
    return _request_id_ctx.get()


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        token = _request_id_ctx.set(request_id)
        try:
            response = await call_next(request)
        finally:
            _request_id_ctx.reset(token)
        response.headers["X-Request-ID"] = request_id
        return response


class RequestIdFilter(logging.Filter):
    """Injects request_id into every LogRecord so formatters can include it."""

    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = get_request_id()
        return True
