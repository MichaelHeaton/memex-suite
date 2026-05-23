import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from ..database import get_session
from ..models import SourceCreate, SourceRecord, SourceResponse, SourceUpdate

router = APIRouter(prefix="/sources", tags=["sources"])

# Caller identity — for now a static default; replace with JWT sub when Keycloak is wired
SYSTEM_ACTOR = "system"


@router.get("", response_model=list[SourceResponse])
def list_sources(
    system_type: Annotated[str | None, Query()] = None,
    is_active: Annotated[bool | None, Query()] = None,
    session: Session = Depends(get_session),
):
    q = session.query(SourceRecord)
    if system_type is not None:
        q = q.filter(SourceRecord.system_type == system_type)
    if is_active is not None:
        q = q.filter(SourceRecord.is_active == is_active)
    return q.all()


@router.get("/{source_id}", response_model=SourceResponse)
def get_source(source_id: str, session: Session = Depends(get_session)):
    record = session.get(SourceRecord, source_id)
    if not record:
        raise HTTPException(status_code=404, detail="Source not found")
    return record


@router.post("", response_model=SourceResponse, status_code=201)
def create_source(body: SourceCreate, session: Session = Depends(get_session)):
    record = SourceRecord(
        id=str(uuid.uuid4()),
        **body.model_dump(),
        is_active=True,
        created_by=SYSTEM_ACTOR,
    )
    session.add(record)
    session.flush()
    session.refresh(record)
    return record


@router.patch("/{source_id}", response_model=SourceResponse)
def update_source(
    source_id: str,
    body: SourceUpdate,
    session: Session = Depends(get_session),
):
    record = session.get(SourceRecord, source_id)
    if not record:
        raise HTTPException(status_code=404, detail="Source not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(record, field, value)
    record.updated_by = SYSTEM_ACTOR
    session.flush()
    session.refresh(record)
    return record


@router.patch("/{source_id}/deactivate", response_model=SourceResponse)
def deactivate_source(source_id: str, session: Session = Depends(get_session)):
    record = session.get(SourceRecord, source_id)
    if not record:
        raise HTTPException(status_code=404, detail="Source not found")
    record.is_active = False
    record.updated_by = SYSTEM_ACTOR
    session.flush()
    session.refresh(record)
    return record
