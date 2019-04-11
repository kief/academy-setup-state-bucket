.DEFAULT_GOAL := help

MANAGED_STACK_NAME=state
INSTANCE_IDENTIFIER=workshop

SOURCE_STACK_NAME=spin-stack-s3bucket
SOURCE_STACK_LOCATION=https://github.com/cloudspinners/$(SOURCE_STACK_NAME)/archive/master.zip

include my-stack.tfvars

AWS_ACCOUNT=$(shell aws --profile $(aws_profile) sts get-caller-identity --output text --query Account)
BUCKET_BASENAME=$(INSTANCE_IDENTIFIER)-$(environment_name)
STATE_BUCKET=$(BUCKET_BASENAME)-$(AWS_ACCOUNT)
STATE_KEY=$(environment_name)/$(INSTANCE_IDENTIFIER)/$(MANAGED_STACK_NAME).tfstate

debug:
	@echo "AWS_ACCOUNT=$(AWS_ACCOUNT)"
	@echo "STATE_BUCKET=$(STATE_BUCKET)"
	@echo "STATE_KEY=$(STATE_KEY)"

bundle:
	bundle install

bundleup:
	bundle update

test: bundle ## Run tests (if any)
	bundle exec inspec exec -t aws://$(aws_region)/$(aws_profile) test/aws

clean: ## Remove local files other than state
	rm -rf _work _src

_work/$(SOURCE_STACK_NAME).zip:
	mkdir -p _work
	curl -sSL -o $@ "$(SOURCE_STACK_LOCATION)"
	unzip -j -d _src $@ '*/src/*'

bootstrap: _state/state_has_been_migrated ## Only run this the first time

_state/state_has_been_migrated: bootstrap_plan bootstrap_apply

bootstrap_init: _work/$(SOURCE_STACK_NAME).zip
	rm -f _src/remote_backend.tf
	cd _src && terraform init

bootstrap_plan: bootstrap_init
	cd _src && terraform plan \
		-state ../_state/terraform.tfstate \
		-var-file=../my-stack.tfvars \
		-var region=$(aws_region) \
		-var bucket_base_name=$(BUCKET_BASENAME) \
		-var managed_stack_name=$(MANAGED_STACK_NAME) \
		-var instance_identifier=$(INSTANCE_IDENTIFIER)

bootstrap_apply: bootstrap_init
	cd _src && terraform apply \
		-auto-approve \
		-state ../_state/terraform.tfstate \
		-var-file=../my-stack.tfvars \
		-var region=$(aws_region) \
		-var bucket_base_name=$(BUCKET_BASENAME) \
		-var managed_stack_name=$(MANAGED_STACK_NAME) \
		-var instance_identifier=$(INSTANCE_IDENTIFIER)

_src/remote_backend.tf:
	mkdir -p _src
	@echo 'terraform {' > $@
	@echo '  backend "s3" {}' >> $@
	@echo '}' >> $@

init: _work/$(SOURCE_STACK_NAME).zip _src/remote_backend.tf
	@echo "Copying local state in case of backend migration"
	if [ -f _state/terraform.tfstate ] ; then cp _state/terraform.tfstate _src/ ; fi;
	cd _src && terraform init \
		-backend=true \
		-force-copy \
		-backend-config="profile=$(aws_profile)" \
		-backend-config="region=$(aws_region)" \
		-backend-config='encrypt=true' \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="key=$(STATE_KEY)"
	mkdir -p _state && touch _state/state_has_been_migrated


plan: init ## Terraform plan
	cd _src && terraform plan \
		-var-file=../my-stack.tfvars \
		-var region=$(aws_region) \
		-var bucket_base_name=$(BUCKET_BASENAME) \
		-var managed_stack_name=$(MANAGED_STACK_NAME) \
		-var instance_identifier=$(INSTANCE_IDENTIFIER) \
		-var environment_name=$(environment_name)

apply: init ## Terraform apply
	cd _src && terraform apply \
		-auto-approve \
		-var-file=../my-stack.tfvars \
		-var region=$(aws_region) \
		-var bucket_base_name=$(BUCKET_BASENAME) \
		-var managed_stack_name=$(MANAGED_STACK_NAME) \
		-var instance_identifier=$(INSTANCE_IDENTIFIER) \
		-var environment_name=$(environment_name)

help:
	@grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
