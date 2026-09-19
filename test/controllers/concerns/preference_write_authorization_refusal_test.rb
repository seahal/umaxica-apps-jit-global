# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/preference_lifecycle_surfaces"

# A real controller class is required (not `Object.new.extend(...)`) so
# ActiveSupport::Concern flushes PreferenceCore's nested dependencies -- see the
# identical note in preference_dual_write_contract_test.rb. It inherits the
# surface application controller because the refusal under test comes from
# `authorize :user, through: :current_policy_user`, which is declared there.
class PreferenceWriteAuthorizationRefusalTestController < ::Base::App::ApplicationController
  include ::PreferenceCore
end

# Every preference write mirrors the token-scoped record into the principal-scoped
# one, and the mirror is authorized against ClientPreferencePolicy#update?, which
# only passes for the owner. This file pins what happens when it does not pass:
# the write raises PreferenceOperationError (the type the endpoints translate into
# a refusal) rather than an unhandled ActionPolicy::Unauthorized, and neither side
# of the dual write is left modified.
class PreferenceWriteAuthorizationRefusalTest < ActiveSupport::TestCase
  fixtures :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses

  setup do
    PreferenceClassRegistry.option_class("App", :language).ensure_defaults!
    @owner = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    @intruder = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    @resource_pref = ClientPreference.create!(user_id: @owner.id)
    @browser_pref = PreferenceLifecycleSurfaces.new_token_preference(:app, with_default_children: true)
    PreferenceLifecycleSurfaces.set_language!(@browser_pref, PreferenceLifecycleSurfaces::JA)
  end

  def build_context(params = {})
    ctx = PreferenceWriteAuthorizationRefusalTestController.new
    ctx.set_request!(ActionDispatch::TestRequest.create)
    ctx.request.params.merge!(params)
    owner = @owner
    intruder = @intruder
    ctx.define_singleton_method(:params) { ActionController::Parameters.new(params) }
    ctx.define_singleton_method(:current_resource) { owner }
    ctx.define_singleton_method(:current_policy_user) { intruder }
    ctx.define_singleton_method(:current_actor) { nil }
    ctx.define_singleton_method(:preference_class) { AppPreference }
    ctx.define_singleton_method(:preference_prefix) { |_p = nil| "App" }
    ctx.instance_variable_set(:@preferences, @browser_pref)
    ctx
  end

  test "an option write for someone else's mirror is refused and leaves the token record alone" do
    ctx = build_context
    child = @browser_pref.app_preference_language

    error =
      assert_raises(PreferenceOperationError) do
        ctx.send(
          :update_preference_child_dual_write!,
          child,
          { "option_id" => PreferenceLifecycleSurfaces::EN },
          option_type: :language,
          audit_event: "UPDATE_PREFERENCE_LANGUAGE",
        )
      end

    assert_kind_of PreferenceOperationError, error
    assert_equal PreferenceLifecycleSurfaces::JA, child.reload.option_id,
                 "the token-side child must not move when the mirror write is unauthorized"
  end

  test "a cookie write for someone else's mirror is refused" do
    ctx = build_context
    cookie = @browser_pref.app_preference_cookie ||
      @browser_pref.create_app_preference_cookie!(functional: false, performant: false, targetable: false)

    assert_raises(PreferenceOperationError) do
      ctx.send(
        :update_preference_cookie_dual_write!,
        cookie,
        { "functional" => true },
        audit_event: "UPDATE_PREFERENCE_COOKIE",
      )
    end

    assert_not cookie.reload.functional, "the token-side cookie must not move when the mirror write is unauthorized"
  end

  test "a rebootstrap reset for someone else's mirror is refused before anything is retired" do
    ctx = build_context

    assert_raises(PreferenceOperationError) { ctx.send(:reset_preference_by_rebootstrap!) }

    assert_nil @browser_pref.reload.retired_at if @browser_pref.respond_to?(:retired_at)

    assert ClientPreference.exists?(@resource_pref.id), "the mirror must survive an unauthorized reset"
  end

  test "the region and regional-defaults write for someone else's mirror is refused" do
    PreferenceClassRegistry.option_class("App", :currency).ensure_defaults!
    PreferenceClassRegistry.option_class("App", :date_format).ensure_defaults!
    PreferenceClassRegistry.option_class("App", :time_format).ensure_defaults!
    PreferenceClassRegistry.option_class("App", :region).ensure_defaults!
    currency = @browser_pref.app_preference_currency ||
      @browser_pref.create_app_preference_currency!(option_id: AppPreferenceCurrencyOption::JPY)
    date_format = @browser_pref.app_preference_date_format ||
      @browser_pref.create_app_preference_date_format!(option_id: AppPreferenceDateFormatOption::ISO)
    time_format = @browser_pref.app_preference_time_format ||
      @browser_pref.create_app_preference_time_format!(option_id: AppPreferenceTimeFormatOption::HOUR_24)
    ctx = build_context(preference_region: { option_id: PreferenceClassRegistry.option_class("App", :region)::US.to_s })
    ctx.instance_variable_set(:@preference_region, @browser_pref.app_preference_region)
    ctx.instance_variable_set(:@preference_language, @browser_pref.app_preference_language)
    ctx.instance_variable_set(:@preference_currency, currency)
    ctx.instance_variable_set(:@preference_date_format, date_format)
    ctx.instance_variable_set(:@preference_time_format, time_format)

    assert_raises(PreferenceOperationError) { ctx.send(:update_region_and_regional_defaults!) }

    assert_equal PreferenceLifecycleSurfaces::JA, @browser_pref.app_preference_language.reload.option_id
    assert_equal AppPreferenceCurrencyOption::JPY, currency.reload.option_id
  end
end
