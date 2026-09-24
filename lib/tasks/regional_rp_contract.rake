# frozen_string_literal: true

require "fileutils"
require "json"

namespace :auth do
  desc "Audit the approved regional RP matrix without activating registrations"
  task regional_rp_contract: :environment do
    report_path = ENV.fetch("REPORT", "tmp/auth/regional_rp_contract.json")
    entries =
      RegionalRpClientMatrix.client_ids.map do |client_id|
        uri_binding = RegionalRpClientMatrix.uri_binding_for(client_id)
        complete_binding = RegionalRpClientMatrix.binding_for(client_id)
        {
          client_id:,
          status: "complete",
          uri_binding:,
          audience: complete_binding.fetch(:audience),
        }
      rescue RegionalRpClientMatrix::MissingCanonicalHost => e
        {
          client_id:,
          status: "missing_canonical_host",
          error: e.message,
        }
      rescue RegionalRpClientMatrix::MissingCanonicalAudience => e
        {
          client_id:,
          status: "missing_canonical_audience",
          error: e.message,
        }
      rescue RegionalRpClientMatrix::InvalidCanonicalRegistration => e
        {
          client_id:,
          status: "invalid_canonical_registration",
          error: e.message,
        }
      end
    report = {
      approved_client_ids: RegionalRpClientMatrix.client_ids,
      expected_registry_contract: RegionalRpClientMatrix.expected_registry_contract,
      complete: entries.all? { |entry| entry.fetch(:status) == "complete" },
      entries:,
    }
    path = Rails.root.join(report_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(report))

    summary = entries.map { |entry| entry.slice(:client_id, :status, :error) }
    puts JSON.pretty_generate(complete: report.fetch(:complete), entries: summary)
    puts "Report written to #{report_path}"
  end
end
