.DEFAULT_GOAL := help

AWS_REGION=us-east-1
AWS_PROFILE=stackrepo_bootstrap
SOURCE_STACK_NAME=spin-stack-s3bucket
SOURCE_STACK_LOCATION=https://github.com/cloudspinners/$(SOURCE_STACK_NAME)/archive/master.zip
AWS_ACCOUNT=$(shell aws --profile $(AWS_PROFILE) sts get-caller-identity --output text --query Account)
BUCKET_BASE_NAME=ksm

bundle:
	bundle install

bundleup:
	bundle update

test: bundle
	bundle exec inspec exec -t aws://$(AWS_REGION)/$(AWS_PROFILE) test/aws

fetch:
	rm -rf _work _src
	mkdir -p _work
	curl -sSL -o _work/$(SOURCE_STACK_NAME).zip "$(SOURCE_STACK_LOCATION)"
	unzip -j -d _src _work/$(SOURCE_STACK_NAME).zip '*/src/*'

bootstrap_init:
	rm -f _src/remote_backend.tf
	cd _src && terraform init

bootstrap_plan: bootstrap_init
	cd _src && terraform plan \
		-state ../_state/terraform.tfstate \
		-var-file=../stack.tfvars

bootstrap_apply: bootstrap_init
	cd _src && terraform apply \
		-auto-approve \
		-state ../_state/terraform.tfstate \
		-var-file=../stack.tfvars

_src/remote_backend.tf:
	mkdir -p _src
	@echo 'terraform {' > $@
	@echo '  backend "s3" {}' >> $@
	@echo '}' >> $@

init: _src/remote_backend.tf
	cd _src && terraform init \
		-backend=true \
		-force-copy \
		-backend-config "region=$(AWS_REGION)" \
		-backend-config 'encrypt=true' \
		-backend-config "bucket=$(BUCKET_BASE_NAME)-$(AWS_ACCOUNT)" \
		-backend-config "profile=$(AWS_PROFILE)" \
		-backend-config "key=$(SOURCE_STACK_NAME)/bucket-$(BUCKET_BASE_NAME).tfstate"
# 		-backend-config "role_arn=arn:aws:iam::$(AWS_ACCOUNT):role/$(AWS_ASSUME_ROLE)" \

plan: init ## Terraform plan
	cd _src && terraform plan \
		-var-file=../stack.tfvars

apply: init ## Terraform apply
	cd _src && terraform apply \
		-auto-approve \
		-var-file=../stack.tfvars

help:
	@grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
