"""AgentCore Memory helpers for the AWS SAP Exam Coach agent."""

from __future__ import annotations

import logging
import os
from datetime import datetime, timezone

import boto3

logger = logging.getLogger(__name__)

MEMORY_ID = os.getenv("MEMORY_ID", "")
ACTOR_ID = os.getenv("MEMORY_ACTOR_ID", "learner")
AWS_REGION = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "eu-west-1"))
NAMESPACE = os.getenv("MEMORY_NAMESPACE", "aws_knowledge")
TOP_K = int(os.getenv("MEMORY_TOP_K", "5"))


def _client():
    return boto3.client("bedrock-agentcore", region_name=AWS_REGION)


def retrieve(query: str) -> str:
    """Return a formatted memory context block for the given query.

    Returns an empty string when memory is disabled or on any error.
    """
    if not MEMORY_ID:
        return ""
    try:
        resp = _client().retrieve_memory_records(
            memoryId=MEMORY_ID,
            namespace=NAMESPACE,
            searchCriteria={
                "searchQuery": query,
                "topK": TOP_K,
            },
        )
        summaries = resp.get("memoryRecordSummaries", [])
        if not summaries:
            return ""
        lines = [s["content"]["text"] for s in summaries if s.get("content", {}).get("text")]
        if not lines:
            return ""
        joined = "\n- ".join(lines)
        return f"<memory>\n- {joined}\n</memory>\n\n"
    except Exception:
        logger.exception("Memory retrieval failed — continuing without context")
        return ""


def ingest(session_id: str, user_message: str, agent_response: str) -> None:
    """Ingest a single conversation turn into memory (fire-and-forget).

    Silently swallows errors so the response path is never affected.
    """
    if not MEMORY_ID:
        return
    try:
        # Ensure agent_response is a plain string — Strands may return a
        # dict-like Message object instead of str.
        if not isinstance(agent_response, str):
            if isinstance(agent_response, dict):
                # Handle {'role': 'assistant', 'content': [{'text': '...'}]}
                content = agent_response.get("content", [])
                if isinstance(content, list):
                    agent_response = "\n".join(
                        item.get("text", "") for item in content if isinstance(item, dict)
                    )
                else:
                    agent_response = str(agent_response)
            else:
                agent_response = str(agent_response)

        _client().create_event(
            memoryId=MEMORY_ID,
            actorId=ACTOR_ID,
            sessionId=session_id,
            eventTimestamp=datetime.now(timezone.utc).isoformat(),
            payload=[
                {"conversational": {"role": "USER", "content": {"text": user_message}}},
                {"conversational": {"role": "ASSISTANT", "content": {"text": agent_response}}},
            ],
        )
    except Exception:
        logger.exception("Memory ingestion failed — response already sent, continuing")
