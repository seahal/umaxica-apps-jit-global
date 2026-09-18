# typed: false
# frozen_string_literal: true

module PreferenceAdoption
  extend ActiveSupport::Concern

  CHILD_RECORD_TYPES = PreferenceClassRegistry::CHILD_RECORD_TYPES
  COOKIE_CONSENT_FIELDS = %i(consented functional performant targetable).freeze

  private

  # Called after login to sync preferences between AppPreference/OrgPreference
  # and ClientPreference/OperatorPreference. Uses updated_at to determine which is newer.
  # Non-fatal: never blocks login on failure.
  def adopt_preference_for!(resource)
    return unless adoptable_preference_class?
    return if resource.blank? || @preferences.blank?

    resource_pref = find_or_create_resource_preference!(resource)
    return if resource_pref.blank?

    sync_preferences!(resource_pref)
  rescue StandardError => e
    Rails.logger.info(JitLogEvent.format("preference.adoption.error", error: e.class.name, message: e.message))
  end

  # Called during preference rotation to keep ClientPreference/OperatorPreference in sync.
  # Non-fatal: never blocks rotation on failure.
  def adopt_rotated_preference!(resource, new_preference)
    return unless adoptable_preference_class?
    return if resource.blank? || new_preference.blank?

    @preferences = new_preference
    resource_pref = find_resource_preference(resource)
    return if resource_pref.blank?

    copy_preference_values!(@preferences, resource_pref, resource_pref_prefix)
  rescue StandardError => e
    Rails.logger.info(
      JitLogEvent.format(
        "preference.adoption.rotation_error", error: e.class.name,
                                              message: e.message,
      ),
    )
  end

  def adoptable_preference_class?
    name = preference_class.name
    name == "AppPreference" || name == "OrgPreference" || name == "ComPreference"
  end

  # Find or create the 1:1 ClientPreference/OperatorPreference/VisitorPreference for this resource.
  def find_or_create_resource_preference!(resource)
    pref = find_resource_preference(resource)
    return pref if pref.present?

    create_resource_preference!(resource)
  end

  def find_resource_preference(resource)
    with_preference_writing_connection(resource) do
      case preference_class.name
      when "AppPreference"
        resource.user_preference
      when "OrgPreference"
        resource.staff_preference
      when "ComPreference"
        resource.visitor_preference
      end
    end
  end

  def create_resource_preference!(resource)
    pref_class, fk = resource_preference_mapping
    return nil unless pref_class

    pref = nil
    with_preference_writing_connection(pref_class) do
      pref = pref_class.create!(fk => resource.id)
      create_resource_preference_options!(pref)
    end
    pref
  end

  def create_resource_preference_options!(resource_pref)
    prefix = resource_pref_prefix
    CHILD_RECORD_TYPES.each do |type|
      PreferenceClassRegistry.option_class(prefix, type).ensure_defaults!
      PreferenceClassRegistry.record_class(prefix, type).create!(
        preference: resource_pref,
        option_id: PreferenceClassRegistry.default_option_id(prefix, type),
      )
    end
  end

  # Per-key sign-in reconciliation (target semantics: explicit user intent wins
  # over an unmarked/auto-seeded default; a whole-record `updated_at` winner no
  # longer decides the fate of unrelated keys). Each of CHILD_RECORD_TYPES is
  # resolved independently using `explicit_fields` as the authority:
  #
  #   principal legacy (explicit_fields IS NULL) -> principal always wins,
  #                                        regardless of browser state. A row
  #                                        that predates the explicit_fields
  #                                        column has unknowable history; a
  #                                        browser-side explicit marker must
  #                                        not be allowed to overwrite an
  #                                        established value just because its
  #                                        own provenance happens to be known
  #                                        (see PreferenceExplicitFields).
  #   browser explicit,  principal not  -> browser wins
  #   principal explicit, browser not   -> principal wins
  #   both explicit                     -> more recently touched *child*
  #                                        record wins (best-effort per-key
  #                                        LWW on a low-sensitivity display
  #                                        value, not a strict causal order);
  #                                        tie -> principal
  #   neither explicit                  -> principal (unchanged default
  #                                        behavior for accounts with no
  #                                        divergent browser edit)
  #
  # The losing side is updated to match the winner's value *and* its explicit
  # flag, so both records converge to the same value and the same explicit
  # state (never marking a side explicit for a value it never chose). The
  # legacy branch is the one exception: the principal side is never written
  # to by this method while legacy, so it stays legacy until a genuine user
  # action on that account (mark_field_explicit!/dual-write) transitions it.
  def sync_preferences!(resource_pref)
    CHILD_RECORD_TYPES.each { |type| reconcile_preference_key!(resource_pref, type) }
    reconcile_flat_preference_values!(resource_pref)
    reconcile_cookie_consent!(resource_pref)

    force_underage_r18_stopper!(resource_pref)
    issue_access_token_from(@preferences)
  end

  def reconcile_preference_key!(resource_pref, type)
    browser_child = preference_child_for(@preferences, type, preference_prefix)
    principal_child = preference_child_for(resource_pref, type, resource_pref_prefix)
    return if browser_child.blank? && principal_child.blank?

    principal_legacy = preference_legacy_unknown?(resource_pref)
    browser_explicit = explicit_field_on?(@preferences, type)
    principal_explicit = !principal_legacy && explicit_field_on?(resource_pref, type)

    winner =
      if !principal_legacy && browser_explicit && !principal_explicit
        :browser
      elsif !principal_legacy && browser_explicit && principal_explicit
        key_recency_winner(browser_child, principal_child)
      else
        # Covers "principal legacy" (protect unknown-provenance value from
        # any browser marker), "principal explicit, browser not", and
        # "neither explicit" -- all fall through to the principal per target
        # semantics section 6.3 and section 2's legacy-compatibility rule.
        :principal
      end

    case winner
    when :browser
      return if browser_child.blank?

      copy_single_child!(
        @preferences, resource_pref, resource_pref_prefix, type,
        source_child: browser_child, mark_explicit: browser_explicit,
      )
    when :principal
      return if principal_child.blank?

      copy_single_child!(
        resource_pref, @preferences, preference_prefix, type,
        source_child: principal_child, mark_explicit: principal_explicit,
      )
    end
  end

  def explicit_field_on?(preference, type)
    preference.respond_to?(:explicit_field?) && preference.explicit_field?(type)
  end

  def preference_legacy_unknown?(preference)
    preference.respond_to?(:legacy_unknown_explicit_state?) && preference.legacy_unknown_explicit_state?
  end

  def key_recency_winner(browser_child, principal_child)
    browser_updated = browser_child&.updated_at
    principal_updated = principal_child&.updated_at
    return :principal if principal_updated.blank?
    return :browser if browser_updated.present? && browser_updated > principal_updated

    :principal
  end

  def preference_child_for(preference, type, _prefix)
    return if preference.blank?

    association_prefix = preference_child_association_prefix(preference)
    return unless preference.respond_to?("#{association_prefix}_#{type}")

    with_preference_writing_connection(preference) { preference.public_send("#{association_prefix}_#{type}") }
  end

  # Copy a single child record's option_id from source to target, creating the
  # target child (with defaults) if it does not exist yet, then align both
  # sides' explicit-state for this key so a subsequent sync is a no-op.
  def copy_single_child!(_source, target, target_prefix, type, source_child:, mark_explicit:)
    return if source_child.blank? || source_child.option_id.blank?

    target_assoc = preference_child_association_prefix(target)
    return unless target.respond_to?("#{target_assoc}_#{type}") || target.respond_to?("create_#{target_assoc}_#{type}!")

    target_child = with_preference_writing_connection(target) { target.public_send("#{target_assoc}_#{type}") } ||
      begin
        option_class = PreferenceClassRegistry.option_class(target_prefix, type)
        with_preference_writing_connection(option_class) { option_class.ensure_defaults! }
        with_preference_writing_connection(target) do
          target.public_send(
            "create_#{target_assoc}_#{type}!",
            option_id: PreferenceClassRegistry.default_option_id(target_prefix, type),
          )
        end
      end

    if target_child.option_id != source_child.option_id
      target_option_class = PreferenceClassRegistry.option_class(target_prefix, type)
      resolved_id = resolve_cross_db_option_id(source_child, target_option_class)
      if resolved_id
        connection_class = preference_connection_class(target)
        if connection_class
          connection_class.connected_to(role: :writing) { target_child.update!(option_id: resolved_id) }
        else
          target_child.update!(option_id: resolved_id)
        end
      end
    end

    sync_explicit_state!(target, type, mark_explicit)
  end

  def sync_explicit_state!(preference, type, explicit)
    return unless preference.respond_to?(:mark_field_explicit!) && preference.respond_to?(:explicit_field?)
    return if preference.explicit_field?(type) == explicit

    with_preference_writing_connection(preference) do
      if explicit
        preference.mark_field_explicit!(type)
      else
        preference.update!(explicit_fields: preference.explicit_field_names - [type.to_s])
      end
    end
  end

  # Flat columns (language/region/timezone/theme mirrored as plain strings on
  # ClientPreference/OperatorPreference/VisitorPreference) follow the same
  # per-key child-record winner computed above, so they are re-derived from
  # whichever side just won rather than compared on their own timestamp.
  def reconcile_flat_preference_values!(resource_pref)
    return unless resource_pref.respond_to?(:language=)

    # `adult_content_gate` is never a real flat column on either side (both
    # AppPreference and ClientPreference/OperatorPreference/VisitorPreference
    # expose it as a read-only method backed by the child association); it is
    # already reconciled per-key above and must not be mass-assigned here.
    snapshot = preference_snapshot_for(resource_pref).except(:adult_content_gate)
    return if snapshot.blank?

    connection_class = preference_connection_class(resource_pref)
    if connection_class
      connection_class.connected_to(role: :writing) { resource_pref.update!(snapshot) }
    else
      resource_pref.update!(snapshot)
    end
  end

  # Cookie consent is not a display preference: it is not covered by
  # `explicit_fields`/CHILD_RECORD_TYPES and is intentionally excluded from
  # the per-key display-preference merge above. Whichever side has the more
  # recently recorded `consented_at` wins; a side with no recorded consent
  # never overwrites a side that has one.
  def reconcile_cookie_consent!(resource_pref)
    browser_consent = preference_consent_snapshot(@preferences)
    principal_consent = preference_consent_snapshot(resource_pref)
    return if browser_consent.blank? && principal_consent.blank?

    browser_at = browser_consent&.dig(:consented_at)
    principal_at = principal_consent&.dig(:consented_at)

    if browser_at.present? && (principal_at.blank? || browser_at > principal_at)
      apply_consent_snapshot!(resource_pref, browser_consent)
    elsif principal_at.present?
      apply_consent_snapshot!(@preferences, principal_consent)
    end
  end

  def preference_consent_snapshot(preference)
    return if preference.blank?

    if preference.respond_to?(:consented)
      COOKIE_CONSENT_FIELDS.index_with { |f| preference.public_send(f) }.merge(consented_at: preference.consented_at)
    else
      assoc_name = "#{preference.class.name.underscore}_cookie"
      return unless preference.respond_to?(assoc_name)

      cookie = with_preference_writing_connection(preference) { preference.public_send(assoc_name) }
      return if cookie.blank?

      COOKIE_CONSENT_FIELDS.index_with { |f| cookie.public_send(f) }.merge(consented_at: cookie.consented_at)
    end
  end

  def apply_consent_snapshot!(target, snapshot)
    if target.respond_to?(:consented)
      connection_class = preference_connection_class(target)
      connection_class ? connection_class.connected_to(role: :writing) {
        target.update!(snapshot)
      } : target.update!(snapshot)
      return
    end

    assoc_name = "#{target.class.name.underscore}_cookie"
    return unless target.respond_to?(assoc_name)

    cookie = with_preference_writing_connection(target) { target.public_send(assoc_name) } ||
      with_preference_writing_connection(target) { target.public_send("create_#{assoc_name}!") }
    connection_class = preference_connection_class(target)
    connection_class ? connection_class.connected_to(role: :writing) {
      cookie.update!(snapshot)
    } : cookie.update!(snapshot)
  end

  # Copy child record option_ids and cookie consent from source to target.
  def copy_preference_values!(source, target, target_prefix)
    source_assoc = preference_child_association_prefix(source)
    target_assoc = preference_child_association_prefix(target)

    CHILD_RECORD_TYPES.each do |type|
      next unless source.respond_to?("#{source_assoc}_#{type}")

      source_child = with_preference_writing_connection(source) { source.public_send("#{source_assoc}_#{type}") }
      next unless source_child&.option_id
      next unless target.respond_to?("#{target_assoc}_#{type}") ||
        target.respond_to?("create_#{target_assoc}_#{type}!")

      target_child = with_preference_writing_connection(target) { target.public_send("#{target_assoc}_#{type}") } ||
        begin
          option_class = PreferenceClassRegistry.option_class(target_prefix, type)
          with_preference_writing_connection(option_class) { option_class.ensure_defaults! }
          with_preference_writing_connection(target) do
            target.public_send(
              "create_#{target_assoc}_#{type}!",
              option_id: PreferenceClassRegistry.default_option_id(target_prefix, type),
            )
          end
        end

      if target_child.option_id != source_child.option_id
        target_option_class = PreferenceClassRegistry.option_class(target_prefix, type)
        # Map option by name since option IDs may differ across databases
        resolved_id = resolve_cross_db_option_id(source_child, target_option_class)
        next unless resolved_id

        connection_class = preference_connection_class(target)
        if connection_class
          connection_class.connected_to(role: :writing) { target_child.update!(option_id: resolved_id) }
        else
          target_child.update!(option_id: resolved_id)
        end
      end
    end

    copy_flat_preference_values!(source, target)
    copy_cookie_consent!(source, target, source_assoc, target_assoc)
    touch_target!(target)
  end

  def force_underage_r18_stopper!(resource_pref)
    resource = preference_resource_for(resource_pref)
    return unless resource&.respond_to?(:birthdate)
    return if AgeEligibility.minimum_age_reached?(resource.birthdate, minimum_age: 18, today: Time.zone.today)

    force_r18_stopper_child!(@preferences, preference_prefix)
    force_r18_stopper_child!(resource_pref, resource_pref_prefix)
  end

  def force_r18_stopper_child!(preference, prefix)
    association_prefix = preference_child_association_prefix(preference)
    record_class = PreferenceClassRegistry.record_class(prefix, :adult_content_gate)
    option_class = PreferenceClassRegistry.option_class(prefix, :adult_content_gate)
    with_preference_writing_connection(option_class) { option_class.ensure_defaults! }
    denied_id = option_class::DENY

    child =
      with_preference_writing_connection(preference) do
        preference.public_send(r18_stopper_association_name(preference, association_prefix))
      end

    if child
      with_preference_writing_connection(child) { child.update!(option_id: denied_id) }
    else
      with_preference_writing_connection(record_class) do
        record_class.create!(preference: preference, option_id: denied_id)
      end
    end
  end

  def preference_resource_for(resource_pref)
    case resource_pref
    when ClientPreference then resource_pref.user
    when OperatorPreference then resource_pref.staff
    when VisitorPreference then resource_pref.visitor
    end
  end

  def r18_stopper_association_name(preference, association_prefix)
    prefixed = "#{association_prefix}_adult_content_gate"
    return prefixed if preference.respond_to?(prefixed)

    "#{preference.class.name.underscore}_adult_content_gate"
  end

  def resolve_cross_db_option_id(source_child, target_option_class)
    source_option = with_preference_writing_connection(source_child) { source_child.option }
    return source_child.option_id if source_option.blank?

    source_name = source_option.name
    return source_child.option_id if source_name.blank?

    with_preference_writing_connection(target_option_class) do
      target_option_class.find_each do |opt|
        return opt.id if opt.name&.downcase == source_name.downcase
      end
    end
    nil
  end

  def copy_cookie_consent!(source, target, _source_assoc, _target_assoc)
    if source.respond_to?(:consented)
      # Source is ClientPreference/OperatorPreference (direct columns)
      source_consent = COOKIE_CONSENT_FIELDS.index_with { |f| source.public_send(f) }
    else
      source_assoc_name = source.class.name.underscore
      source_cookie = with_preference_writing_connection(source) { source.public_send("#{source_assoc_name}_cookie") }
      return unless source_cookie

      source_consent = COOKIE_CONSENT_FIELDS.index_with { |f| source_cookie.public_send(f) }
    end

    if target.respond_to?(:consented)
      # Target is ClientPreference/OperatorPreference (direct columns)
      connection_class = preference_connection_class(target)
      if connection_class
        connection_class.connected_to(role: :writing) { target.update!(source_consent) }
      else
        target.update!(source_consent)
      end
    else
      target_assoc_name = target.class.name.underscore
      target_cookie = with_preference_writing_connection(target) {
        target.public_send("#{target_assoc_name}_cookie")
      } ||
        with_preference_writing_connection(target) { target.public_send("create_#{target_assoc_name}_cookie!") }
      connection_class = preference_connection_class(target)
      if connection_class
        connection_class.connected_to(role: :writing) { target_cookie.update!(source_consent) }
      else
        target_cookie.update!(source_consent)
      end
    end
  end

  def copy_flat_preference_values!(source, target)
    return unless target.respond_to?(:language=)

    snapshot = preference_snapshot_for(source)
    return if snapshot.blank?

    connection_class = preference_connection_class(target)
    if connection_class
      connection_class.connected_to(role: :writing) { target.update!(snapshot) }
    else
      target.update!(snapshot)
    end
  end

  def preference_snapshot_for(preference)
    return if preference.blank?

    if local_preference_snapshot_source?(preference)
      return CHILD_RECORD_TYPES.each_with_object({}) do |type, snapshot|
        next unless preference.respond_to?(type)

        snapshot[type] = preference.public_send(type)
      end.compact
    end

    association_prefix = preference.class.name.underscore

    CHILD_RECORD_TYPES.each_with_object({}) do |type, snapshot|
      child =
        with_preference_writing_connection(preference) {
          preference.public_send("#{association_prefix}_#{type}")
        }
      value = with_preference_writing_connection(child) { child&.option&.name }
      value = value&.downcase if %i(language region currency).include?(type)
      value = preference_theme_short_code(value) if type == :theme
      snapshot[type] = value if value.present?
    end
  end

  def local_preference_snapshot_source?(preference)
    preference.respond_to?(:language) &&
      preference.respond_to?(:region) &&
      preference.respond_to?(:timezone) &&
      preference.respond_to?(:theme)
  end

  def preference_theme_short_code(value)
    case value.to_s.downcase
    when "light", "li"
      "li"
    when "dark", "dr"
      "dr"
    when "system", "sy"
      "sy"
    end
  end

  def touch_target!(target)
    connection_class = preference_connection_class(target)
    if connection_class
      connection_class.connected_to(role: :writing) { target.update!(updated_at: Time.current) }
    else
      target.update!(updated_at: Time.current)
    end
  end

  def resource_preference_mapping
    case preference_class.name
    when "AppPreference"
      [ClientPreference, :user_id]
    when "OrgPreference"
      [OperatorPreference, :staff_id]
    when "ComPreference"
      [VisitorPreference, :visitor_id]
    else
      [nil, nil]
    end
  end

  def resource_pref_prefix
    case preference_class.name
    when "AppPreference" then "Client"
    when "OrgPreference" then "Operator"
    when "ComPreference" then "Visitor"
    end
  end

  def preference_child_association_prefix(preference)
    case preference
    when ClientPreference
      "user_preference"
    when OperatorPreference
      "staff_preference"
    when VisitorPreference
      "visitor_preference"
    else
      preference.class.name.underscore
    end
  end

  def with_preference_writing_connection(record_or_class)
    return yield if record_or_class.blank?

    connection_class = preference_connection_class(record_or_class)
    return yield unless connection_class

    connection_class.connected_to(role: :writing) { yield }
  end

  def preference_connection_class(record_or_class)
    klass = record_or_class.is_a?(Class) ? record_or_class : record_or_class.class
    # Only Active Record classes own a connection; plain objects are written directly.
    klass.connection_class_for_self if klass < ActiveRecord::Base
  end
end
