#!/usr/bin/env python3
"""Invoke an AgentCore Runtime endpoint and print the response.

Usage:
    python test/invoke.py --runtime-arn <RUNTIME_ARN> --prompt "What is Amazon Bedrock?"
    python test/invoke.py --runtime-arn <RUNTIME_ARN> --prompt "Tell me a joke" --session-id my-session

Install:
    pip install boto3
"""

import argparse
import json
import uuid

from config import add_aws_args, boto_session


def invoke(
    runtime_arn: str,
    endpoint_name: str,
    prompt: str,
    session_id: str,
    region: str,
    profile: str | None,
    user_id: str | None = None,
) -> None:
    session = boto_session(argparse.Namespace(profile=profile, region=region))
    client = session.client("bedrock-agentcore")

    payload = json.dumps({"prompt": prompt}).encode()

    kwargs = dict(
        agentRuntimeArn=runtime_arn,
        runtimeSessionId=session_id,
        payload=payload,
        qualifier=endpoint_name,
    )
    if user_id:
        kwargs["runtimeUserId"] = user_id

    response = client.invoke_agent_runtime(**kwargs)

    content_type = response.get("contentType", "")

    if "text/event-stream" in content_type:
        for line in response["response"].iter_lines(chunk_size=10):
            if line:
                line = line.decode("utf-8")
                if line.startswith("data: "):
                    print(line[6:])
    elif content_type == "application/json":
        raw = b"".join(response.get("response", []))
        print(json.dumps(json.loads(raw.decode("utf-8")), indent=2, ensure_ascii=False))
    else:
        raw = b"".join(response.get("response", []))
        print(raw.decode("utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Invoke an AgentCore Runtime endpoint")
    add_aws_args(parser)
    parser.add_argument("--runtime-arn", required=True, help="AgentCore Runtime ARN")
    parser.add_argument("--endpoint-name", required=False, default="DEFAULT", help="AgentCore Runtime endpoint name (default: DEFAULT)")
    parser.add_argument("--prompt", required=True, help="Prompt to send to the agent")
    parser.add_argument("--session-id", default=None, help="Session ID (default: random UUID)")
    parser.add_argument("--user-id", default=None, help="Runtime user ID for identity/OAuth2 flows")
    args = parser.parse_args()

    session_id = args.session_id or str(uuid.uuid4())
    print(f"Session: {session_id}\n")

    invoke(args.runtime_arn, args.endpoint_name, args.prompt, session_id, args.region, args.profile, args.user_id)


if __name__ == "__main__":
    main()
