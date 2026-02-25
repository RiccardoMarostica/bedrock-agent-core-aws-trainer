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
NS_SEMANTIC = os.getenv("MEMORY_NAMESPACE", "aws_knowledge")
NS_SUMMARIZATION = os.getenv("MEMORY_NS_SUMMARIZATION", "study_sessions_{sessionId}")
NS_USER_PREFERENCE = os.getenv("MEMORY_NS_USER_PREFERENCE", "learner_profile")
TOP_K = int(os.getenv("MEMORY_TOP_K", "5"))


def _client():
    return boto3.client("bedrock-agentcore", region_name=AWS_REGION)


def _retrieve_namespace(query: str, namespace: str) -> list[str]:
    """Retrieve memory record texts from a single namespace.

    Returns an empty list when no records are found or on any error.
    """
    try:
        resp = _client().retrieve_memory_records(
            memoryId=MEMORY_ID,
            namespace=namespace,
            searchCriteria={
                "searchQuery": query,
                "topK": TOP_K,
            },
        )
        summaries = resp.get("memoryRecordSummaries", [])
        return [s["content"]["text"] for s in summaries if s.get("content", {}).get("text")]
    except Exception:
        logger.exception("Memory retrieval failed for namespace=%s", namespace)
        return []


def retrieve(query: str, session_id: str = "") -> str:
    """Return a formatted memory context block from all strategy namespaces.

    Queries semantic (aws_knowledge), summarization (study_sessions_{sessionId}),
    and user preference (learner_profile) namespaces. Returns an empty string
    when memory is disabled or no records are found.
    """
    if not MEMORY_ID:
        return ""

    sections: list[str] = []

    # Semantic — AWS facts, patterns, exam gotchas
    semantic = _retrieve_namespace(query, NS_SEMANTIC)
    if semantic:
        joined = "\n- ".join(semantic)
        sections.append(f"<semantic_memory>\n- {joined}\n</semantic_memory>")

    # Summarization — session digests (namespace contains the session ID)
    if session_id:
        ns_summary = NS_SUMMARIZATION.replace("{sessionId}", session_id)
        summaries = _retrieve_namespace(query, ns_summary)
        if summaries:
            joined = "\n- ".join(summaries)
            sections.append(f"<session_memory>\n- {joined}\n</session_memory>")

    # User preference — learner profile, knowledge gaps, learning style
    preferences = _retrieve_namespace(query, NS_USER_PREFERENCE)
    if preferences:
        joined = "\n- ".join(preferences)
        sections.append(f"<user_preference_memory>\n- {joined}\n</user_preference_memory>")

    if not sections:
        return ""

    return "<memory>\n" + "\n".join(sections) + "\n</memory>\n\n"


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
            eventTimestamp=datetime.now(timezone.utc),
            payload=[
                {"conversational": {"role": "USER", "content": {"text": user_message}}},
                {"conversational": {"role": "ASSISTANT", "content": {"text": agent_response}}},
            ],
        )
    except Exception:
        logger.exception("Memory ingestion failed — response already sent, continuing")
