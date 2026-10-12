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

  desc "Inventory and optionally backfill bounded concrete Avatar Group ownership periods"
  task group_ownership_periods: :environment do
    raw_ids = ENV.fetch("AVATAR_GROUP_IDS", "")
    ids = raw_ids.split(",").filter_map { |value| Integer(value, 10, exception: false) }
    if ids.empty? || ids.length > AvatarGroupConcreteOwnershipBackfillOperation::BATCH_SIZE
      abort "AVATAR_GROUP_IDS must contain 1..#{AvatarGroupConcreteOwnershipBackfillOperation::BATCH_SIZE} positive IDs"
    end
    abort "AVATAR_GROUP_IDS must contain positive IDs" unless ids.all?(&:positive?)

    apply = ENV["APPLY"] == "1"
    path = ENV.fetch("REPORT", "tmp/avatar_backfill/avatar_group_ownership_periods.json")
    result = AvatarGroupConcreteOwnershipBackfillOperation.call(group_ids: ids.uniq, apply: apply, output_path: path)
    puts JSON.pretty_generate(result.summary)
    puts "Report written to #{path}"
  end

  desc "Prepare and optionally establish the verified Avatar ownership writer cutover"
  task ownership_cutover: :environment do
    raw_avatar_ids = ENV.fetch("AVATAR_IDS", "")
    raw_group_ids = ENV.fetch("AVATAR_GROUP_IDS", "")
    avatar_ids = raw_avatar_ids.split(",").filter_map { |value| Integer(value, 10, exception: false) }
    group_ids = raw_group_ids.split(",").filter_map { |value| Integer(value, 10, exception: false) }
    if avatar_ids.empty? || avatar_ids.length > AvatarOwnershipTransitionInventoryQuery::BATCH_SIZE
      abort "AVATAR_IDS must contain 1..#{AvatarOwnershipTransitionInventoryQuery::BATCH_SIZE} positive IDs"
    end
    abort "AVATAR_IDS must contain positive IDs" unless avatar_ids.all?(&:positive?)
    abort "AVATAR_GROUP_IDS must contain only positive IDs" unless group_ids.all?(&:positive?)
    abort "AVATAR_GROUP_IDS is too large" if group_ids.length > AvatarGroupOwnershipTransitionInventoryQuery::BATCH_SIZE

    writer_quiesced = ENV.fetch("WRITER_QUIESCED") == "1"
    apply = ENV["APPLY"] == "1"
    path = ENV.fetch("REPORT", "tmp/avatar_backfill/avatar_ownership_cutover.json")
    result = AvatarOwnershipCutoverOperation.call(
      avatar_ids: avatar_ids.uniq,
      group_ids: group_ids.uniq,
      writer_quiesced: writer_quiesced,
      apply: apply,
    )
    FileUtils.mkdir_p(Rails.root.join(path).dirname)
    Rails.root.join(path).write(result.to_json)
    puts JSON.pretty_generate(result.summary)
    puts "Report written to #{path}"
  end
end
