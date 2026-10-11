# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/preference_lifecycle_surfaces"

# Shared app/com/org contract for PreferenceAdoption#sync_preferences! (the
# sign-in per-key reconciler). One set of assertions executed once per
# surface via PreferenceLifecycleSurfaces -- see
# preference_sign_out_rotation_contract_test.rb for the same pattern.
class PreferenceSignInReconciliationContractTest < ActiveSupport::TestCase
  fixtures :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses,
           :org_preference_statuses, :org_preference_binding_methods, :org_preference_dbsc_statuses,
           :com_preference_statuses, :com_preference_binding_methods, :com_preference_dbsc_statuses

  PreferenceLifecycleSurfaces::SURFACES.each_key do |surface|
    test "#{surface}: per-key -- an unrelated principal-explicit key is not clobbered by a browser-wins key" do
      cfg = PreferenceLifecycleSurfaces.config(surface)
      browser_pref = PreferenceLifecycleSurfaces.new_token_preference(surface, with_default_children: true)
      PreferenceLifecycleSurfaces.set_language!(browser_pref, PreferenceLifecycleSurfaces::EN)
      browser_pref.mark_field_explicit!(:language)

      resource_pref = create_resource_preference(cfg)
      resource_theme_child =
        set_resource_child!(resource_pref, cfg[:resource_theme_assoc], PreferenceLifecycleSurfaces::DARK)
      resource_pref.mark_field_explicit!(:theme)

      sync!(surface, browser_pref, resource_pref)

      resource_pref.reload
      resource_theme_child.reload

      assert_equal PreferenceLifecycleSurfaces::EN,
                   resource_pref.public_send(cfg[:resource_language_assoc]).reload.option_id,
                   "#{surface}: browser-explicit language must win"
      assert_equal PreferenceLifecycleSurfaces::DARK, resource_theme_child.option_id,
                   "#{surface}: unrelated principal-explicit theme must be untouched"
    end

    test "#{surface}: legacy (explicit_fields IS NULL) principal is never overwritten by a browser-explicit marker" do
      cfg = PreferenceLifecycleSurfaces.config(surface)
      browser_pref = PreferenceLifecycleSurfaces.new_token_preference(surface, with_default_children: true)
      PreferenceLifecycleSurfaces.set_language!(browser_pref, PreferenceLifecycleSurfaces::EN)
      browser_pref.mark_field_explicit!(:language)

      resource_pref = create_resource_preference(cfg)
      principal_owner(surface).connected_to(role: :writing) { resource_pref.update_column(:explicit_fields, nil) }
      resource_pref.reload

      assert_predicate resource_pref, :legacy_unknown_explicit_state?

      sync!(surface, browser_pref, resource_pref)

      resource_pref.reload

      assert_equal PreferenceLifecycleSurfaces::JA,
                   resource_pref.public_send(cfg[:resource_language_assoc]).reload.option_id,
                   "#{surface}: legacy principal value must never be overwritten merely because the browser is explicit"
      assert_predicate resource_pref, :legacy_unknown_explicit_state?,
                       "#{surface}: sync must not write to the principal while it stays legacy"
    end

    test "#{surface}: browser and principal converge to the same value and explicit state after reconciliation" do
      cfg = PreferenceLifecycleSurfaces.config(surface)
      browser_pref = PreferenceLifecycleSurfaces.new_token_preference(surface, with_default_children: true)
      PreferenceLifecycleSurfaces.set_language!(browser_pref, PreferenceLifecycleSurfaces::EN)
      browser_pref.mark_field_explicit!(:language)

      resource_pref = create_resource_preference(cfg)

      sync!(surface, browser_pref, resource_pref)

      resource_pref.reload
      browser_pref.reload

      resource_option_id = resource_pref.public_send(cfg[:resource_language_assoc]).reload.option_id
      browser_option_id = browser_pref.public_send(
        PreferenceLifecycleSurfaces.language_association(browser_pref),
      ).option_id

      assert_equal browser_option_id, resource_option_id, "#{surface}: both sides must converge to the same value"
      assert_equal browser_pref.explicit_field?(:language), resource_pref.explicit_field?(:language),
                   "#{surface}: both sides must converge to the same explicit state"
    end
  end

  private

  def principal_owner(surface)
    case surface
    when :app then AppZenithRecord
    when :org then OrgZenithRecord
    when :com then ComZenithRecord
    end
  end

  def create_resource_preference(cfg)
    ensure_resource_option_defaults!(cfg)
    resource = cfg[:resource_fixture].call
    pref = cfg[:resource_pref_class].call.create!(cfg[:resource_fk] => resource.id)
    set_resource_child!(pref, cfg[:resource_language_assoc], PreferenceLifecycleSurfaces::JA)
    pref
  end

  def ensure_resource_option_defaults!(cfg)
    resource_prefix = cfg[:resource_pref_class].call.name.gsub("Preference", "")
    %i(language theme).each { |type| PreferenceClassRegistry.option_class(resource_prefix, type).ensure_defaults! }
  end

  def set_resource_child!(resource_pref, assoc_name, option_id)
    create_name = "create_#{assoc_name}!"
    child = resource_pref.public_send(assoc_name) || resource_pref.public_send(create_name, option_id: option_id)
    child.update!(option_id: option_id)
    child
  end

  def sync!(surface, browser_pref, resource_pref)
    cfg = PreferenceLifecycleSurfaces.config(surface)
    ctx = Object.new
    ctx.extend(PreferenceAdoption)
    ctx.define_singleton_method(:preference_class) { cfg[:preference_class].call }
    ctx.define_singleton_method(:preference_prefix) { |_p = nil|
      cfg[:preference_class].call.name.gsub("Preference", "")
    }
    ctx.define_singleton_method(:issue_access_token_from) { |_pref| nil }
    ctx.instance_variable_set(:@preferences, browser_pref)
    ctx.send(:sync_preferences!, resource_pref)
  end
end
