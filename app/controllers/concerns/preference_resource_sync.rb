# typed: false
# frozen_string_literal: true

module PreferenceResourceSync
  extend ActiveSupport::Concern

  private

  # Dual-write: when logged in, sync current AppPreference/ComPreference/OrgPreference
  # values to the corresponding ClientPreference/VisitorPreference/OperatorPreference.
  # Both direct columns and child option records are propagated so the resource
  # preference is a complete mirror of the token preference.
  def sync_to_resource_preference!
    return unless respond_to?(:current_resource, true)

    resource = preference_current_resource
    return if resource.blank?

    resource_pref = preference_write_resource_preference!(resource)
    return if resource_pref.blank?

    authorize!(resource_pref, to: :update?) if respond_to?(:authorize!, true)
    sync_direct_resource_preference!(resource_pref)
    sync_resource_preference_children!(resource_pref)
  rescue PreferenceBase::ResolutionError
    raise
  rescue StandardError => e
    # Surface mirror-sync failures instead of swallowing them. A failed resource
    # write leaves the token (source) and resource (mirror) out of sync, so the
    # caller must treat the whole preference operation as failed rather than
    # silently logging and returning success.
    Rails.logger.warn(
      JitLogEvent.format(
        "preference.sync_to_resource.error", error: e.class.name,
                                             message: e.message,
      ),
    )
    raise PreferenceOperationError
  end

  def sync_resource_preference_children!(resource_pref)
    return unless respond_to?(:copy_preference_values!, true)

    target_prefix = resource_preference_registry_prefix(resource_pref)
    copy_preference_values!(@preferences, resource_pref, target_prefix)
  end

  def preference_write_resource_preference!(resource = nil)
    resource ||= preference_current_resource if respond_to?(:current_resource, true)
    return if resource.blank?

    case preference_class.name
    when "AppPreference"
      resource.user_preference || create_resource_preference_for_write!(ClientPreference, :user_id, resource.id)
    when "OrgPreference"
      resource.staff_preference || create_resource_preference_for_write!(OperatorPreference, :staff_id, resource.id)
    when "ComPreference"
      resource.visitor_preference || create_resource_preference_for_write!(
        VisitorPreference, :visitor_id,
        resource.id,
      )
    end
  end

  def create_resource_preference_for_write!(preference_model, foreign_key, resource_id)
    connection_class = preference_connection_class(preference_model)
    preference = nil

    connection_class.connected_to(role: :writing) do
      preference = preference_model.create!(foreign_key => resource_id)
      create_resource_preference_children_for_write!(preference)
    end

    preference
  end

  def create_resource_preference_children_for_write!(resource_pref)
    prefix = resource_preference_registry_prefix(resource_pref)
    PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
      PreferenceClassRegistry.option_class(prefix, type).ensure_defaults!
      PreferenceClassRegistry.record_class(prefix, type).create!(
        preference: resource_pref,
        option_id: PreferenceClassRegistry.default_option_id(prefix, type),
      )
    end
  end

  def authorize_resource_preference_write!(resource_pref)
    authorize!(resource_pref, to: :update?) if resource_pref.present? && respond_to?(:authorize!, true)
  end

  def write_resource_preference_option!(resource_pref, type, shared_option_id)
    return if resource_pref.blank? || shared_option_id.blank?

    type = PreferenceClassRegistry::TYPE_KEY_MAP.fetch(type, type).to_sym
    resource_prefix = resource_preference_registry_prefix(resource_pref)
    direct_value = resource_preference_value_for_option(preference_prefix, type, shared_option_id)
    resource_option_id = mapped_resource_option_id(resource_prefix, type, shared_option_id)
    direct_value = resource_preference_value_for_option(
      resource_prefix, type,
      resource_option_id,
    ) if resource_option_id.present?
    return if resource_option_id.blank? && direct_value.blank?

    attrs = {}
    attrs[type] = direct_value if direct_value.present? && resource_pref.respond_to?(:"#{type}=")

    with_resource_preference_writing_connection(resource_pref) do
      if resource_option_id.present?
        child = load_or_create_resource_preference_child!(resource_pref, resource_prefix, type)
        child&.update!(option_id: resource_option_id)
      end
      resource_pref.update!(attrs.slice(*resource_pref.attribute_names.map(&:to_sym)))
      # Dual-write must land the same explicit state on both sides (target
      # semantics section 6.5): the token side was just marked explicit for `type`
      # by the caller (preference_core.rb#mark_preference_field_explicit!),
      # so the mirror must record the same explicit choice, not silently stay
      # "auto-seeded" forever.
      resource_pref.mark_field_explicit!(type) if resource_pref.respond_to?(:mark_field_explicit!)
    end
  end

  def write_resource_preference_cookie!(resource_pref, attrs)
    return if resource_pref.blank? || attrs.blank?

    allowed = attrs.to_h.with_indifferent_access.slice(
      :consented, :functional, :performant, :targetable, :consented_at,
    )
    return if allowed.blank?

    with_resource_preference_writing_connection(resource_pref) do
      resource_pref.update!(allowed)
    end
  end

  def reset_resource_preference_defaults_for_write!(resource_pref)
    return if resource_pref.blank?

    resource_prefix = resource_preference_registry_prefix(resource_pref)
    association_prefix = resource_preference_association_prefix(resource_pref)

    with_resource_preference_writing_connection(resource_pref) do
      PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
        PreferenceClassRegistry.option_class(resource_prefix, type).ensure_defaults!
        default_id = PreferenceClassRegistry.default_option_id(resource_prefix, type)
        association_name = "#{association_prefix}_#{type}"
        child = resource_pref.public_send(association_name) if resource_pref.respond_to?(association_name)
        child ||= load_or_create_resource_preference_child!(resource_pref, resource_prefix, type)
        child&.update!(option_id: default_id) if child.blank? || child.option_id != default_id

        direct_value = resource_preference_value_for_option(resource_prefix, type, default_id)
        resource_pref.public_send(
          :"#{type}=",
          direct_value,
        ) if direct_value.present? && resource_pref.respond_to?(:"#{type}=")
      end

      resource_pref.consented = false if resource_pref.respond_to?(:consented=)
      resource_pref.functional = false if resource_pref.respond_to?(:functional=)
      resource_pref.performant = false if resource_pref.respond_to?(:performant=)
      resource_pref.targetable = false if resource_pref.respond_to?(:targetable=)
      resource_pref.consented_at = nil if resource_pref.respond_to?(:consented_at=)
      resource_pref.save!
    end
  end

  def load_or_create_resource_preference_child!(resource_pref, resource_prefix, type)
    association_prefix = resource_preference_association_prefix(resource_pref)
    association_name = "#{association_prefix}_#{type}"
    create_name = "create_#{association_name}!"
    return unless resource_pref.respond_to?(association_name) || resource_pref.respond_to?(create_name)

    child = resource_pref.public_send("#{association_prefix}_#{type}")
    return child if child.present?
    return unless resource_pref.respond_to?(create_name)

    resource_pref.public_send(
      create_name,
      option_id: PreferenceClassRegistry.default_option_id(resource_prefix, type),
    )
  end

  def mapped_resource_option_id(resource_prefix, type, shared_option_id)
    PreferenceClassRegistry.option_class(resource_prefix, type).ensure_defaults!
    shared_option = PreferenceClassRegistry.option_class(preference_prefix, type).find_by(id: shared_option_id)
    return shared_option_id if shared_option.blank? || shared_option.name.blank?

    lookup_option_id(PreferenceClassRegistry.option_class(resource_prefix, type), shared_option.name)
  end

  def resource_preference_value_for_option(resource_prefix, type, option_id)
    case type
    when :language
      option_id_to_language(option_id, resource_prefix)
    when :region
      option_id_to_region(option_id, resource_prefix)
    when :timezone
      option_id_to_timezone(option_id, resource_prefix)
    when :theme
      normalize_theme(option_id_to_theme(option_id, resource_prefix))
    else
      option_id_to_preference_value(option_id, resource_prefix, type)
    end
  end

  def resource_preference_registry_prefix(resource_pref)
    case resource_pref
    when ClientPreference then "Client"
    when OperatorPreference then "Operator"
    when VisitorPreference then "Visitor"
    else
      resource_pref.class.name.delete_suffix("Preference")
    end
  end

  # Must match the actual has_one association names declared on each mirror
  # model (client_preference.rb: `user_preference_language` etc.;
  # operator_preference.rb: `staff_preference_language` etc.;
  # visitor_preference.rb: `visitor_preference_language` etc.) -- NOT the
  # model's own class-name prefix. "client_preference"/"operator_preference"
  # were wrong (found 2026-07-21 while measuring signed-in dual-write query
  # counts: `load_or_create_resource_preference_child!` silently returned nil
  # for App/Org because `respond_to?("client_preference_language")` /
  # `respond_to?("operator_preference_language")` are both false, so the
  # per-key mirror child option row was never created/updated -- only the
  # flat string column was, via a separate code path that does not depend on
  # this prefix). VisitorPreference's real prefix happens to equal its class
  # name, which is why Com was unaffected.
  def resource_preference_association_prefix(resource_pref)
    case resource_pref
    when ClientPreference then "user_preference"
    when OperatorPreference then "staff_preference"
    when VisitorPreference then "visitor_preference"
    else
      resource_pref.class.name.underscore
    end
  end

  def with_resource_preference_writing_connection(resource_pref, &)
    connection_class = preference_connection_class(resource_pref.class)
    return yield unless connection_class

    connection_class.connected_to(role: :writing, &)
  end

  def preference_connection_class(model_or_class)
    model_class = model_or_class.is_a?(Class) ? model_or_class : model_or_class.class
    # Only Active Record classes own a connection; plain objects are written directly.
    model_class.connection_class_for_self if model_class < ActiveRecord::Base
  end

  # Best-effort atomic boundary for the dual write that spans two databases:
  # the token side (source of truth, e.g. AppPreference on app_setting) and the
  # resource side (mirror, e.g. ClientPreference on app_principal). A genuine
  # two-phase commit is not available across these connections, so the token
  # (source) transaction is the OUTER boundary and the resource (mirror)
  # transaction is INNER. Any error raised inside the block rolls back both
  # sides, which covers every in-request failure path (validation, foreign key,
  # authorization). The only irreducible gap is a process crash in the narrow
  # window between the inner (resource) commit and the outer (token) commit; in
  # that case the mirror is briefly ahead and the next login-time sync re-aligns
  # it back to the source. Callers must keep the source write textually first so
  # the write order matches this commit ordering.
  def with_dual_write_transaction(resource_pref)
    token_owner = preference_connection_owner
    return yield if token_owner.blank?

    resource_owner = resource_pref.present? ? preference_connection_class(resource_pref.class) : nil
    return token_owner.transaction { yield } if resource_owner.blank? || resource_owner == token_owner

    token_owner.transaction do
      resource_owner.connected_to(role: :writing) do
        resource_owner.transaction do
          yield
        end
      end
    end
  end

  def sync_direct_resource_preference!(resource_pref)
    snapshot = resolved_preference_snapshot(@preferences)
    cookie = resolved_preference_cookie(@preferences)
    attrs = snapshot.merge(cookie).compact
    return if attrs.blank?

    with_resource_preference_writing_connection(resource_pref) { resource_pref.update!(attrs) }
  end

  def resolved_preference_snapshot(preference)
    return {} if preference.blank?

    if preference.respond_to?(:language) &&
        preference.respond_to?(:region) &&
        preference.respond_to?(:timezone) &&
        preference.respond_to?(:theme)
      return PreferenceClassRegistry::CHILD_RECORD_TYPES.each_with_object({}) do |type, snapshot|
        next unless preference.respond_to?(type)

        snapshot[type] = preference.public_send(type)
      end.compact
    end

    association_prefix = preference.class.name.underscore

    PreferenceClassRegistry::CHILD_RECORD_TYPES.each_with_object({}) do |type, snapshot|
      association_name = "#{association_prefix}_#{type}"
      next unless preference.respond_to?(association_name)

      child = preference.public_send(association_name)
      value = child&.option&.name
      value = value&.downcase if %i(language region currency).include?(type)
      value = theme_short_code(value) if type == :theme
      snapshot[type] = value if value.present?
    end
  end

  def resolved_preference_cookie(preference)
    return default_preference_cookie_state if preference.blank?

    if preference.respond_to?(:consented)
      return {
        consented: !!preference.consented,
        functional: !!preference.functional,
        performant: !!preference.performant,
        targetable: !!preference.targetable,
      }
    end

    association_prefix = preference.class.name.underscore
    cookie_name = "#{association_prefix}_cookie"
    return default_preference_cookie_state unless preference.respond_to?(cookie_name)

    cookie = preference.public_send(cookie_name)
    return default_preference_cookie_state if cookie.blank?

    {
      consented: !!cookie.consented,
      functional: !!cookie.functional,
      performant: !!cookie.performant,
      targetable: !!cookie.targetable,
    }
  end

  def default_preference_cookie_state
    {
      consented: false,
      functional: false,
      performant: false,
      targetable: false,
    }
  end
end
