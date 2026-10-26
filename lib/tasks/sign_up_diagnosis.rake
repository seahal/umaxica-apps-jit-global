# frozen_string_literal: true

namespace :sign_up do
  desc "WU-26: print the read-only diagnosis of one sign-up attempt (SURFACE=app|com FLOW=<public id>)"
  task diagnose: :environment do
    report = SignUpAttemptDiagnosisInventory.call(surface: ENV.fetch("SURFACE"), flow_public_id: ENV.fetch("FLOW"))
    puts JSON.pretty_generate(report)
  end
end
