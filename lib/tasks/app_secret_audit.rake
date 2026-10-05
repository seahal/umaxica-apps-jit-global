# frozen_string_literal: true

namespace :app_secret do
  desc "Provision the required security audit policy with an explicitly approved retention duration"
  task provision_audit_policy: :environment do
    days = Integer(ENV.fetch("CHRONICLE_SECURITY_RETENTION_DAYS"), 10)
    raise ArgumentError, "security audit retention days must be positive" unless days.positive?

    ChronicleRecord.connected_to(role: :writing) do
      policy =
        ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |record|
          record.name = "Security"
          record.duration_days = days
          record.permanent = false
        end
      unless policy.duration_days == days && !policy.permanent?
        raise ArgumentError, "existing security policy differs; changing audit retention requires a separate decision"
      end

      puts "Security audit policy verified: #{policy.duration_days} days; existing audit history preserved"
    end
  end
end
