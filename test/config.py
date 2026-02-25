"""Shared configuration and helpers for test/utility scripts.

Centralises AWS session creation, default region/profile, and common constants
so individual scripts stay DRY.
"""

import argparse
import boto3

# ---------------------------------------------------------------------------
# Defaults — override via CLI flags or environment variables
# ---------------------------------------------------------------------------
DEFAULT_REGION = "eu-west-1"
DEFAULT_PROFILE = "default"
OAUTH2_CALLBACK_PORT = 9090
OAUTH2_CALLBACK_PATH = "/oauth2/callback"


def add_aws_args(parser: argparse.ArgumentParser) -> None:
    """Add the standard --region and --profile arguments to a parser."""
    parser.add_argument("--region", default=DEFAULT_REGION, help=f"AWS region (default: {DEFAULT_REGION})")
    parser.add_argument("--profile", default=DEFAULT_PROFILE, help=f"AWS CLI profile (default: {DEFAULT_PROFILE})")


def boto_session(args: argparse.Namespace) -> boto3.Session:
    """Create a boto3 Session from parsed CLI args."""
    return boto3.Session(profile_name=args.profile, region_name=args.region)
