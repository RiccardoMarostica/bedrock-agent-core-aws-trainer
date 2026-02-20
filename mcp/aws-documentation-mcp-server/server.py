"""AWS Documentation MCP Server — AgentCore Runtime wrapper.

Creates a fresh FastMCP instance and re-registers the tool functions from the
upstream awslabs.aws_documentation_mcp_server package. This follows the official
AgentCore sample pattern: own FastMCP + @mcp.tool() decorators.

The upstream package's FastMCP instance uses lazy handler registration that
doesn't play well with AgentCore's tool sync. By re-registering the functions
on our own instance, we get a clean, predictable server.
"""
import os
import sys
from loguru import logger

logger.remove()
logger.add(sys.stderr, level=os.getenv("FASTMCP_LOG_LEVEL", "WARNING"))

os.environ.setdefault("AWS_DOCUMENTATION_PARTITION", "aws")

# ---------------------------------------------------------------------------
# Import the raw tool functions from the upstream package
# ---------------------------------------------------------------------------
from awslabs.aws_documentation_mcp_server.server_aws import (  # noqa: E402
    read_documentation,
    search_documentation,
    recommend,
)

# ---------------------------------------------------------------------------
# Create our own FastMCP instance (following the official AgentCore sample)
# ---------------------------------------------------------------------------
from mcp.server.fastmcp import FastMCP  # noqa: E402

mcp = FastMCP(
    "AWS Documentation MCP Server",
    host=os.getenv("FASTMCP_HOST", "0.0.0.0"),
    port=int(os.getenv("FASTMCP_PORT", "8000")),
    stateless_http=True,
)

# Re-register each tool on our own instance
mcp.tool()(read_documentation)
mcp.tool()(search_documentation)
mcp.tool()(recommend)

logger.info(f"Registered tools: {list(mcp._tool_manager._tools.keys())}")

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    from mcp.server.transport_security import TransportSecuritySettings

    # AgentCore routes requests through an internal proxy with a non-localhost
    # Host header. Disable DNS rebinding protection.
    mcp.settings.transport_security = TransportSecuritySettings(
        enable_dns_rebinding_protection=False
    )

    mcp.run(transport="streamable-http")
