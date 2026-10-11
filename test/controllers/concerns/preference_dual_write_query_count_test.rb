# typed: false
# frozen_string_literal: true

require "test_helper"

# A real controller class (not `Object.new.extend(...)`) is required so that
# ActiveSupport::Concern actually flushes PreferenceCore's nested
# dependencies (PreferenceBase, PreferenceResourceSync) -- see the identical
# note in preference_dbsc_retirement_test.rb.
class PreferenceDualWriteQueryCountTestController < ::ApplicationController
  include ::PreferenceCore
end

# Measures actual SQL statement counts for the full signed-in dual-write path
# (`PreferenceCore#update_preference_child_dual_write!`,
# app/controllers/concerns/preference_core.rb:286-309) using real
# ActiveSupport::Notifications instrumentation against real DB rows -- not
# estimation. This is the method a real controller action calls: it writes
# the browser-scoped child (with audit log), marks the browser side
# explicit, writes the principal-scoped mirror
# (`PreferenceResourceSync#write_resource_preference_option!`), and finally
# reloads + reissues the token. Numbers are reported in
# memos/2026-07-21-preference-lifecycle-hardening-implementation.md and
# docs/architecture/preference-behavior-contract.md.
#
# Writing this test uncovered a real, pre-existing bug: `write_resource_preference_option!`
# on app/org (not com) silently never updated the mirror's per-key child
# option row, because `resource_preference_association_prefix` guessed the
# wrong has_one association name (see the fix and comment in
# app/controllers/concerns/preference_resource_sync.rb). This test's
# assertions on the child option id (not just the flat column) are what
# caught it, and continue to guard against a regression.
class PreferenceDualWriteQueryCountTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses,
           :app_preferences, :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses

  setup do
    AppPreferenceLanguageOption.ensure_defaults!
    ClientPreferenceLanguageOption.ensure_defaults!

    @browser_pref = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      binding_method_id: AppPreferenceBindingMethod::NOTHING,
      dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
      discarded_at: 20.years.from_now,
      purged_at: 20.years.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    AppPreferenceLanguage.create!(preference: @browser_pref, option_id: AppPreferenceLanguageOption::JA)

    @user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    @resource_pref = ClientPreference.create!(user_id: @user.id)
    ClientPreferenceLanguage.create!(preference_id: @resource_pref.id, option_id: ClientPreferenceLanguageOption::JA)
  end

  test "update_preference_child_dual_write! query count and correctness for a single-key signed-in update" do
    user = @user
    ctx = PreferenceDualWriteQueryCountTestController.new
    ctx.define_singleton_method(:preference_class) { AppPreference }
    ctx.define_singleton_method(:preference_prefix) { |_p = nil| "App" }
    ctx.define_singleton_method(:current_resource) { user }
    ctx.define_singleton_method(:current_user) { user }
    ctx.define_singleton_method(:authorize!) { |*, **| true }
    ctx.define_singleton_method(:issue_access_token_from) { |_pref| nil }
    ctx.define_singleton_method(:request) { OpenStruct.new(remote_ip: "127.0.0.1") }
    ctx.instance_variable_set(:@preferences, @browser_pref)

    child = @browser_pref.app_preference_language

    statements =
      capture_sql do
        ctx.send(
          :update_preference_child_dual_write!, child,
          { option_id: AppPreferenceLanguageOption::EN }, option_type: :language,
                                                          audit_event: "UPDATE_PREFERENCE_LANGUAGE",
        )
      end

    reads = statements.count { |s| s[:sql] =~ /\A\s*SELECT/i }
    writes = statements.count { |s| s[:sql] =~ /\A\s*(UPDATE|INSERT)/i }
    browser_db = statements.count { |s| s[:sql] =~ /app_preferences|app_preference_languages/i }
    principal_db = statements.count { |s| s[:sql] =~ /client_preferences|client_preference_languages/i }
    option_lookup = statements.count { |s| s[:sql] =~ /_options\b/i }
    chronicle_db = statements.count { |s| s[:sql] =~ /chronicle|app_preference_chronicles/i }

    sqls = statements.pluck(:sql)
    duplicates = sqls.tally.select { |_sql, count| count > 1 }

    report = <<~REPORT
      Total SQL statements: #{statements.size}
      Reads: #{reads}
      Writes: #{writes}
      Browser DB statements: #{browser_db}
      Principal DB statements: #{principal_db}
      Option lookup statements: #{option_lookup}
      Chronicle/audit statements: #{chronicle_db}
      Repeated or duplicate statements: #{duplicates.size}
    REPORT
    Rails.root.join("tmp/dual_write_query_report.txt").write(
      "#{report}\n\nFull statement list:\n#{sqls.each_with_index.map { |s, i| "#{i + 1}. #{s}" }.join("\n")}" \
      "#{duplicates.any? ? "\n\nDuplicates:\n#{duplicates.map { |sql, count| "(#{count}x) #{sql}" }.join("\n")}" : ""}",
    )

    @resource_pref.reload
    @browser_pref.reload

    assert_equal AppPreferenceLanguageOption::EN, @browser_pref.app_preference_language.reload.option_id
    assert_equal ClientPreferenceLanguageOption::EN, @resource_pref.user_preference_language.reload.option_id,
                 "the mirror's per-key child option row (not just the flat column) must be updated"
    assert_equal "en", @resource_pref.reload.language
    assert @browser_pref.explicit_field?(:language), "browser side must be marked explicit"
    assert @resource_pref.explicit_field?(:language), "mirror side must be marked explicit by the dual-write"
    assert_predicate statements.size, :positive?
  end

  private

  def capture_sql
    statements = []
    subscriber =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        sql = payload[:sql].to_s
        next if payload[:name] == "SCHEMA"
        next if sql.start_with?("BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE")

        statements << { sql: sql, name: payload[:name] }
      end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
