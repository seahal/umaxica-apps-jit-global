# frozen_string_literal: true

class LoadInitialChronicleSchema < ActiveRecord::Migration[8.2]
  def up
    enable_extension "citext"
    enable_extension "pg_catalog.plpgsql"

    create_table "app_document_audit_events" do |t|
    end

    create_table "app_document_audit_levels" do |t|
    end

    create_table "app_document_audits" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_app_document_audits_on_actor_id_and_occurred_at")
      t.index(["event_id"], name: "index_app_document_audits_on_event_id")
      t.index(["expires_at"], name: "index_app_document_audits_on_expires_at")
      t.index(["level_id"], name: "index_app_document_audits_on_level_id")
      t.index(["occurred_at"], name: "index_app_document_audits_on_occurred_at")
      t.index(["subject_id"], name: "index_app_document_audits_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_cf1fa79ee4")
      t.check_constraint("event_id >= 0", name: "app_document_audits_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "app_document_audits_level_id_non_negative_check")
    end

    create_table "app_preference_activities" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_app_preference_activities_on_actor_id_and_occurred_at")
      t.index(["event_id"], name: "index_app_preference_activities_on_event_id")
      t.index(["expires_at"], name: "index_app_preference_activities_on_expires_at")
      t.index(["level_id"], name: "index_app_preference_activities_on_level_id")
      t.index(["occurred_at"], name: "index_app_preference_activities_on_occurred_at")
      t.index(["subject_id"], name: "index_app_preference_activities_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_app_pref")
      t.check_constraint("event_id >= 0", name: "app_preference_activities_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "app_preference_activities_level_id_non_negative_check")
    end

    create_table "app_preference_activity_events" do |t|
    end

    create_table "app_preference_activity_levels" do |t|
    end

    create_table "app_timeline_audit_events" do |t|
    end

    create_table "app_timeline_audit_levels" do |t|
    end

    create_table "app_timeline_audits" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_app_timeline_audits_on_actor_id_and_occurred_at")
      t.index(["event_id"], name: "index_app_timeline_audits_on_event_id")
      t.index(["expires_at"], name: "index_app_timeline_audits_on_expires_at")
      t.index(["level_id"], name: "index_app_timeline_audits_on_level_id")
      t.index(["occurred_at"], name: "index_app_timeline_audits_on_occurred_at")
      t.index(["subject_id"], name: "index_app_timeline_audits_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_c80b4e4f83")
      t.check_constraint("event_id >= 0", name: "app_timeline_audits_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "app_timeline_audits_level_id_non_negative_check")
    end

    create_table "com_document_audit_events" do |t|
    end

    create_table "com_document_audit_levels" do |t|
    end

    create_table "com_document_audits" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_com_document_audits_on_actor_id_and_occurred_at")
      t.index(["event_id"], name: "index_com_document_audits_on_event_id")
      t.index(["expires_at"], name: "index_com_document_audits_on_expires_at")
      t.index(["level_id"], name: "index_com_document_audits_on_level_id")
      t.index(["occurred_at"], name: "index_com_document_audits_on_occurred_at")
      t.index(["subject_id"], name: "index_com_document_audits_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_c40361e81b")
      t.check_constraint("event_id >= 0", name: "com_document_audits_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "com_document_audits_level_id_non_negative_check")
    end

    create_table "com_preference_activities" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_com_preference_activities_on_actor_id_and_occurred_at")
      t.index(["event_id"], name: "index_com_preference_activities_on_event_id")
      t.index(["expires_at"], name: "index_com_preference_activities_on_expires_at")
      t.index(["level_id"], name: "index_com_preference_activities_on_level_id")
      t.index(["occurred_at"], name: "index_com_preference_activities_on_occurred_at")
      t.index(["subject_id"], name: "index_com_preference_activities_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_com_pref")
      t.check_constraint("event_id >= 0", name: "com_preference_activities_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "com_preference_activities_level_id_non_negative_check")
    end

    create_table "com_preference_activity_events" do |t|
    end

    create_table "com_preference_activity_levels" do |t|
    end

    create_table "com_timeline_audit_events" do |t|
    end

    create_table "com_timeline_audit_levels" do |t|
    end

    create_table "com_timeline_audits" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_com_timeline_audits_on_actor_id_and_occurred_at")
      t.index(["event_id"], name: "index_com_timeline_audits_on_event_id")
      t.index(["expires_at"], name: "index_com_timeline_audits_on_expires_at")
      t.index(["level_id"], name: "index_com_timeline_audits_on_level_id")
      t.index(["occurred_at"], name: "index_com_timeline_audits_on_occurred_at")
      t.index(["subject_id"], name: "index_com_timeline_audits_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_99ec847a5c")
      t.check_constraint("event_id >= 0", name: "com_timeline_audits_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "com_timeline_audits_level_id_non_negative_check")
    end

    create_table "org_document_audit_events" do |t|
    end

    create_table "org_document_audit_levels" do |t|
    end

    create_table "org_document_audits" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_org_document_audits_on_actor_id_and_occurred_at")
      t.index(["event_id"], name: "index_org_document_audits_on_event_id")
      t.index(["expires_at"], name: "index_org_document_audits_on_expires_at")
      t.index(["level_id"], name: "index_org_document_audits_on_level_id")
      t.index(["occurred_at"], name: "index_org_document_audits_on_occurred_at")
      t.index(["subject_id"], name: "index_org_document_audits_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_bf53171ad0")
      t.check_constraint("event_id >= 0", name: "org_document_audits_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "org_document_audits_level_id_non_negative_check")
    end

    create_table "org_preference_activities" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_org_preference_activities_on_actor_id_and_occurred_at")
      t.index(["event_id"], name: "index_org_preference_activities_on_event_id")
      t.index(["expires_at"], name: "index_org_preference_activities_on_expires_at")
      t.index(["level_id"], name: "index_org_preference_activities_on_level_id")
      t.index(["occurred_at"], name: "index_org_preference_activities_on_occurred_at")
      t.index(["subject_id"], name: "index_org_preference_activities_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_org_pref")
      t.check_constraint("event_id >= 0", name: "org_preference_activities_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "org_preference_activities_level_id_non_negative_check")
    end

    create_table "org_preference_activity_events" do |t|
    end

    create_table "org_preference_activity_levels" do |t|
    end

    create_table "org_timeline_audit_events" do |t|
    end

    create_table "org_timeline_audit_levels" do |t|
    end

    create_table "org_timeline_audits" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_org_timeline_audits_on_actor_id_and_occurred_at")
      t.index(["event_id"], name: "index_org_timeline_audits_on_event_id")
      t.index(["expires_at"], name: "index_org_timeline_audits_on_expires_at")
      t.index(["level_id"], name: "index_org_timeline_audits_on_level_id")
      t.index(["occurred_at"], name: "index_org_timeline_audits_on_occurred_at")
      t.index(["subject_id"], name: "index_org_timeline_audits_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_0f4341deba")
      t.check_constraint("event_id >= 0", name: "org_timeline_audits_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "org_timeline_audits_level_id_non_negative_check")
    end

    create_table "scavenger_global_events" do |t|
    end

    create_table "scavenger_global_statuses" do |t|
    end

    create_table "scavenger_globals" do |t|
      t.datetime("created_at", null: false)
      t.text("error_message")
      t.bigint("event_id", default: 0, null: false)
      t.datetime("finished_at")
      t.string("idempotency_key", limit: 128, null: false)
      t.string("job_type", limit: 64, null: false)
      t.datetime("occurred_at")
      t.jsonb("payload")
      t.integer("retry_count")
      t.datetime("started_at")
      t.bigint("status_id", default: 0, null: false)
      t.datetime("updated_at", null: false)
      t.index(["event_id"], name: "index_scavenger_globals_on_event_id")
      t.index(["idempotency_key"], name: "index_scavenger_globals_on_idempotency_key", unique: true)
      t.index(["job_type"], name: "index_scavenger_globals_on_job_type")
      t.index(["occurred_at"], name: "index_scavenger_globals_on_occurred_at")
      t.index(["status_id"], name: "index_scavenger_globals_on_status_id")
    end

    create_table "staff_activities" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_staff_activities_on_actor_id_and_occurred_at")
      t.index(["actor_type", "actor_id"], name: "index_staff_activities_on_actor")
      t.index(["event_id"], name: "index_staff_activities_on_event_id")
      t.index(["expires_at"], name: "index_staff_activities_on_expires_at")
      t.index(["level_id"], name: "index_staff_activities_on_level_id")
      t.index(["occurred_at"], name: "index_staff_activities_on_occurred_at")
      t.index(["subject_id"], name: "index_staff_activities_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_2e96c29236")
      t.check_constraint("event_id >= 0", name: "staff_activities_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "staff_activities_level_id_non_negative_check")
    end

    create_table "staff_activity_events" do |t|
    end

    create_table "staff_activity_levels" do |t|
    end

    create_table "user_activities" do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.text("actor_type", default: "", null: false)
      t.jsonb("context", default: {}, null: false)
      t.datetime("created_at", null: false)
      t.text("current_value", default: "", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.datetime("expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false)
      t.inet("ip_address", default: "0.0.0.0", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.text("previous_value", default: "", null: false)
      t.bigint("subject_id", null: false)
      t.text("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_id", "occurred_at"], name: "index_user_activities_on_actor_id_and_occurred_at")
      t.index(["actor_type", "actor_id"], name: "index_user_activities_on_actor")
      t.index(["event_id"], name: "index_user_activities_on_event_id")
      t.index(["expires_at"], name: "index_user_activities_on_expires_at")
      t.index(["level_id"], name: "index_user_activities_on_level_id")
      t.index(["occurred_at"], name: "index_user_activities_on_occurred_at")
      t.index(["subject_id"], name: "index_user_activities_on_subject_id")
      t.index(%w(subject_type subject_id occurred_at), name: "idx_on_subject_type_subject_id_occurred_at_a29eb711dd")
      t.check_constraint("event_id >= 0", name: "user_activities_event_id_non_negative_check")
      t.check_constraint("level_id >= 0", name: "user_activities_level_id_non_negative_check")
    end

    create_table "user_activity_events" do |t|
    end

    create_table "user_activity_levels" do |t|
    end

    create_table "app_document_behavior_events" do |t|
    end

    create_table "app_document_behavior_levels" do |t|
    end

    create_table "app_document_behaviors" do |t|
      t.bigint("actor_id")
      t.string("actor_type")
      t.datetime("created_at", null: false)
      t.bigint("event_id", null: false)
      t.datetime("expires_at")
      t.bigint("level_id", null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" })
      t.bigint("subject_id", null: false)
      t.string("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_type", "actor_id"], name: "index_app_document_behaviors_on_actor_type_and_actor_id")
      t.index(["event_id"], name: "index_app_document_behaviors_on_event_id")
      t.index(["level_id"], name: "index_app_document_behaviors_on_level_id")
      t.index(["subject_id"], name: "index_app_document_behaviors_on_subject_id")
      t.index(["subject_type", "subject_id"], name: "index_app_document_behaviors_on_subject_type_and_subject_id")
    end

    create_table "app_timeline_behavior_events" do |t|
    end

    create_table "app_timeline_behavior_levels" do |t|
    end

    create_table "app_timeline_behaviors" do |t|
      t.bigint("actor_id")
      t.string("actor_type")
      t.datetime("created_at", null: false)
      t.bigint("event_id", null: false)
      t.datetime("expires_at")
      t.bigint("level_id", null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" })
      t.bigint("subject_id", null: false)
      t.string("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_type", "actor_id"], name: "index_app_timeline_behaviors_on_actor_type_and_actor_id")
      t.index(["event_id"], name: "index_app_timeline_behaviors_on_event_id")
      t.index(["level_id"], name: "index_app_timeline_behaviors_on_level_id")
      t.index(["subject_id"], name: "index_app_timeline_behaviors_on_subject_id")
      t.index(["subject_type", "subject_id"], name: "index_app_timeline_behaviors_on_subject_type_and_subject_id")
    end

    create_table "com_document_behavior_events" do |t|
    end

    create_table "com_document_behavior_levels" do |t|
    end

    create_table "com_document_behaviors" do |t|
      t.bigint("actor_id")
      t.string("actor_type")
      t.datetime("created_at", null: false)
      t.bigint("event_id", null: false)
      t.datetime("expires_at")
      t.bigint("level_id", null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" })
      t.bigint("subject_id", null: false)
      t.string("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_type", "actor_id"], name: "index_com_document_behaviors_on_actor_type_and_actor_id")
      t.index(["event_id"], name: "index_com_document_behaviors_on_event_id")
      t.index(["level_id"], name: "index_com_document_behaviors_on_level_id")
      t.index(["subject_id"], name: "index_com_document_behaviors_on_subject_id")
      t.index(["subject_type", "subject_id"], name: "index_com_document_behaviors_on_subject_type_and_subject_id")
    end

    create_table "com_timeline_behavior_events" do |t|
    end

    create_table "com_timeline_behavior_levels" do |t|
    end

    create_table "com_timeline_behaviors" do |t|
      t.bigint("actor_id")
      t.string("actor_type")
      t.datetime("created_at", null: false)
      t.bigint("event_id", null: false)
      t.datetime("expires_at")
      t.bigint("level_id", null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" })
      t.bigint("subject_id", null: false)
      t.string("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_type", "actor_id"], name: "index_com_timeline_behaviors_on_actor_type_and_actor_id")
      t.index(["event_id"], name: "index_com_timeline_behaviors_on_event_id")
      t.index(["level_id"], name: "index_com_timeline_behaviors_on_level_id")
      t.index(["subject_id"], name: "index_com_timeline_behaviors_on_subject_id")
      t.index(["subject_type", "subject_id"], name: "index_com_timeline_behaviors_on_subject_type_and_subject_id")
    end

    create_table "org_document_behavior_events" do |t|
    end

    create_table "org_document_behavior_levels" do |t|
    end

    create_table "org_document_behaviors" do |t|
      t.bigint("actor_id")
      t.string("actor_type")
      t.datetime("created_at", null: false)
      t.bigint("event_id", null: false)
      t.datetime("expires_at")
      t.bigint("level_id", null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" })
      t.bigint("subject_id", null: false)
      t.string("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_type", "actor_id"], name: "index_org_document_behaviors_on_actor_type_and_actor_id")
      t.index(["event_id"], name: "index_org_document_behaviors_on_event_id")
      t.index(["level_id"], name: "index_org_document_behaviors_on_level_id")
      t.index(["subject_id"], name: "index_org_document_behaviors_on_subject_id")
      t.index(["subject_type", "subject_id"], name: "index_org_document_behaviors_on_subject_type_and_subject_id")
    end

    create_table "org_timeline_behavior_events" do |t|
    end

    create_table "org_timeline_behavior_levels" do |t|
    end

    create_table "org_timeline_behaviors" do |t|
      t.bigint("actor_id")
      t.string("actor_type")
      t.datetime("created_at", null: false)
      t.bigint("event_id", null: false)
      t.datetime("expires_at")
      t.bigint("level_id", null: false)
      t.datetime("occurred_at", default: -> { "CURRENT_TIMESTAMP" })
      t.bigint("subject_id", null: false)
      t.string("subject_type", null: false)
      t.datetime("updated_at", null: false)
      t.index(["actor_type", "actor_id"], name: "index_org_timeline_behaviors_on_actor_type_and_actor_id")
      t.index(["event_id"], name: "index_org_timeline_behaviors_on_event_id")
      t.index(["level_id"], name: "index_org_timeline_behaviors_on_level_id")
      t.index(["subject_id"], name: "index_org_timeline_behaviors_on_subject_id")
      t.index(["subject_type", "subject_id"], name: "index_org_timeline_behaviors_on_subject_type_and_subject_id")
    end

    create_table "scavenger_regional_events" do |t|
    end

    create_table "scavenger_regional_statuses" do |t|
    end

    create_table "scavenger_regionals" do |t|
      t.datetime("created_at", null: false)
      t.text("error_message")
      t.bigint("event_id", default: 0, null: false)
      t.datetime("finished_at")
      t.string("idempotency_key", limit: 128, null: false)
      t.string("job_type", limit: 64, null: false)
      t.datetime("occurred_at")
      t.jsonb("payload")
      t.bigint("region_id", null: false)
      t.integer("retry_count")
      t.datetime("started_at")
      t.bigint("status_id", default: 0, null: false)
      t.datetime("updated_at", null: false)
      t.index(["event_id"], name: "index_scavenger_regionals_on_event_id")
      t.index(["occurred_at"], name: "index_scavenger_regionals_on_occurred_at")
      t.index(
        ["region_id", "idempotency_key"], name: "index_scavenger_regionals_on_region_id_and_idempotency_key",
                                          unique: true,
      )
      t.index(["region_id", "job_type"], name: "index_scavenger_regionals_on_region_id_and_job_type")
      t.index(["status_id"], name: "index_scavenger_regionals_on_status_id")
    end

    safety_assured do
      add_foreign_key "app_document_audits", "app_document_audit_events", column: "event_id", validate: false
      add_foreign_key "app_document_audits", "app_document_audit_levels", column: "level_id", validate: false
      add_foreign_key "app_preference_activities", "app_preference_activity_events", column: "event_id", validate: false
      add_foreign_key "app_preference_activities", "app_preference_activity_levels", column: "level_id", validate: false
      add_foreign_key "app_timeline_audits", "app_timeline_audit_events", column: "event_id", validate: false
      add_foreign_key "app_timeline_audits", "app_timeline_audit_levels", column: "level_id", validate: false
      add_foreign_key "com_document_audits", "com_document_audit_events", column: "event_id", validate: false
      add_foreign_key "com_document_audits", "com_document_audit_levels", column: "level_id", validate: false
      add_foreign_key "com_preference_activities", "com_preference_activity_events", column: "event_id", validate: false
      add_foreign_key "com_preference_activities", "com_preference_activity_levels", column: "level_id", validate: false
      add_foreign_key "com_timeline_audits", "com_timeline_audit_events", column: "event_id", validate: false
      add_foreign_key "com_timeline_audits", "com_timeline_audit_levels", column: "level_id", validate: false
      add_foreign_key "org_document_audits", "org_document_audit_events", column: "event_id", validate: false
      add_foreign_key "org_document_audits", "org_document_audit_levels", column: "level_id", validate: false
      add_foreign_key "org_preference_activities", "org_preference_activity_events", column: "event_id", validate: false
      add_foreign_key "org_preference_activities", "org_preference_activity_levels", column: "level_id", validate: false
      add_foreign_key "org_timeline_audits", "org_timeline_audit_events", column: "event_id", validate: false
      add_foreign_key "org_timeline_audits", "org_timeline_audit_levels", column: "level_id", validate: false
      add_foreign_key "scavenger_globals", "scavenger_global_events", column: "event_id"
      add_foreign_key "scavenger_globals", "scavenger_global_statuses", column: "status_id"
      add_foreign_key "staff_activities", "staff_activity_events", column: "event_id", validate: false
      add_foreign_key "staff_activities", "staff_activity_levels", column: "level_id", validate: false
      add_foreign_key "user_activities", "user_activity_events", column: "event_id", validate: false
      add_foreign_key "user_activities", "user_activity_levels", column: "level_id", validate: false
      add_foreign_key "app_document_behaviors", "app_document_behavior_events", column: "event_id"
      add_foreign_key "app_document_behaviors", "app_document_behavior_levels", column: "level_id"
      add_foreign_key "app_timeline_behaviors", "app_timeline_behavior_events", column: "event_id"
      add_foreign_key "app_timeline_behaviors", "app_timeline_behavior_levels", column: "level_id"
      add_foreign_key "com_document_behaviors", "com_document_behavior_events", column: "event_id"
      add_foreign_key "com_document_behaviors", "com_document_behavior_levels", column: "level_id"
      add_foreign_key "com_timeline_behaviors", "com_timeline_behavior_events", column: "event_id"
      add_foreign_key "com_timeline_behaviors", "com_timeline_behavior_levels", column: "level_id"
      add_foreign_key "org_document_behaviors", "org_document_behavior_events", column: "event_id"
      add_foreign_key "org_document_behaviors", "org_document_behavior_levels", column: "level_id"
      add_foreign_key "org_timeline_behaviors", "org_timeline_behavior_events", column: "event_id"
      add_foreign_key "org_timeline_behaviors", "org_timeline_behavior_levels", column: "level_id"
      add_foreign_key "scavenger_regionals", "scavenger_regional_events", column: "event_id"
      add_foreign_key "scavenger_regionals", "scavenger_regional_statuses", column: "status_id"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
