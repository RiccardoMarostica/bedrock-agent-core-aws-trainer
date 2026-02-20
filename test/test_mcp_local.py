"""Quick local test for the AWS Docs MCP Server running in Docker."""
import asyncio
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client


async def main():
    url = "http://localhost:8000/mcp"
    print(f"Connecting to {url}...")

    async with streamablehttp_client(url, terminate_on_close=False) as (
        read,
        write,
        _,
    ):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("Connected!")

            tools = await session.list_tools()
            print(f"\nAvailable tools ({len(tools.tools)}):")
            for t in tools.tools:
                print(f"  - {t.name}: {t.description[:80] if t.description else ''}")


asyncio.run(main())
