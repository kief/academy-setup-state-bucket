
This project is part of the supporting infrastructure for my infrastructure implementation training programme.


# What this is for

Create a "root" S3 bucket for storing remote terraform statefiles. We'd like the training participants to start working on infrastructure before they have to worry about making buckets, migrating state, and that faff.


# How to use it

Edit the `stack.tfvars` file. Edit the `Makefile` and set things at the top.

Run `make bootstrap_plan`, and when you're happy with that, `make bootstrap_apply`. This should make the s3 bucket. It will download the terraform source from a [cloudspin project](https://github.com/cloudspinners/spin-stack-s3bucket). The state will be stored locally in the first instance.

Once that's working, you can run `make init`, which should migrate the state to the bucket that you created in the previous steps.
