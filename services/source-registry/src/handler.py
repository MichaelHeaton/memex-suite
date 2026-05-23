from mangum import Mangum

from .app import app

# Lambda entry point. Mangum adapts API Gateway (HTTP API) events to ASGI.
handler = Mangum(app, lifespan="off")
