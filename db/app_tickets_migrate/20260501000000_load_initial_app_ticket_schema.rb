# frozen_string_literal: true
class LoadInitialAppTicketSchema < ActiveRecord::Migration[8.2]
  def change
    enable_extension "citext"
    enable_extension "pg_catalog.plpgsql"
    enable_extension "pgcrypto"

    create_table "user_authorization_codes" do |t|
      t.string "acr"
      t.string "auth_method"
      t.string "client_id", limit: 64, null: false
      t.string "code", limit: 64, null: false
      t.string "code_challenge", null: false
      t.string "code_challenge_method", limit: 8, default: "S256", null: false
      t.datetime "consumed_at"
      t.datetime "created_at", null: false
      t.datetime "expires_at", null: false
      t.string "nonce"
      t.text "redirect_uri", null: false
      t.datetime "revoked_at"
      t.string "scope"
      t.bigint "user_id", null: false
      t.string "state"
      t.datetime "updated_at", null: false
      t.index ["code"], name: "index_user_authorization_codes_on_code", unique: true
      t.index ["expires_at"], name: "index_user_authorization_codes_on_expires_at"
      t.index ["user_id"], name: "index_user_authorization_codes_on_user_id"
    end

    create_table "user_reauth_sessions" do |t|
      t.integer "attempt_count", default: 0, null: false
      t.datetime "created_at", null: false
      t.datetime "discarded_at", default: ::Float::INFINITY, null: false
      t.string "method"
      t.datetime "purged_at", default: ::Float::INFINITY, null: false
      t.text "return_to", null: false
      t.string "scope", null: false
      t.string "status", null: false
      t.datetime "updated_at", null: false
      t.bigint "user_token_id", null: false
      t.datetime "verified_at"
      t.index ["user_token_id"], name: "index_user_reauth_sessions_on_user_token_id", unique: true
      t.check_constraint "discarded_at <= purged_at", name: "chk_user_reauth_sessions_retention_order"
    end

    create_table "user_token_binding_methods" do |t|
    end

    create_table "user_token_dbsc_statuses" do |t|
    end

    create_table "user_token_kinds" do |t|
    end

    create_table "user_token_statuses" do |t|
    end

    create_table "user_tokens" do |t|
      t.datetime "compromised_at"
      t.datetime "created_at", null: false
      t.text "dbsc_challenge"
      t.datetime "dbsc_challenge_issued_at"
      t.jsonb "dbsc_public_key"
      t.string "dbsc_session_id"
      t.datetime "deletable_at", default: ::Float::INFINITY, null: false
      t.string "device_id", default: "", null: false
      t.string "device_id_digest"
      t.datetime "expired_at"
      t.datetime "last_step_up_at"
      t.string "last_step_up_scope"
      t.datetime "last_used_at"
      t.string "public_id", limit: 21, default: "", null: false
      t.datetime "refresh_expires_at", null: false
      t.binary "refresh_token_digest"
      t.string "refresh_token_family_id"
      t.integer "refresh_token_generation", default: 0, null: false
      t.datetime "revoked_at"
      t.datetime "rotated_at"
      t.datetime "updated_at", null: false
      t.bigint "user_id", null: false
      t.bigint "user_token_binding_method_id", default: 0, null: false
      t.bigint "user_token_dbsc_status_id", default: 0, null: false
      t.bigint "user_token_kind_id", default: 0, null: false
      t.bigint "user_token_status_id", default: 1, null: false
      t.index ["compromised_at"], name: "index_user_tokens_on_compromised_at"
      t.index ["dbsc_session_id"], name: "index_user_tokens_on_dbsc_session_id", unique: true
      t.index ["deletable_at"], name: "index_user_tokens_on_deletable_at"
      t.index ["device_id"], name: "index_user_tokens_on_device_id"
      t.index ["device_id_digest"], name: "index_user_tokens_on_device_id_digest"
      t.index ["expired_at"], name: "index_user_tokens_on_expired_at"
      t.index ["public_id"], name: "index_user_tokens_on_public_id", unique: true
      t.index ["refresh_expires_at"], name: "index_user_tokens_on_refresh_expires_at"
      t.index ["refresh_token_digest"], name: "index_user_tokens_on_refresh_token_digest", unique: true
      t.index ["refresh_token_family_id"], name: "index_user_tokens_on_refresh_token_family_id"
      t.index ["revoked_at"], name: "index_user_tokens_on_revoked_at"
      t.index ["user_id", "last_step_up_at"], name: "index_user_tokens_on_user_id_and_last_step_up_at"
      t.index ["user_token_binding_method_id"], name: "index_user_tokens_on_user_token_binding_method_id"
      t.index ["user_token_dbsc_status_id"], name: "index_user_tokens_on_user_token_dbsc_status_id"
      t.index ["user_token_kind_id"], name: "index_user_tokens_on_user_token_kind_id"
      t.index ["user_token_status_id"], name: "index_user_tokens_on_user_token_status_id"
      t.check_constraint "user_token_kind_id >= 0", name: "chk_user_tokens_kind_id_positive"
      t.check_constraint "user_token_status_id >= 0", name: "chk_user_tokens_status_id_positive"
    end

    create_table "user_verifications" do |t|
      t.datetime "created_at", null: false
      t.datetime "expires_at", null: false
      t.datetime "last_used_at"
      t.datetime "revoked_at"
      t.string "token_digest", null: false
      t.datetime "updated_at", null: false
      t.bigserial "user_token_id", null: false
      t.index ["expires_at"], name: "index_user_verifications_on_expires_at"
      t.index ["token_digest"], name: "index_user_verifications_on_token_digest", unique: true
      t.index ["user_token_id"], name: "index_user_verifications_on_user_token_id"
    end

    add_foreign_key "user_tokens", "user_token_binding_methods", name: "fk_user_tokens_on_user_token_binding_method_id", validate: false
    add_foreign_key "user_tokens", "user_token_dbsc_statuses", name: "fk_user_tokens_on_user_token_dbsc_status_id", validate: false
    add_foreign_key "user_tokens", "user_token_kinds", name: "fk_user_tokens_on_user_token_kind_id", validate: false
    add_foreign_key "user_tokens", "user_token_statuses", name: "fk_user_tokens_on_user_token_status_id", validate: false
    add_foreign_key "user_reauth_sessions", "user_tokens", on_delete: :cascade, validate: false
    add_foreign_key "user_verifications", "user_tokens", on_delete: :cascade, validate: false
  end
end
