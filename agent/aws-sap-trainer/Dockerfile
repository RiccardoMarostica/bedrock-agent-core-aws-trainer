# --------------------------------------------------------------------------
# AgentCore Runtime requires linux/arm64 containers on port 8080
# --------------------------------------------------------------------------
ARG TARGETPLATFORM=linux/arm64
FROM --platform=${TARGETPLATFORM} python:3.11-slim-bookworm

WORKDIR /app

# Install uv (provides uvx for MCP server execution)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Install dependencies first (layer caching)
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py memory.py google_drive.py ./

EXPOSE 8080

CMD ["python", "main.py"]
