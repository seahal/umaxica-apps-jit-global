# typed: false
# frozen_string_literal: true

# Validate app/com timing overrides during every Rails process boot, including Solid Queue
# workers and schedulers. Production must never start with development-only shortening variables.
require Rails.root.join("app/values/umaxica/withdrawal/timing_policy_value").to_s

Umaxica::Withdrawal::TimingPolicyValue.validate_environment!(
  environment: Rails.env.to_s,
  environment_variables: ENV,
)
