#!/bin/sh
# Check if the server.py process is running
if pgrep -f "python /app/server.py" > /dev/null; then
  echo "aws-documentation-mcp-server is running"
  exit 0
fi
exit 1
