
This project is part of the supporting infrastructure for the Better Infrastructure Learning Programme.


# What

Create a "root" S3 bucket for storing remote terraform statefiles. We'd like the training participants to start working on infrastructure before they have to worry about making buckets, migrating state, and that faff.

The bucket will be named *workshop-ENVIRONMENT-AWS_ACCOUNT*. *ENVIRONMENT* is set in your configuration file (see below), *AWS_ACCOUNT* is the AWS account ID (a string of digits), which is determined dynamically.

The state for this stack will be migrated to the bucket itself.


# How

- Create an IAM user with API credentials configured in a profile in `~/.aws/credentials`
- Create and edit your local configuration file: `cp example-stack.tfvars my-stack.tfvars`
- Run `make bootstrap_plan`, and when you're happy with that, `make bootstrap_apply`. This should make the s3 bucket, storing your statefile locally
- Once that's working, run `make plan`, which should migrate the state to the bucket that you created in the previous steps without changing the bucket or other resources in AWS. This should show that there are no changes to be made.


# Details

This project works by downloading terraform source from a [cloudspin project](https://github.com/cloudspinners/spin-stack-s3bucket).

The bootstrap_* targets use a local statefile. The init target (which is a dependency of the plan and apply targets) adds the remote backend to the source and will then cause the state to be moved up to the bucket.

