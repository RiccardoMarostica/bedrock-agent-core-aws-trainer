#!/usr/bin/env python3
"""Invoke an AgentCore MCP Runtime using SigV4-signed streamable-http.

Based on the official AWS sample:
https://github.com/awslabs/amazon-bedrock-agentcore-samples/blob/main/01-tutorials/01-AgentCore-runtime/02-hosting-MCP-server/streamable_http_sigv4.py

Usage:
    # List available tools
    python test/invoke_mcp_runtime.py --runtime-arn <RUNTIME_ARN>

    # Call a specific tool
    python test/invoke_mcp_runtime.py --runtime-arn <RUNTIME_ARN> \\
        --tool search_documentation \\
        --args '{"search_phrase": "Amazon S3 bucket versioning"}'

Install:
    pip install boto3 mcp botocore httpx
"""

import argparse
import asyncio
import json
from collections.abc import Generator

import httpx
from botocore.auth import SigV4Auth as BotocoreSigV4Auth
from botocore.awsrequest import AWSRequest
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

from config import add_aws_args, boto_session


class SigV4HttpxAuth(httpx.Auth):
    """HTTPX Auth that signs every request with AWS SigV4 — from the official AWS sample."""

    def __init__(self, credentials, service: str, region: str):
        self.signer = BotocoreSigV4Auth(credentials, service, region)

    def auth_flow(self, request: httpx.Request) -> Generator[httpx.Request, httpx.Response, None]:
        headers = dict(request.headers)
        headers.pop("connection", None)  # causes signature mismatch if included
        aws_req = AWSRequest(
            method=request.method,
            url=str(request.url),
            data=request.content,
            headers=headers,
        )
        self.signer.add_auth(aws_req)
        request.headers.update(dict(aws_req.headers))
        yield request


def build_url(runtime_arn: str, region: str) -> str:
    encoded = runtime_arn.replace(":", "%3A").replace("/", "%2F")
    return f"https://bedrock-agentcore.{region}.amazonaws.com/runtimes/{encoded}/invocations"


async def run(runtime_arn: str, region: str, profile: str | None, tool: str | None, tool_args: dict) -> None:
    url = build_url(runtime_arn, region)
    print(f"URL: {url}\n")

    session = boto_session(argparse.Namespace(profile=profile, region=region))
    credentials = session.get_credentials().get_frozen_credentials()
    auth = SigV4HttpxAuth(credentials, "bedrock-agentcore", region)

    async with streamablehttp_client(url, auth=auth, terminate_on_close=False) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("Connected!\n")

            tools = await session.list_tools()
            print(f"Available tools ({len(tools.tools)}):")
            for t in tools.tools:
                print(f"  - {t.name}: {(t.description or '')[:80]}")

            if tool:
                print(f"\nCalling: {tool}")
                result = await session.call_tool(tool, tool_args)
                for item in result.content:
                    if hasattr(item, "text"):
                        print(item.text)
                    else:
                        print(item)


def main() -> None:
    parser = argparse.ArgumentParser(description="Invoke an AgentCore MCP Runtime")
    add_aws_args(parser)
    parser.add_argument("--runtime-arn", required=True)
    parser.add_argument("--tool", default=None)
    parser.add_argument("--args", default="{}", help="Tool arguments as JSON string")
    args = parser.parse_args()

    asyncio.run(run(
        runtime_arn=args.runtime_arn,
        region=args.region,
        profile=args.profile,
        tool=args.tool,
        tool_args=json.loads(args.args),
    ))


if __name__ == "__main__":
    main()
