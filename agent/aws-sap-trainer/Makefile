# ──────────────────────────────────────────────────────────────────────────────
# Agent — build, test, push
# ──────────────────────────────────────────────────────────────────────────────
# Usage:
#   make build                        Build the ARM64 container image
#   make run                          Run locally (needs AWS creds in env)
#   make push                         Build & push to ECR
#   make push TAG=v1.0.0              Push with a specific tag
#   make test-local                   Curl the local /ping and /invocations
# ──────────────────────────────────────────────────────────────────────────────

# --- Configuration (override via env or CLI) --------------------------------
AWS_REGION   ?= eu-west-1
AWS_PROFILE  ?= default
ECR_REPO     ?= <YOUR_ECR_REPO>
TAG          ?= latest
IMAGE_NAME   ?= $(ECR_REPO)

# Derived
ACCOUNT_ID   := $(shell aws sts get-caller-identity --profile $(AWS_PROFILE) --query Account --output text)
ECR_URI      := $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO)

# ──────────────────────────────────────────────────────────────────────────────

.PHONY: build run push login test-local

## Build the ARM64 container image
build:
	docker buildx build --platform linux/arm64 -t $(IMAGE_NAME):$(TAG) --load .

## Run the container locally (pass AWS creds via env)
run:
	docker run --platform linux/arm64 -p 8080:8080 \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e AWS_REGION=$(AWS_REGION) \
		-e LOG_LEVEL=DEBUG \
		$(IMAGE_NAME):$(TAG)

## Authenticate Docker to ECR
login:
	aws ecr get-login-password --region $(AWS_REGION) --profile $(AWS_PROFILE) \
		| docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

## Build and push to ECR
push: login
	docker buildx build --platform linux/arm64 \
		-t $(ECR_URI):$(TAG) \
		--push .

## Quick smoke test against local container
test-local:
	@echo "--- /ping ---"
	curl -s http://localhost:8080/ping | python3 -m json.tool
	@echo "\n--- /invocations ---"
	curl -s -X POST http://localhost:8080/invocations \
		-H "Content-Type: application/json" \
		-d '{"prompt": "Say hello in one sentence."}' | python3 -m json.tool
