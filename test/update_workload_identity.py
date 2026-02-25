#!/usr/bin/env python3
"""List workload identities and update one with an allowed OAuth2 return URL.

Usage:
    # List all workload identities:
    python test/update_workload_identity.py

    # Update a specific workload identity with the callback URL:
    python test/update_workload_identity.py \\
        --name <WORKLOAD_IDENTITY_NAME> \\
        --add-url "http://localhost:9090/oauth2/callback"
"""

import argparse
import json

from config import add_aws_args, boto_session


def main():
    parser = argparse.ArgumentParser()
    add_aws_args(parser)
    parser.add_argument("--name", help="Workload identity name to update")
    parser.add_argument("--add-url", help="OAuth2 return URL to add")
    args = parser.parse_args()

    session = boto_session(args)
    client = session.client("bedrock-agentcore-control")

    if not args.name:
        # List all workload identities
        print("Listing workload identities...\n")
        paginator = client.get_paginator("list_workload_identities")
        for page in paginator.paginate():
            for wi in page.get("workloadIdentities", []):
                print(f"  Name: {wi['name']}")
                print(f"  ARN:  {wi.get('workloadIdentityArn', 'N/A')}")
                print()
        return

    # Get current state
    current = client.get_workload_identity(name=args.name)
    existing_urls = current.get("allowedResourceOauth2ReturnUrls") or []
    print(f"Current allowed URLs for '{args.name}': {json.dumps(existing_urls, indent=2)}")

    if not args.add_url:
        return

    if args.add_url in existing_urls:
        print(f"\nURL already registered: {args.add_url}")
        return

    updated_urls = existing_urls + [args.add_url]
    client.update_workload_identity(
        name=args.name,
        allowedResourceOauth2ReturnUrls=updated_urls,
    )
    print(f"\nAdded: {args.add_url}")
    print(f"Updated URLs: {json.dumps(updated_urls, indent=2)}")


if __name__ == "__main__":
    main()
