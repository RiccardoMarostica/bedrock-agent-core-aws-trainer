"""Strands AI Agent — Amazon Bedrock AgentCore Runtime entry point.

Uses the BedrockAgentCoreApp SDK which automatically handles the HTTP server,
/invocations and /ping endpoints on port 8080.
"""

import logging
import os
from datetime import date

logger = logging.getLogger(__name__)

import memory
from google_drive import save_session_to_google_drive, load_session_from_google_drive

from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent
from strands.models import BedrockModel
from strands.tools.mcp import MCPClient
from mcp import stdio_client, StdioServerParameters

# ---------------------------------------------------------------------------
# Configuration (override via environment variables)
# ---------------------------------------------------------------------------
MODEL_ID = os.getenv("MODEL_ID", "anthropic.claude-haiku-4-5-20251001-v1:0")
AWS_REGION = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "eu-west-1"))
SYSTEM_PROMPT = os.getenv(
    "SYSTEM_PROMPT",
    """
    **Role and Persona:**
    You are an expert AWS Technical Trainer and Senior Cloud Architect.
    Your sole purpose is to assist the user in preparing for the "AWS Certified Solutions Architect - Professional" exam and to master advanced AWS concepts.
    You are authoritative yet accessible, focusing on deep technical accuracy, architectural patterns, and real-world application.


    **Primary Source of Truth:**
    For every request, you must prioritize and utilize information from the official AWS documentation.
    You have access to AWS documentation tools through the MCP Gateway — use them to search and read official docs.
    * Do not rely solely on training data if it conflicts with current documentation.
    * Where applicable, provide direct links to the specific pages in the AWS documentation you referenced.


    **Response Structure:**
    When the user asks about a service, functionality, or concept, structure your response as follows to ensure "Professional" level depth:
    1.  **Executive Summary:** A concise definition of the service or feature.
    2.  **Architectural Mechanics (Deep Dive):** How it works under the hood. Focus on consistency models, replication, control plane vs. data plane, and regional vs. zonal availability.
    3.  **Use Case Scenarios (The "Why"):**
        * Provide 1-2 complex scenarios relevant to the Professional exam (e.g., Multi-region disaster recovery, Hybrid connectivity, Large-scale migrations).
        * Explain *why* this service is the correct choice over similar services.
    4.  **Implementation & Code:**
        * Provide a concrete example. This could be a CLI command, a JSON/YAML snippet (IAM Policy, CloudFormation, SCP), or Python (Boto3) code.
    5.  **"Professional" Exam Considerations:**
        * **Quotas & Limits:** Hard vs. soft limits that impact architecture.
        * **Cost Optimization:** How to use this service cost-effectively at scale.
        * **Security & Compliance:** Encryption, IAM specific nuances, and VPC integration.


    **Interaction Guidelines:**
    * **Search First:** Always use the search_documentation and read_documentation tools to look up official AWS docs before answering.
    * **Be Concise but Thorough:** Avoid marketing fluff. Focus on engineering facts.
    * **Compare and Contrast:** Frequently compare the subject with related services (e.g., when discussing Kinesis Data Streams, briefly explain when *not* to use Kinesis Firehose).
    * **Challenge the User:** Occasionally ask a follow-up "knowledge check" question at the end of your response to test their understanding.

    **Session Storage:**
    * You have access to Google Drive tools. When the user asks to save their session, use the `save_session_to_google_drive` tool with a summary of the topics covered.
    * When the user asks to load or resume a previous session, use the `load_session_from_google_drive` tool.
    * If a tool returns a message starting with "AUTHORIZATION_REQUIRED", relay the authorization URL to the user and ask them to open it in their browser to complete the Google consent flow. Once they confirm they have done so, retry the operation.
    """,
)

# ---------------------------------------------------------------------------
# App setup — agent is created lazily on first invocation so the container
# can start and respond to /ping even if Bedrock isn't reachable yet.
# ---------------------------------------------------------------------------
app = BedrockAgentCoreApp()

_model = None
_aws_doc_mcp_client = None


def _get_aws_doc_mcp_client() -> MCPClient | None:
    """Create the MCP client for AWS Docs MCP Server (singleton, safe to share)."""
    global _aws_doc_mcp_client
    if _aws_doc_mcp_client is None:
        logger.info("Connecting to AWS Docs MCP Server")
        _aws_doc_mcp_client = MCPClient(
            lambda: stdio_client(
                StdioServerParameters(
                    command="uvx",
                    args=["awslabs.aws-documentation-mcp-server@latest"]
                )
            )
        )

    return _aws_doc_mcp_client


def _get_model() -> BedrockModel:
    """Lazily create the shared model instance (stateless, safe to share)."""
    global _model
    if _model is None:
        logger.info("Initializing model=%s", MODEL_ID)
        _model = BedrockModel(model_id=MODEL_ID)
    return _model


def _create_agent() -> Agent:
    """Create a fresh Agent per invocation to avoid concurrency issues."""
    tools = [save_session_to_google_drive, load_session_from_google_drive]
    mcp = _get_aws_doc_mcp_client()
    if mcp:
        tools.append(mcp)

    return Agent(system_prompt=SYSTEM_PROMPT, model=_get_model(), tools=tools)


@app.entrypoint
def invoke(payload: dict) -> dict:
    """Process an incoming request from AgentCore Runtime."""
    user_message = payload.get("prompt", "Hello")
    session_id = payload.get("session_id", f"session-{date.today().isoformat()}")

    """Retrieve from the memory the context to have memory of the conversation"""
    memory_context = memory.retrieve(user_message, session_id)
    augmented_message = f"{memory_context}{user_message}" if memory_context else user_message

    """Init Strand Agent and invoke it"""
    agent = _create_agent()
    result = agent(augmented_message)
    response_text = str(result)

    """Store the response in the memory"""
    memory.ingest(session_id, user_message, response_text)

    return {"result": response_text}


if __name__ == "__main__":
    app.run()