# frozen_string_literal: true

# adr/operator-capability-authorization.md, Bootstrap. The only way to issue the IAM capabilities,
# and the recovery path when no operator holds them. It grants to one explicitly named, eligible
# operator; there is no "all operators" or "first operator" form and no environment that skips it.
#
# The Chronicle intent is written first, and nothing is granted if it cannot be. See
# docs/operations/operator-capability-runbook.md.
namespace :operator_capabilities do
  desc "Grant capabilities to one operator (OPERATOR= CAPABILITIES=a,b TICKET= EXPIRES_AT=iso8601 [DRY_RUN=true])"
  task bootstrap: :environment do
    operator = Operator.find_by!(public_id: ENV.fetch("OPERATOR"))
    capabilities = ENV.fetch("CAPABILITIES").split(",")
    capabilities.map!(&:strip)
    capabilities.reject!(&:empty?)
    ticket_id = ENV.fetch("TICKET")
    expires_at = Time.iso8601(ENV.fetch("EXPIRES_AT"))
    dry_run = ENV.fetch("DRY_RUN", "false") == "true"

    if dry_run
      # Validates every input and every grant exactly as a real run would, and writes nothing.
      OperatorCapabilityGrant.bootstrap!(
        operator: operator, capabilities: capabilities, ticket_id: ticket_id, expires_at: expires_at, dry_run: true,
      ).each do |grant|
        puts "dry_run would grant operator=#{operator.public_id} capability=#{grant.capability} " \
             "expires_at=#{grant.expires_at.iso8601}"
      end
      next
    end

    event_uuid = SecureRandom.uuid
    action = "iam.capability.bootstrapped"

    chronicle = ChronicleIntentWriter.call(
      event_uuid: event_uuid,
      action: action,
      subject: operator,
      reason: OperatorCapabilityGrant::REASON_BOOTSTRAP,
      metadata: { capabilities: capabilities, ticket_id: ticket_id, subject_public_id: operator.public_id },
    )
    begin
      grants = OperatorCapabilityGrant.bootstrap!(
        operator: operator, capabilities: capabilities, ticket_id: ticket_id, expires_at: expires_at,
      )
    rescue StandardError => e
      ChronicleResultWriter.call(
        chronicle: chronicle,
        result: "failed",
        event_uuid: event_uuid,
        request_id: nil,
        action: action,
        subject: operator,
        changeset: { error_class: e.class.name },
      )
      raise
    end
    ChronicleResultWriter.call(
      chronicle: chronicle,
      result: "succeeded",
      event_uuid: event_uuid,
      request_id: nil,
      action: action,
      subject: operator,
      changeset: { grant_public_ids: grants.map(&:public_id) },
    )

    grants.each do |grant|
      puts "grant=#{grant.public_id} operator=#{operator.public_id} capability=#{grant.capability} " \
           "expires_at=#{grant.expires_at.iso8601}"
    end
    puts "audit event_uuid=#{event_uuid}"
  end

  desc "List in-force capability grants (OPERATOR=public_id optional)"
  task status: :environment do
    grants = OperatorCapabilityGrant.in_force.includes(:operator).order(:capability, :id)
    grants = grants.joins(:operator).where(operators: { public_id: ENV.fetch("OPERATOR") }) if ENV.key?("OPERATOR")
    if grants.empty?
      puts "no in-force capability grants"
      next
    end

    grants.each do |grant|
      puts "grant=#{grant.public_id} operator=#{grant.operator.public_id} capability=#{grant.capability} " \
           "origin=#{grant.origin} eligible=#{grant.operator.capability_eligible?} " \
           "expires_at=#{grant.expires_at.iso8601}"
    end
  end
end
