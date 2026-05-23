import os
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .models import Base

_engine = None
_SessionLocal = None


def get_engine():
    global _engine
    if _engine is None:
        dsn = os.environ.get("DATABASE_URL")
        if not dsn:
            raise RuntimeError("DATABASE_URL environment variable is not set")
        _engine = create_engine(dsn, pool_pre_ping=True)
    return _engine


def init_db():
    """Create tables if they don't exist. Called at Lambda cold start."""
    Base.metadata.create_all(bind=get_engine())


def get_session() -> Generator[Session, None, None]:
    """FastAPI dependency — yields a database session per request."""
    global _SessionLocal
    if _SessionLocal is None:
        _SessionLocal = sessionmaker(bind=get_engine(), autocommit=False, autoflush=False)
    session = _SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
