# frozen_string_literal: true

namespace :org_telephone_public_ids do
  desc "Report live legacy ORG Telephone ceremony and receipt counts without modifying proof"
  task legacy_references: :environment do
    puts OperatorTelephoneLegacyReferenceInventory.call(
      scope: OperatorTelephoneCeremonyTransaction.all,
    ).to_json
  end

  desc "Report missing ORG Telephone public IDs without changing identifiers or proof"
  task :inventory, [:batch_size] => :environment do |_task, args|
    size = args[:batch_size]
    unless size.is_a?(String) && size.match?(/\A[1-9][0-9]*\z/)
      raise ArgumentError, "an explicit positive batch size is required"
    end

    puts OperatorTelephonePublicIdBackfillOperation.call(
      scope: OperatorTelephone.all, dry_run: true, batch_size: Integer(size, 10),
    ).to_json
  end

  desc "Backfill missing ORG Telephone public IDs in the explicitly selected database"
  task :backfill, %i(database batch_size) => :environment do |_task, args|
    unless args[:database].present? && args[:database] == OperatorTelephone.connection_db_config.database
      raise ArgumentError, "explicit ORG Telephone database target does not match the current connection"
    end

    size = args[:batch_size]
    unless size.is_a?(String) && size.match?(/\A[1-9][0-9]*\z/)
      raise ArgumentError, "an explicit positive batch size is required"
    end

    puts OperatorTelephonePublicIdBackfillOperation.call(
      scope: OperatorTelephone.all, dry_run: false, batch_size: Integer(size, 10),
    ).to_json
  end
end
