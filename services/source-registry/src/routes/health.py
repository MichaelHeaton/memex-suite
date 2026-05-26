import time

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from shared.health import DependencyStatus, health_response

from ..database import get_session

router = APIRouter()
VERSION = "0.1.0"


@router.get("/v1/health")
def health(session: Session = Depends(get_session)):
    start = time.monotonic()
    try:
        session.execute(text("SELECT 1"))
        latency = int((time.monotonic() - start) * 1000)
        db_status = DependencyStatus(name="postgres", status="ok", latency_ms=latency)
    except Exception:
        db_status = DependencyStatus(name="postgres", status="down")

    resp = health_response("source-registry", VERSION, [db_status])
    status_code = 503 if resp.status == "down" else 200
    return resp.model_dump(), status_code
