# --------------------------------------------------------------------------
# AWS Documentation MCP Server — AgentCore Runtime
# Based on the upstream awslabs/mcp Dockerfile with AgentCore adaptations:
#   - Installs from PyPI (no local source copy needed)
#   - Runs as non-root user (upstream pattern)
#   - Starts with streamable-http transport on port 8000 (AgentCore MCP contract)
# --------------------------------------------------------------------------

# Stage 1: build venv with uv
# Pin digest matches upstream — dependabot keeps this updated in the source repo
FROM public.ecr.aws/amazonlinux/amazonlinux@sha256:50a58a006d3381e38160fc5bb4bbefa68b74fcd70dde798f68667aac24312f20 AS uv

RUN dnf install -y shadow-utils python3 && \
    dnf clean all

WORKDIR /app

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_PREFERENCE=only-managed \
    UV_FROZEN=true \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install uv itself via the pinned hash requirements file
COPY uv-requirements.txt ./
RUN python3 -m ensurepip && \
    python3 -m pip install --require-hashes --requirement uv-requirements.txt --no-cache-dir

# Install the MCP server package from PyPI into a venv
RUN --mount=type=cache,target=/root/.cache/uv \
    uv venv --python 3.13 /app/.venv && \
    uv pip install --python /app/.venv/bin/python \
        "awslabs.aws-documentation-mcp-server"

RUN mkdir -p /root/.local

# --------------------------------------------------------------------------
# Stage 2: lean runtime image
# --------------------------------------------------------------------------
FROM public.ecr.aws/amazonlinux/amazonlinux@sha256:50a58a006d3381e38160fc5bb4bbefa68b74fcd70dde798f68667aac24312f20

ENV PATH="/app/.venv/bin:$PATH:/usr/sbin" \
    PYTHONUNBUFFERED=1 \
    FASTMCP_LOG_LEVEL=WARNING \
    FASTMCP_HOST=0.0.0.0 \
    FASTMCP_PORT=8000 \
    FASTMCP_STATELESS_HTTP=true \
    AWS_DOCUMENTATION_PARTITION=aws

RUN dnf install -y shadow-utils procps && \
    dnf clean all && \
    groupadd --force --system app && \
    useradd app -g app -d /app && \
    chmod o+x /root

COPY --from=uv --chown=app:app /root/.local /root/.local
COPY --from=uv --chown=app:app /app/.venv   /app/.venv

COPY docker-healthcheck.sh /usr/local/bin/docker-healthcheck.sh
RUN chmod +x /usr/local/bin/docker-healthcheck.sh

# Wrapper script that starts FastMCP in streamable-http mode (required by AgentCore)
COPY --chown=app:app server.py /app/server.py

USER app

EXPOSE 8000

HEALTHCHECK --interval=60s --timeout=10s --start-period=10s --retries=3 \
    CMD ["docker-healthcheck.sh"]

# AgentCore requires MCP over streamable-http — started via wrapper script
ENTRYPOINT ["/app/.venv/bin/python", "/app/server.py"]
