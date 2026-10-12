# frozen_string_literal: true

namespace :avatar_backfill do
  desc "Dry-run audit legacy avatars.client_id rows before binding backfill"
  task audit_legacy_client_bindings: :environment do
    path = ENV.fetch("REPORT", "tmp/avatar_backfill/legacy_client_binding_audit.json")
    result = AvatarBackfill::AuditLegacyClientBindings.call(output_path: path)
    puts JSON.pretty_generate(result.summary)
    puts "Report written to #{path}"
  end

  desc I18n.t("avatar_backfill.legacy_client_bindings_desc")
  task legacy_client_bindings: :environment do
    apply = ENV["APPLY"] == "1"
    path = ENV.fetch("REPORT", "tmp/avatar_backfill/legacy_client_binding_backfill.json")
    result = AvatarBackfill::BackfillLegacyClientBindings.call(apply: apply, output_path: path)
    puts JSON.pretty_generate(result.summary)
    puts "Report written to #{path}"
  end

  desc "Inventory and optionally backfill bounded concrete Avatar ownership periods"
  task ownership_periods: :environment do
    raw_ids = ENV.fetch("AVATAR_IDS", "")
    ids = raw_ids.split(",").filter_map { |value| Integer(value, 10, exception: false) }
    if ids.empty? || ids.length > AvatarConcreteOwnershipBackfillOperation::BATCH_SIZE
      abort "AVATAR_IDS must contain 1..#{AvatarConcreteOwnershipBackfillOperation::BATCH_SIZE} positive IDs"
    end
    abort "AVATAR_IDS must contain positive IDs" unless ids.all?(&:positive?)

    apply = ENV["APPLY"] == "1"
    path = ENV.fetch("REPORT", "tmp/avatar_backfill/avatar_ownership_periods.json")
    result = AvatarConcreteOwnershipBackfillOperation.call(avatar_ids: ids.uniq, apply: apply, output_path: path)
    puts JSON.pretty_generate(result.summary)
    puts "Report written to #{path}"
  end
end
