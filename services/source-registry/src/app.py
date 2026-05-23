from contextlib import asynccontextmanager

from fastapi import FastAPI

from .database import init_db
from .routes.health import router as health_router
from .routes.sources import router as sources_router


@asynccontextmanager
async def lifespan(application: FastAPI):
    init_db()
    yield


app = FastAPI(title="Source Registry", version="0.1.0", lifespan=lifespan)

app.include_router(health_router)
app.include_router(sources_router, prefix="/v1")
