# frozen_string_literal: true

class LoadInitialOrgSettingSchema < ActiveRecord::Migration[8.2]
  def up
    enable_extension "citext"
    enable_extension "pg_catalog.plpgsql"
    enable_extension "pgcrypto"

    create_table "org_preference_binding_methods" do |t|
    end

    create_table "org_preference_cookies" do |t|
      t.bigint("preference_id", null: false)
      t.uuid("consent_version")
      t.boolean("consented", default: false, null: false)
      t.datetime("consented_at")
      t.datetime("created_at", null: false)
      t.boolean("functional", default: false, null: false)
      t.boolean("performant", default: false, null: false)
      t.boolean("targetable", default: false, null: false)
      t.datetime("updated_at", null: false)
      t.index(["preference_id"], name: "index_org_preference_cookies_on_preference_id", unique: true)
    end

    create_table "org_preference_currencies" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_currencies_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_currencies_on_preference_id", unique: true)
    end

    create_table "org_preference_currency_options" do |t|
    end

    create_table "org_preference_date_format_options" do |t|
    end

    create_table "org_preference_date_formats" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_date_formats_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_date_formats_on_preference_id", unique: true)
    end

    create_table "org_preference_dbsc_statuses" do |t|
    end

    create_table "org_preference_densities" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_densities_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_densities_on_preference_id", unique: true)
    end

    create_table "org_preference_density_options" do |t|
    end

    create_table "org_preference_items_per_page_options" do |t|
    end

    create_table "org_preference_items_per_pages" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_items_per_pages_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_items_per_pages_on_preference_id", unique: true)
    end

    create_table "org_preference_language_options" do |t|
    end

    create_table "org_preference_languages" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_languages_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_languages_on_preference_id", unique: true)
    end

    create_table "org_preference_motion_options" do |t|
    end

    create_table "org_preference_motions" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_motions_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_motions_on_preference_id", unique: true)
    end

    create_table "org_preference_region_options" do |t|
    end

    create_table "org_preference_regions" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_regions_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_regions_on_preference_id", unique: true)
    end

    create_table "org_preference_statuses" do |t|
    end

    create_table "org_preference_theme_options" do |t|
    end

    create_table "org_preference_themes" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_themes_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_themes_on_preference_id", unique: true)
    end

    create_table "org_preference_time_format_options" do |t|
    end

    create_table "org_preference_time_formats" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_time_formats_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_time_formats_on_preference_id", unique: true)
    end

    create_table "org_preference_timezone_options" do |t|
    end

    create_table "org_preference_timezones" do |t|
      t.bigint("preference_id", null: false)
      t.bigint("option_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["option_id"], name: "index_org_preference_timezones_on_option_id")
      t.index(["preference_id"], name: "index_org_preference_timezones_on_preference_id", unique: true)
    end

    create_table "org_preferences" do |t|
      t.bigint("binding_method_id", default: 0, null: false)
      t.datetime("created_at", null: false)
      t.text("dbsc_challenge")
      t.datetime("dbsc_challenge_issued_at")
      t.jsonb("dbsc_public_key")
      t.string("dbsc_session_id")
      t.bigint("dbsc_status_id", default: 0, null: false)
      t.string("device_id")
      t.string("jti")
      t.string("public_id", null: false)
      t.bigint("replaced_by_id")
      t.bigint("status_id", default: 2, null: false)
      t.binary("token_digest")
      t.datetime("updated_at", null: false)
      t.datetime("used_at")
      t.string("device_id_digest")
      t.datetime("purged_at", default: ::Float::INFINITY, null: false)
      t.datetime("discarded_at", default: ::Float::INFINITY, null: false)
      t.index(["binding_method_id"], name: "index_org_preferences_on_binding_method_id")
      t.index(["dbsc_session_id"], name: "index_org_preferences_on_dbsc_session_id", unique: true)
      t.index(["dbsc_status_id"], name: "index_org_preferences_on_dbsc_status_id")
      t.index(["device_id"], name: "index_org_preferences_on_device_id")
      t.index(["device_id_digest"], name: "index_org_preferences_on_device_id_digest")
      t.index(["jti"], name: "index_org_preferences_on_jti", unique: true)
      t.index(["public_id"], name: "index_org_preferences_on_public_id", unique: true)
      t.index(["purged_at"], name: "index_org_preferences_on_purge_at")
      t.index(["replaced_by_id"], name: "index_org_preferences_on_replaced_by_id")
      t.index(["status_id"], name: "index_org_preferences_on_status_id")
      t.index(["token_digest"], name: "index_org_preferences_on_token_digest")
      t.index(["used_at"], name: "index_org_preferences_on_used_at")
    end

    safety_assured do
      add_foreign_key "org_preference_cookies", "org_preferences", column: "preference_id", validate: false
      add_foreign_key "org_preference_currencies", "org_preference_currency_options", column: "option_id"
      add_foreign_key "org_preference_currencies", "org_preferences", column: "preference_id"
      add_foreign_key "org_preference_date_formats", "org_preference_date_format_options", column: "option_id"
      add_foreign_key "org_preference_date_formats", "org_preferences", column: "preference_id"
      add_foreign_key "org_preference_densities", "org_preference_density_options", column: "option_id"
      add_foreign_key "org_preference_densities", "org_preferences", column: "preference_id"
      add_foreign_key "org_preference_items_per_pages", "org_preference_items_per_page_options", column: "option_id"
      add_foreign_key "org_preference_items_per_pages", "org_preferences", column: "preference_id"
      add_foreign_key "org_preference_languages", "org_preference_language_options", column: "option_id", name: "fk_org_preference_languages_on_option_id", validate: false
      add_foreign_key "org_preference_languages", "org_preferences", column: "preference_id", validate: false
      add_foreign_key "org_preference_motions", "org_preference_motion_options", column: "option_id"
      add_foreign_key "org_preference_motions", "org_preferences", column: "preference_id"
      add_foreign_key "org_preference_regions", "org_preference_region_options", column: "option_id", name: "fk_org_preference_regions_on_option_id", validate: false
      add_foreign_key "org_preference_regions", "org_preferences", column: "preference_id", validate: false
      add_foreign_key "org_preference_themes", "org_preference_theme_options", column: "option_id", name: "fk_org_preference_themes_on_option_id", validate: false
      add_foreign_key "org_preference_themes", "org_preferences", column: "preference_id", validate: false
      add_foreign_key "org_preference_time_formats", "org_preference_time_format_options", column: "option_id"
      add_foreign_key "org_preference_time_formats", "org_preferences", column: "preference_id"
      add_foreign_key "org_preference_timezones", "org_preference_timezone_options", column: "option_id", name: "fk_org_preference_timezones_on_option_id", validate: false
      add_foreign_key "org_preference_timezones", "org_preferences", column: "preference_id", validate: false
      add_foreign_key "org_preferences", "org_preference_binding_methods", column: "binding_method_id", name: "fk_org_preferences_on_binding_method_id", validate: false
      add_foreign_key "org_preferences", "org_preference_dbsc_statuses", column: "dbsc_status_id", name: "fk_org_preferences_on_dbsc_status_id", validate: false
      add_foreign_key "org_preferences", "org_preference_statuses", column: "status_id", name: "fk_org_preferences_on_status_id", validate: false
      add_foreign_key "org_preferences", "org_preferences", column: "replaced_by_id", on_delete: :nullify, validate: false
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
