.DEFAULT_GOAL := help

MANAGED_STACK_NAME=state
INSTANCE_IDENTIFIER=workshop
ENVIRONMENT_NAME=root

AWS_REGION=us-east-1
AWS_BOOTSTRAP_PROFILE=stackrepo_bootstrap

SOURCE_STACK_NAME=spin-stack-s3bucket
SOURCE_STACK_LOCATION=https://github.com/cloudspinners/$(SOURCE_STACK_NAME)/archive/master.zip

AWS_ACCOUNT=$(shell aws --profile $(AWS_BOOTSTRAP_PROFILE) sts get-caller-identity --output text --query Account)
BUCKET_BASENAME=$(INSTANCE_IDENTIFIER)-$(ENVIRONMENT_NAME)
STATE_BUCKET=$(BUCKET_BASENAME)-$(AWS_ACCOUNT)
STATE_KEY=$(ENVIRONMENT_NAME)/$(INSTANCE_IDENTIFIER)/$(MANAGED_STACK_NAME).tfstate

bundle:
	bundle install

bundleup:
	bundle update

test: bundle ## Run tests (if any)
	bundle exec inspec exec -t aws://$(AWS_REGION)/$(AWS_BOOTSTRAP_PROFILE) test/aws

clean: ## Remove local files other than state
	rm -rf _work _src

_work/$(SOURCE_STACK_NAME).zip:
	mkdir -p _work
	curl -sSL -o $@ "$(SOURCE_STACK_LOCATION)"
	unzip -j -d _src $@ '*/src/*'

bootstrap: bootstrap_plan bootstrap_apply ## Only run this the first time

bootstrap_init: _work/$(SOURCE_STACK_NAME).zip
	rm -f _src/remote_backend.tf
	cd _src && terraform init

bootstrap_plan: bootstrap_init
	cd _src && terraform plan \
		-state ../_state/terraform.tfstate \
		-var-file=../stack.tfvars \
		-var aws_profile=$(AWS_BOOTSTRAP_PROFILE) \
		-var bucket_base_name=$(BUCKET_BASENAME) \
		-var managed_stack_name=$(MANAGED_STACK_NAME) \
		-var instance_identifier=$(INSTANCE_IDENTIFIER) \
		-var environment_name=$(ENVIRONMENT_NAME) \
		-var region=$(AWS_REGION)

bootstrap_apply: bootstrap_init
	cd _src && terraform apply \
		-auto-approve \
		-state ../_state/terraform.tfstate \
		-var-file=../stack.tfvars \
		-var aws_profile=$(AWS_BOOTSTRAP_PROFILE) \
		-var bucket_base_name=$(BUCKET_BASENAME) \
		-var managed_stack_name=$(MANAGED_STACK_NAME) \
		-var instance_identifier=$(INSTANCE_IDENTIFIER) \
		-var environment_name=$(ENVIRONMENT_NAME) \
		-var region=$(AWS_REGION)

_src/remote_backend.tf:
	mkdir -p _src
	@echo 'terraform {' > $@
	@echo '  backend "s3" {}' >> $@
	@echo '}' >> $@

init: _work/$(SOURCE_STACK_NAME).zip _src/remote_backend.tf
	cd _src && terraform init \
		-backend=true \
		-force-copy \
		-backend-config "region=$(AWS_REGION)" \
		-backend-config 'encrypt=true' \
		-backend-config "bucket=$(STATE_BUCKET)" \
		-backend-config "profile=$(AWS_BOOTSTRAP_PROFILE)" \
		-backend-config "key=$(STATE_KEY)"

plan: init ## Terraform plan
	cd _src && terraform plan \
		-var-file=../stack.tfvars \
		-var aws_profile=$(AWS_BOOTSTRAP_PROFILE) \
		-var bucket_base_name=$(BUCKET_BASENAME) \
		-var managed_stack_name=$(MANAGED_STACK_NAME) \
		-var instance_identifier=$(INSTANCE_IDENTIFIER) \
		-var environment_name=$(ENVIRONMENT_NAME) \
		-var region=$(AWS_REGION)

apply: init ## Terraform apply
	cd _src && terraform apply \
		-auto-approve \
		-var-file=../stack.tfvars \
		-var aws_profile=$(AWS_BOOTSTRAP_PROFILE) \
		-var bucket_base_name=$(BUCKET_BASENAME) \
		-var managed_stack_name=$(MANAGED_STACK_NAME) \
		-var instance_identifier=$(INSTANCE_IDENTIFIER) \
		-var environment_name=$(ENVIRONMENT_NAME) \
		-var region=$(AWS_REGION)

help:
	@grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
