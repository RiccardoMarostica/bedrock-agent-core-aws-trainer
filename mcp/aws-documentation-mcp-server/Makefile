AWS_REGION   ?= eu-west-1
AWS_PROFILE  ?= default
ECR_REPO     ?= <YOUR_MCP_ECR_REPO>
IMAGE_TAG    ?= latest

# Retrieve ECR registry URL
ECR_REGISTRY := $(shell aws ecr describe-repositories \
	--repository-names $(ECR_REPO) \
	--region $(AWS_REGION) \
	--profile $(AWS_PROFILE) \
	--query 'repositories[0].repositoryUri' \
	--output text 2>/dev/null)

.PHONY: build push login build-push

login:
	aws ecr get-login-password --region $(AWS_REGION) --profile $(AWS_PROFILE) \
		| docker login --username AWS --password-stdin \
		$(shell aws sts get-caller-identity --profile $(AWS_PROFILE) --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com

build:
	docker build --platform linux/arm64 -t $(ECR_REPO):$(IMAGE_TAG) .

push: login
	docker tag $(ECR_REPO):$(IMAGE_TAG) $(ECR_REGISTRY):$(IMAGE_TAG)
	docker push $(ECR_REGISTRY):$(IMAGE_TAG)

build-push: build push
