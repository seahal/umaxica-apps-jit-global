# typed: false
# frozen_string_literal: true

# Shared per-surface adapter for Preference lifecycle contract tests.
#
# Per app/com/org test-parity policy (see
# memos/2026-07-21-preference-lifecycle-hardening-implementation.md), the
# behavioral assertions in preference_sign_out_rotation_contract_test.rb,
# preference_sign_up_initialization_test.rb, etc. must be shared code
# exercised once per surface -- not three copy-pasted test files. This file
# is the "small per-surface adapter" the shared assertions run against: it
# supplies the class/constant that differs (AppPreference vs. ComPreference
# vs. OrgPreference, ClientPreference vs. VisitorPreference vs.
# OperatorPreference, ...), never the assertions themselves.
#
# LanguageOption::JA == 1 / ::EN == 2 and ThemeOption::LIGHT == 1 /
# ::DARK == 2 / ::SYSTEM == 3 agree across every token-scoped and
# principal-scoped preference model in this repository (verified by reading
# app_preference_language_option.rb, org_preference_language_option.rb,
# com_preference_language_option.rb, client_preference_language_option.rb,
# operator_preference_language_option.rb, visitor_preference_language_option.rb,
# and the *_theme_option.rb equivalents), so a single shared id pair is used
# below rather than per-surface constants.
module PreferenceLifecycleSurfaces
  JA = 1
  EN = 2
  LIGHT = 1
  DARK = 2
  SYSTEM = 3

  SURFACES = {
    app: {
      preference_class: -> { AppPreference },
      status_class: -> { AppPreferenceStatus },
      binding_class: -> { AppPreferenceBindingMethod },
      dbsc_class: -> { AppPreferenceDbscStatus },
      resource_fixture: -> { Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER) },
      resource_pref_class: -> { ClientPreference },
      resource_fk: :user_id,
      resource_language_assoc: "user_preference_language",
      resource_theme_assoc: "user_preference_theme",
    },
    org: {
      preference_class: -> { OrgPreference },
      status_class: -> { OrgPreferenceStatus },
      binding_class: -> { OrgPreferenceBindingMethod },
      dbsc_class: -> { OrgPreferenceDbscStatus },
      resource_fixture: -> { Operator.create!(status_id: OperatorStatus::NOTHING) },
      resource_pref_class: -> { OperatorPreference },
      resource_fk: :staff_id,
      resource_language_assoc: "staff_preference_language",
      resource_theme_assoc: "staff_preference_theme",
    },
    com: {
      preference_class: -> { ComPreference },
      status_class: -> { ComPreferenceStatus },
      binding_class: -> { ComPreferenceBindingMethod },
      dbsc_class: -> { ComPreferenceDbscStatus },
      resource_fixture: -> { Visitor.create!(status_id: VisitorStatus::NOTHING) },
      resource_pref_class: -> { VisitorPreference },
      resource_fk: :visitor_id,
      resource_language_assoc: "visitor_preference_language",
      resource_theme_assoc: "visitor_preference_theme",
    },
  }.freeze

  module_function

  def config(surface)
    SURFACES.fetch(surface)
  end

  def new_token_preference(surface, with_default_children: false)
    cfg = config(surface)
    pref = cfg[:preference_class].call.create!(
      status_id: cfg[:status_class].call::NOTHING,
      binding_method_id: cfg[:binding_class].call::NOTHING,
      dbsc_status_id: cfg[:dbsc_class].call::NOTHING,
      discard_at: 20.years.from_now,
      purge_eligible_at: 20.years.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    create_default_children!(pref) if with_default_children
    pref
  end

  # Mirrors what the real PreferenceRefreshTokenTransport#persist_new_preference_record!
  # does (create every CHILD_RECORD_TYPES default), scoped to the two types
  # the shared contract tests actually assert on.
  def create_default_children!(preference)
    prefix = preference.class.name.gsub("Preference", "")
    %i(language theme).each do |type|
      option_class = PreferenceClassRegistry.option_class(prefix, type)
      option_class.ensure_defaults!
      record_class = PreferenceClassRegistry.record_class(prefix, type)
      record_class.create!(preference: preference, option_id: PreferenceClassRegistry.default_option_id(prefix, type))
    end
  end

  def language_association(preference)
    "#{preference.class.name.underscore}_language"
  end

  def theme_association(preference)
    "#{preference.class.name.underscore}_theme"
  end

  def set_language!(preference, option_id)
    assoc = language_association(preference)
    child = preference.public_send(assoc) || preference.public_send("create_#{assoc}!", option_id: option_id)
    child.update!(option_id: option_id)
    child
  end

  def set_theme!(preference, option_id)
    assoc = theme_association(preference)
    child = preference.public_send(assoc) || preference.public_send("create_#{assoc}!", option_id: option_id)
    child.update!(option_id: option_id)
    child
  end
end
