from typing import Any, Literal

from pydantic import BaseModel


class MCPEnvelope(BaseModel):
    """Standard MCP gateway response wrapper."""

    result: Any
    completeness: Literal["full", "partial", "none"]
    reason: str | None = None
