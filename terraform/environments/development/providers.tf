# Development environment: every AWS API call is served by the fakecloud
# container defined in the repository-root compose.yaml.
#
# This file is the ONLY place the fakecloud endpoint and its fake credentials
# appear. The modules under ../../modules are environment-agnostic, so a future
# production environment reuses them unchanged and simply omits this provider
# configuration in favour of the real AWS endpoints and a real credential source.
#
# The endpoint defaults to localhost, not `fakecloud`, because Terraform was
# first driven from the developer's host against the loopback publication in
# compose.yaml.
#
# `terraform` is installed inside `core` by the devcontainer feature in
# .devcontainer/devcontainer.json. That feature was added 2026-09-14; comments
# here and in three documents had claimed it since 2026-08-31, while the binary
# was in fact absent. Running Terraform in `core` needs the container-side
# address, because `localhost` in `core` is `core` itself:
#
#   TF_VAR_fakecloud_endpoint=http://fakecloud:4566 terraform plan
#
# Both paths work; only the endpoint differs. This is not yet exercised in
# either location -- see the status note in variables.tf.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state on purpose: this environment describes a disposable emulator on
  # one developer's machine, so there is nothing to share or lock. A production
  # environment would need a real remote backend, which is deferred with the
  # rest of the production infrastructure.
  backend "local" {}
}

provider "aws" {
  region = var.region

  # Obviously-fake credentials. fakecloud validates the shape of a SigV4
  # signature and never the key material, and these values match the
  # OBJECT_STORAGE_ACCESS_KEY_ID/SECRET_ACCESS_KEY the `core` service uses.
  # Hardcoding them here means a real AWS credential in the ambient environment
  # cannot be picked up and pointed at development infrastructure by accident.
  access_key = "test"
  secret_key = "test"

  # The provider otherwise calls IMDS and STS against real AWS during
  # initialisation. There is no account behind fakecloud, so each of these
  # would fail before any resource is planned.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  # fakecloud is addressed by host and port, so virtual-hosted bucket URLs
  # (bucket.localhost) do not resolve. This matches OBJECT_STORAGE_FORCE_PATH_STYLE
  # in compose.yaml. Real AWS uses virtual-hosted style, which is one of the
  # documented differences between this environment and production.
  s3_use_path_style = true

  endpoints {
    s3    = var.fakecloud_endpoint
    kafka = var.fakecloud_endpoint
    sts   = var.fakecloud_endpoint
    ec2   = var.fakecloud_endpoint
    iam   = var.fakecloud_endpoint
  }
}
