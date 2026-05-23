from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel


class DependencyStatus(BaseModel):
    name: str
    status: Literal["ok", "degraded", "down"]
    latency_ms: int | None = None


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded", "down"]
    service: str
    version: str
    timestamp: str
    dependencies: list[DependencyStatus] = []


def health_response(
    service: str,
    version: str,
    dependencies: list[DependencyStatus] | None = None,
) -> HealthResponse:
    deps = dependencies or []
    if any(d.status == "down" for d in deps):
        status = "down"
    elif any(d.status == "degraded" for d in deps):
        status = "degraded"
    else:
        status = "ok"

    return HealthResponse(
        status=status,
        service=service,
        version=version,
        timestamp=datetime.now(timezone.utc).isoformat(),
        dependencies=deps,
    )
