import uuid
from datetime import UTC, datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict
from sqlalchemy import Boolean, Column, DateTime, String, Text
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


class SystemType(StrEnum):
    github = "github"
    jira = "jira"
    gitlab = "gitlab"
    linear = "linear"
    voice_interface = "voice_interface"
    other = "other"


class SourceRecord(Base):
    __tablename__ = "sources"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    system_type = Column(String(32), nullable=False)
    instance = Column(String(255), nullable=False)
    org = Column(String(255), nullable=True)
    display_name = Column(String(255), nullable=False)
    base_url = Column(String(500), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=lambda: datetime.now(UTC))
    created_by = Column(String(255), nullable=False)
    updated_by = Column(String(255), nullable=True)


# ── Pydantic schemas ───────────────────────────────────────────────────────────


class SourceCreate(BaseModel):
    system_type: SystemType
    instance: str
    org: str | None = None
    display_name: str
    base_url: str
    notes: str | None = None


class SourceUpdate(BaseModel):
    display_name: str | None = None
    base_url: str | None = None
    notes: str | None = None


class SourceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    system_type: SystemType
    instance: str
    org: str | None
    display_name: str
    base_url: str
    is_active: bool
    notes: str | None
    created_at: datetime
    created_by: str
    updated_by: str | None
