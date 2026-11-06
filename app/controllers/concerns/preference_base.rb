# typed: false
# frozen_string_literal: true

require "sha3"
require "concurrent"

# ==========================================================================
# TOC
# 1) Preference request entrypoints (I/O boundary)
# 2) Preference option/domain mapping
# 3) Audit + preference domain updates
# 4) Anonymous Preference JWT lifecycle (I/O + domain)
# 5) Cookie/header/session helpers (I/O boundary)
# 6) Child-record lazy helpers
#
# JWT key resolution -> PreferenceJwtConfiguration (jwt_configuration.rb)
# PreferenceToken encode/decode -> PreferenceToken (token.rb)
# Audit-event name -> ID -> PreferenceClassRegistry.audit_event_id_for
# ==========================================================================

module PreferenceBase
  extend ActiveSupport::Concern
  include PreferenceBrowserBinding
  include PreferenceWriteBoundary
  include PreferenceAccessTokenTransport
  include PreferenceAccessTokenIssuer
  include PreferenceTransport

  class ResolutionError < StandardError; end

  THEME_SHORT_MAP = {
    "light" => "li",
    "dark" => "dr",
    "system" => "sy",
  }.freeze

  THEME_OPTION_MAP = {
    "li" => "light",
    "dr" => "dark",
    "sy" => "system",
    "light" => "light",
    "dark" => "dark",
    "system" => "system",
  }.freeze

  private

  def preference_current_resource
    return unless respond_to?(:current_resource, true)

    current_resource
  rescue StandardError => e
    raise_preference_resolution_error!(:current_resource, e)
  end

  def raise_preference_resolution_error!(component, exception)
    Rails.logger.warn(
      JitLogEvent.format(
        "preference.resolution.failed",
        component: component,
        error_class: exception.class.name,
      ),
    )

    raise ResolutionError.new("Preference #{component} resolution failed"), cause: exception
  end

  def set_color_theme
    source = color_theme_preference_source
    theme = normalize_theme(theme_preference_value(source))
    @color_theme = theme
    nil
  end

  def color_theme_preference_source
    load_access_token_payload if respond_to?(:load_access_token_payload, true)
    payload = preference_payload_preferences if respond_to?(:preference_payload_preferences, true)
    return payload if payload.is_a?(Hash) && payload.present?

    Actor.preferences
  end

  def theme_preference_value(source)
    case source
    when Hash
      source["theme"] || source[:theme]
    when Actor::Preference
      source.theme
    else
      raise ArgumentError, "unsupported Preference display source: #{source.class.name}"
    end
  end

  def create_preference_options(preference, params_hash = {})
    prefix = preference_prefix(preference)
    option_ids = preference_option_ids(prefix, params_hash)

    # All three steps target the same app_setting DB with the writing role.
    # Wrap them in a single connected_to switch so the 12 inner
    # with_model_writing_connection calls reuse the already-active context
    # instead of each opening a new one.
    with_preference_connection(:writing) do
      create_preference_cookie(prefix, preference)
      ensure_preference_option_defaults(prefix)
      create_preference_option_records(prefix, preference, option_ids)
      if prefix == "Com"
        ComPreferenceWebPushOption.ensure_defaults!
        create_preference_association!(
          preference, ComPreferenceWebPush, option_id: ComPreferenceWebPushOption::DISABLED,
        )
      end
    end
  end

  # ==========================================================================
  # 3) Preference option/domain mapping
  # ==========================================================================
  def preference_option_ids(prefix, params_hash)
    PreferenceClassRegistry::CHILD_RECORD_TYPES.index_with do |type|
      resolve_option_id_from_param(
        preference_param_value(params_hash, type),
        type,
        PreferenceClassRegistry.default_option_id(prefix, type),
        prefix,
      )
    end
  end

  def create_preference_cookie(prefix, preference)
    klass = PreferenceClassRegistry.cookie_class(prefix)
    with_model_writing_connection(klass) do
      create_preference_association!(
        preference,
        klass,
        targetable: false,
        performant: false,
        functional: false,
        consented: false,
      )
    end
  end

  def ensure_preference_option_defaults(prefix)
    PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
      klass = PreferenceClassRegistry.option_class(prefix, type)
      ensure_model_defaults!(klass)
    end
  end

  def create_preference_option_records(prefix, preference, option_ids)
    PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
      klass = PreferenceClassRegistry.record_class(prefix, type)
      with_model_writing_connection(klass) do
        create_preference_association!(
          preference,
          klass,
          option_id: option_ids[type],
        )
      end
    end
  end

  def create_preference_association!(preference, record_class, attributes)
    record_class.find_or_create_by!(preference_id: preference.id) do |record|
      # Reuse the loaded parent: with only the foreign key, each child's required belongs_to
      # validation re-selects the same preference row (N+1).
      record.preference = preference
      record.assign_attributes(attributes)
    end
  end

  def preference_param_value(params_hash, type)
    case type
    when :language then params_hash[:lx]
    when :region then params_hash[:ri]
    when :timezone then params_hash[:tz]
    when :theme then params_hash[:ct]
    else params_hash[type]
    end
  end

  def resolve_option_id_from_param(value, type, default, _prefix)
    return default if value.blank?

    sanitized = sanitize_option_id({ option_id: value }, option_type: type)
    if sanitized[:option_id].is_a?(Integer)
      sanitized[:option_id]
    else
      default
    end
  end

  def locale_from_region(region)
    return if region.blank?

    {
      "jp" => "ja",
      "us" => "en",
    }[region]
  end

  def normalized_locale(value)
    return if value.blank?

    normalized_value = value.to_s.downcase
    return if normalized_value.blank?

    return unless available_locale_strings.include?(normalized_value)

    normalized_value.to_sym
  end

  def available_locale_strings
    @available_locale_strings ||=
      begin
        locales = I18n.available_locales.map { |locale| locale.to_s.downcase }
        locales.uniq!
        locales
      end
  end

  def preference_class
    @preference_class ||=
      begin
        PreferenceClassRegistry.for_controller_path(controller_path)
      end
  end

  def preference_audit_class
    @preference_audit_class ||= PreferenceClassRegistry.audit_class_for(preference_class)
  end

  def preference_audit_event_class
    @preference_audit_event_class ||= PreferenceClassRegistry.audit_event_class_for(preference_class)
  end

  def preference_audit_level_class
    @preference_audit_level_class ||= PreferenceClassRegistry.audit_level_class_for(preference_class)
  end

  def preference_status_class
    @preference_status_class ||= PreferenceClassRegistry.status_class_for(preference_class)
  end

  # ==========================================================================
  # 4) Audit + preference domain updates
  # ==========================================================================
  def normalize_preference_audit_event_id(event_id)
    return if event_id.blank?

    PreferenceClassRegistry.audit_event_id_for(preference_audit_event_class, event_id)
  end

  def ensure_preferences_record
    load_access_token_preference_record! if @preferences.blank?
    @preferences ||= preference_class.new
  end

  def create_audit_log(event_id:, context:, expires_at: nil)
    expires_at_value = expires_at || SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_TTL.from_now
    normalized_event_id = normalize_preference_audit_event_id(event_id)

    ChronicleRecord.connected_to(role: :writing) do
      ensure_model_defaults!(preference_audit_level_class)
      # Seed the full event catalog once. Per-id find_or_create_by! N+1s when a
      # region change writes language, date format, clock, and currency as one bundle.
      ensure_model_defaults!(preference_audit_event_class) if normalized_event_id.present?

      preference_audit_class.create!(
        subject_id: @preferences.id.to_s,
        subject_type: @preferences.class.name,
        event_id: normalized_event_id,
        level_id: preference_audit_level_class::INFO,
        occurred_at: Time.current,
        discard_at: expires_at_value,
        ip_address: request.remote_ip || default_audit_ip,
        context: context,
      )
    end
  end

  def preference_prefix(preference = nil)
    return preference.class.name.gsub("Preference", "") if preference.present?

    @preference_prefix ||= preference_class.name.gsub("Preference", "")
  end

  def preference_prefix_underscore
    @preference_prefix_underscore ||= preference_class.name.underscore
  end

  def default_audit_ip
    # `IPAddr.new(Integer)` requires an explicit address family; without it the
    # current IPAddr raises IPAddr::AddressFamilyError instead of returning the
    # IPv4 loopback address this fallback exists to produce.
    IPAddr.new((127 << 24) + 1, Socket::AF_INET).to_s
  end

  def update_preference_child_with_audit(child, attributes, audit_event)
    return if child.blank? || attributes.blank?

    # Ensure nested params are a Hash with indifferent access for reliable key access.
    # Note: Rails 8 `expect` returns an ActionController::Parameters object,
    # which we want to convert to Hash with indifferent access after ensuring it's permitted.
    p_hash = attributes.to_h.with_indifferent_access

    preference_connection_owner.transaction do
      child.update!(p_hash)
      create_audit_log(
        event_id: audit_event,
        context: { updated_attributes: p_hash },
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("#{audit_event} failed: #{e.message}")
    raise PreferenceOperationError
  end

  def sanitize_option_id(params, option_type: nil)
    params[PreferenceIoKeys::Params::OPTION_ID] = nil if params[PreferenceIoKeys::Params::OPTION_ID].blank?

    return params if params[PreferenceIoKeys::Params::OPTION_ID].blank?

    # If option_id is already an integer, use it as-is
    option_id_key = PreferenceIoKeys::Params::OPTION_ID
    if option_type != :page_size &&
        (params[option_id_key].is_a?(Integer) || params[option_id_key].to_s.match?(/^\d+$/))
      params[option_id_key] = Integer(params[option_id_key].to_s, 10)
      return params
    end

    prefix = preference_class.name.delete_suffix("Preference")
    option_class = PreferenceClassRegistry.option_class(prefix, option_type) if option_type

    if option_class
      name =
        if option_type == :theme
          canonical_theme_option_id(params[option_id_key])
        else
          params[option_id_key]
        end
      resolved_option_id = lookup_option_id(option_class, name)
      params[option_id_key] = resolved_option_id if resolved_option_id
    end
    params
  end

  def lookup_option_id(option_class, raw_name)
    return if option_class.blank? || raw_name.blank?

    target_keys = normalized_option_lookup_keys(raw_name)
    option_class.find_each do |option|
      return option.id if (target_keys & normalized_option_lookup_keys(option.name)).any?
    end
    nil
  end

  def normalized_option_lookup_keys(value)
    normalized = value.to_s
    [
      normalized.downcase,
      normalized.upcase.tr("/", "_").tr("-", "_").downcase,
    ].uniq
  end

  def canonical_theme_option_id(value)
    return nil if value.blank?

    THEME_OPTION_MAP[value.to_s.downcase]
  end

  def theme_short_code(value)
    return nil if value.blank?

    THEME_SHORT_MAP[value.to_s.downcase]
  end

  def normalize_theme(value)
    return nil if value.blank?

    theme = value.to_s.downcase
    if THEME_SHORT_MAP.value?(theme)
      theme
    else
      THEME_SHORT_MAP[theme]
    end
  end

  def ensure_preference_reference_defaults!
    ensure_model_defaults!(PreferenceClassRegistry.status_class_for(preference_class))
    ensure_model_defaults!(preference_audit_level_class)
    ensure_model_defaults!(preference_audit_event_class)
  end

  def ensure_model_defaults!(klass)
    return if klass.blank? || !klass.respond_to?(:ensure_defaults!)

    connection_owner = model_connection_owner(klass)
    if connection_owner.blank?
      klass.ensure_defaults!
      return
    end

    connection_owner.connected_to(role: :writing) do
      klass.ensure_defaults!
    end
  end

  def with_model_writing_connection(klass)
    connection_owner = model_connection_owner(klass)
    return yield if connection_owner.blank?

    connection_owner.connected_to(role: :writing) { yield }
  end

  # Only Active Record classes own a connection; callers write plain objects directly.
  def model_connection_owner(klass)
    klass.connection_class_for_self if klass.is_a?(Class) && klass < ActiveRecord::Base
  end

  def preference_connection_owner
    @preference_connection_owner ||= model_connection_owner(preference_class)
  end

  def with_preference_connection(role)
    connection_owner = preference_connection_owner
    return yield if connection_owner.blank?

    connection_owner.connected_to(role: role) { yield }
  end

  # ==========================================================================
  # 5) Refresh/access token lifecycle (Cookie/Header/Request I/O boundary)
  # ==========================================================================
  def build_preferences_payload(preference)
    raise ArgumentError, "unsupported Preference token model" unless anonymous_preference_claim_shape?(preference)

    build_anonymous_realm_preferences_payload(preference)
  end

  # Anonymous realm tokens contain only the nine closed display fields. Region, consent, Web Push,
  # and identity stay in their owning records and never enter the shared display credential.
  def build_anonymous_realm_preferences_payload(preference)
    prefix = preference_prefix(preference)
    option_ids = preference_payload_option_ids(preference)
    %i(theme language timezone currency date_format time_format motion density page_size).each do |type|
      option_ids[type] ||= PreferenceClassRegistry.default_option_id(prefix, type)
    end
    {
      "theme" => normalized_theme_key(option_id_to_theme(option_ids[:theme], prefix)),
      "language" => option_id_to_language(option_ids[:language], prefix),
      "timezone" => option_id_to_timezone(option_ids[:timezone], prefix),
      "currency" => option_id_to_preference_value(option_ids[:currency], prefix, :currency),
      "date_format" => option_id_to_preference_value(option_ids[:date_format], prefix, :date_format),
      "time_format" => option_id_to_preference_value(option_ids[:time_format], prefix, :time_format),
      "motion" => option_id_to_preference_value(option_ids[:motion], prefix, :motion),
      "density" => option_id_to_preference_value(option_ids[:density], prefix, :density),
      "page_size" => option_id_to_preference_value(option_ids[:page_size], prefix, :page_size),
    }
  end

  def normalized_theme_key(value)
    { "li" => "light", "dr" => "dark", "sy" => "system" }.fetch(value, value)
  end

  # Accepts either the preference instance or its class; the claim shape is a per-class contract.
  def anonymous_com_claim_shape?(preference)
    klass = preference.is_a?(Class) ? preference : preference.class

    klass.name == "ComPreference"
  end

  def anonymous_preference_claim_shape?(preference)
    klass = preference.is_a?(Class) ? preference : preference.class

    [AppPreference, ComPreference, OrgPreference].include?(klass)
  end

  def anonymous_preference_payload?(payload)
    payload.is_a?(Hash) && SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALMS.include?(payload["aud"])
  end

  def preference_realm_name
    case preference_class.name
    when "AppPreference" then "app"
    when "ComPreference" then "com"
    when "OrgPreference" then "org"
    else raise ArgumentError, "unsupported Preference model: #{preference_class.name}"
    end
  end

  def preference_payload_option_ids(preference)
    %i(language region timezone theme currency date_format time_format motion density
       page_size).index_with do |type|
      PreferenceClassRegistry.record_class(
        preference_prefix(preference),
        type,
      ).where(preference_id: preference.id).pick(:option_id)
    end
  end

  def option_id_to_language(option_id, prefix)
    return if option_id.blank?

    option_class = PreferenceClassRegistry.option_class(prefix, :language)
    return "ja" if option_id == option_class::JA
    return "en" if option_class.const_defined?(:EN) && option_id == option_class::EN

    option_id.to_s.downcase
  end

  def option_id_to_region(option_id, prefix)
    return if option_id.blank?

    option_class = PreferenceClassRegistry.option_class(prefix, :region)
    return "jp" if option_id == option_class::JP
    return "us" if option_id == option_class::US

    option_id.to_s.downcase
  end

  def option_id_to_timezone(option_id, prefix)
    return if option_id.blank?

    option_class = PreferenceClassRegistry.option_class(prefix, :timezone)
    return "Asia/Tokyo" if option_id == option_class::ASIA_TOKYO
    return "Etc/UTC" if option_id == option_class::ETC_UTC

    option_class.find_by(id: option_id)&.name || option_id.to_s
  end

  def option_id_to_theme(option_id, prefix)
    return if option_id.blank?

    option_class = PreferenceClassRegistry.option_class(prefix, :theme)
    return "light" if option_id == option_class::LIGHT
    return "dark" if option_id == option_class::DARK
    return "system" if option_id == option_class::SYSTEM

    option_id.to_s
  end

  def option_id_to_preference_value(option_id, prefix, type)
    return if option_id.blank?

    PreferenceClassRegistry.option_class(prefix, type).find_by(id: option_id)&.name
  end

  def preference_payload_preferences
    PreferenceToken.extract_preferences(@preference_payload)
  end

  def access_token_cookie_name
    PreferenceCookieName.anonymous_jwt
  end

  def access_token_cookie_names
    [PreferenceCookieName.anonymous_jwt]
  end

  def preference_cookie_surface
    case preference_class.name
    when "AppPreference" then :app
    when "ComPreference" then :com
    when "OrgPreference" then :org
    end
  end

  def preference_child_class_suffix(type)
    {
      currency: "Currency",
      date_format: "DateFormat",
      time_format: "TimeFormat",
      motion: "Motion",
      density: "Density",
      page_size: "PageSize",
    }.fetch(type.to_sym)
  end

  def preference_associations_to_preload
    prefix = preference_class.name.underscore
    [
      "#{prefix}_cookie",
      "#{prefix}_language",
      "#{prefix}_region",
      "#{prefix}_timezone",
      "#{prefix}_theme",
      "#{prefix}_currency",
      "#{prefix}_date_format",
      "#{prefix}_time_format",
      "#{prefix}_motion",
      "#{prefix}_density",
      "#{prefix}_page_size",
    ].map(&:to_sym)
  end

  # ==========================================================================
  # 7) Child-record lazy helpers
  # ==========================================================================
  def load_or_create_preference_child(child_type, default_attributes = {})
    record_class = preference_child_record_class(child_type)
    relation = record_class.where(preference_id: @preferences.id)
    child = relation.first
    return child if child.present?

    begin
      relation.create!(default_attributes)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      relation.first!
    end
  end

  # GET-safe counterpart to load_or_create_preference_child: renders an
  # unpersisted default value when the child row is missing instead of
  # writing to the DB. Bootstrap (create_new_preference_record!) already
  # persists every CHILD_RECORD_TYPES row for a new preference, so a missing
  # row here means a pre-bootstrap-completeness legacy record; the row is
  # backfilled at the next legitimate write point (PATCH/update), not on GET.
  def load_or_build_preference_child(child_type, default_attributes = {})
    record_class = preference_child_record_class(child_type)
    child = record_class.find_by(preference_id: @preferences.id) if @preferences.persisted?
    return child if child.present?

    attributes = { preference_id: @preferences.id }.merge(default_attributes)
    unless child_type.to_s == "Cookie"
      attributes[:option_id] = PreferenceClassRegistry.default_option_id(preference_prefix, child_type)
    end

    record_class.new(attributes)
  end

  def preference_child_record_class(child_type)
    return PreferenceClassRegistry.cookie_class(preference_prefix) if child_type.to_s == "Cookie"

    PreferenceClassRegistry.record_class(preference_prefix, child_type)
  end
end
