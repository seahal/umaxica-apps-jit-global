# typed: false
# frozen_string_literal: true

# Warm the FIXED_ID_SEED_CACHE for all preference reference tables at server
# startup. This prevents the first incoming request from blocking on
# insert_missing_fixed_ids! when those tables are empty (e.g. after db:reset).
#
# If the app_setting DB is unavailable at startup (e.g. the server was started
# before the DB finished initialising), each class is skipped with a warning.
# The request-path fallback in insert_missing_fixed_ids! handles seeding later.
Rails.application.config.after_initialize do
  next if Rails.env.test?

  reference_classes = [
    # Status
    AppPreferenceStatus, ComPreferenceStatus, OrgPreferenceStatus,
    # Audit levels
    AppPreferenceChronicleLevel, ComPreferenceChronicleLevel, OrgPreferenceChronicleLevel,
    # Audit events
    AppPreferenceChronicleEvent, ComPreferenceChronicleEvent, OrgPreferenceChronicleEvent,
  ]

  reference_classes.each do |klass|
    next unless klass.respond_to?(:ensure_defaults!)

    klass.ensure_defaults!
  rescue ActiveRecord::NoDatabaseError,
         ActiveRecord::ConnectionNotEstablished,
         ActiveRecord::StatementInvalid,
         ActiveRecord::ActiveRecordError => e
    Rails.logger.warn(
      JitLogEvent.format(
        "preference_reference_defaults.skipped",
        class: klass.name,
        error_class: e.class.name,
        error_message: e.message.split("\n").first,
      ),
    )
  end
end
