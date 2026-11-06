# frozen_string_literal: true

# Administrator tooling for org Microsoft Entra ID sign-in.
#
# The ceremony performs no JIT provisioning, so an operator can only sign in with
# Entra after `provision` and then `activate` have both been run for them.
# See docs/runbooks/entra-org-login.md.
change_state =
  lambda do |state|
    result = OperatorEntraIdentityActivation.call(operator_public_id: ENV.fetch("OPERATOR"), state: state)
    puts "identity=#{result.identity.public_id} #{result.previous_state} -> #{result.state}"
  end

namespace :entra_identity do
  desc "Create an inactive Entra identity for an operator (OPERATOR=public_id OID=entra_object_id)"
  task provision: :environment do
    result = OperatorEntraIdentityProvisioner.call(
      operator_public_id: ENV.fetch("OPERATOR"),
      entra_object_id: ENV.fetch("OID"),
    )

    puts "provisioned identity=#{result.identity.public_id} operator=#{result.operator_public_id} state=inactive"
    puts "run: bin/rails entra_identity:activate OPERATOR=#{result.operator_public_id}"
  end

  desc "Allow a provisioned operator to sign in with Entra (OPERATOR=public_id)"
  task activate: :environment do
    change_state.call("active")
  end

  desc "Stop an operator's Entra sign-in without deleting the mapping (OPERATOR=public_id)"
  task suspend: :environment do
    change_state.call("suspended")
  end

  desc "Permanently withdraw an operator's Entra sign-in (OPERATOR=public_id)"
  task revoke: :environment do
    change_state.call("revoked")
  end

  desc "List provisioned Entra identities and their state"
  task status: :environment do
    identities = OperatorEntraIdentity.order(created_at: :asc)
    if identities.empty?
      puts "no Entra identities are provisioned"
      next
    end

    identities.each do |identity|
      state = OperatorEntraIdentityActivation::STATES.key(identity.status_id) || "inactive"
      last = identity.last_authenticated_at&.iso8601 || "never"
      puts "identity=#{identity.public_id} operator_id=#{identity.operator_id} state=#{state} " \
           "last_authenticated_at=#{last}"
    end
  end

  desc "Check everything about org Entra sign-in that can be checked without a browser"
  task preflight: :environment do
    result = OrgEntraSignInPreflight.call
    result.checks.each { |check| puts "#{check.ok ? "ok  " : "FAIL"} #{check.name}: #{check.detail}" }
    abort("preflight failed") unless result.ok?
  end
end
