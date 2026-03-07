REGION  ?= ap-northeast-2
PROJECT ?= scuad

.PHONY: help \
	pull-all pull-v1 pull-shared pull-dev pull-staging pull-prod \
	push-all push-v1 push-shared push-dev push-staging push-prod

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  pull-all     SSM에서 모든 env tfvars 내려받기"
	@echo "  pull-<env>   SSM에서 tfvars 내려받기"
	@echo "  push-all     SSM에 모든 env tfvars 올리기"
	@echo "  push-<env>   SSM에 tfvars 올리기"
	@echo ""
	@echo "Environments: v1, shared, dev, staging, prod"

# ---- Helper ----
define pull_tfvars
	aws ssm get-parameter \
	  --name "/tfvars/$(1)" \
	  --with-decryption \
	  --query "Parameter.Value" \
	  --output text \
	  --region $(REGION) > $(2)/terraform.tfvars
endef

# ---- Push ----
define push_tfvars
	aws ssm put-parameter \
	  --name "/tfvars/$(1)" \
	  --type "SecureString" \
	  --value "$$(cat $(2)/terraform.tfvars)" \
	  --overwrite \
	  --region $(REGION)
endef

push-all: push-v1 push-shared push-dev push-staging push-prod

push-v1:
	$(call push_tfvars,v1,.)

push-shared:
	$(call push_tfvars,shared,envs/shared)

push-dev:
	$(call push_tfvars,dev,envs/dev)

push-staging:
	$(call push_tfvars,staging,envs/staging)

push-prod:
	$(call push_tfvars,prod,envs/prod)

# ---- Pull ----
pull-all: pull-v1 pull-shared pull-dev pull-staging pull-prod

pull-v1:
	$(call pull_tfvars,v1,.)

pull-shared:
	$(call pull_tfvars,shared,envs/shared)

pull-dev:
	$(call pull_tfvars,dev,envs/dev)

pull-staging:
	$(call pull_tfvars,staging,envs/staging)

pull-prod:
	$(call pull_tfvars,prod,envs/prod)
