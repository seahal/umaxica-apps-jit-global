# typed: false
# frozen_string_literal: true

require "sha3"
require "concurrent"
require_relative "../../models/concerns/refresh_token_shared"

# ==========================================================================
# TOC
# 1) Preference request entrypoints (I/O boundary)
# 2) Preference option/domain mapping
# 3) Audit + preference domain updates
# 4) Refresh/access token lifecycle (I/O + domain)
# 5) Cookie/header/session helpers (I/O boundary)
# 6) Child-record lazy helpers
#
# JWT key resolution -> PreferenceJwtConfiguration (jwt_configuration.rb)
# PreferenceToken encode/decode -> PreferenceToken (token.rb)
# Audit-event name -> ID -> PreferenceClassRegistry.audit_event_id_for
# ==========================================================================

module PreferenceBase
  extend ActiveSupport::Concern
  include DbscCanonicalUrl
  include ::RefreshTokenShared
  include PreferenceCookieWriter
  include PreferenceAccessTokenTransport
  include PreferenceAccessTokenIssuer
  include PreferenceRefreshTokenTransport
  include PreferenceTransport

  class ResolutionError < StandardError; end

  ACCESS_TOKEN_TTL = ::SecurityTokenLifetimes::PREFERENCE_JWT_TTL
  REFRESH_TOKEN_TTL = 400.days
  THEME_COOKIE_KEY = PreferenceIoKeys::Cookies::THEME
  LANGUAGE_COOKIE_KEY = PreferenceIoKeys::Cookies::LANGUAGE
  TIMEZONE_COOKIE_KEY = PreferenceIoKeys::Cookies::TIMEZONE
  PUBLIC_OPTION_COOKIE_METHODS = {
    PreferenceIoKeys::Cookies::THEME => :theme,
    PreferenceIoKeys::Cookies::TIMEZONE => :timezone,
    PreferenceIoKeys::Cookies::CURRENCY => :currency,
    PreferenceIoKeys::Cookies::DATE_FORMAT => :date_format,
    PreferenceIoKeys::Cookies::TIME_FORMAT => :time_format,
    PreferenceIoKeys::Cookies::MOTION => :motion,
    PreferenceIoKeys::Cookies::DENSITY => :density,
    PreferenceIoKeys::Cookies::PAGE_SIZE => :page_size,
  }.freeze

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

  # ==========================================================================
  # 2) Preference request entrypoints (Request/Cookie I/O boundary)
  # ==========================================================================
  def cookie_banner_endpoint_url
    return nil unless cookie_banner_endpoint_available_for_request?

    @cookie_banner_endpoint_url ||=
      begin
        endpoint_url = nil
        %i(
          base_app_web_v0_cookie_url
          base_com_web_v0_cookie_url
          base_org_web_v0_cookie_url
        ).each do |helper_name|
          next unless respond_to?(helper_name, true)

          endpoint_url = public_send(helper_name)
          break
        rescue ActionController::UrlGenerationError
          next
        end
        endpoint_url
      end
  end

  def cookie_banner_endpoint_available_for_request?
    expected_host =
      case ::CoreSurface.current(request)
      when :app then ENV.fetch("PRIVATE_BASE_SERVICE_URL")
      when :com then ENV.fetch("PRIVATE_BASE_CORPORATE_URL")
      when :org then ENV.fetch("PRIVATE_BASE_STAFF_URL")
      end
    return false if expected_host.blank?

    request.host == expected_host
  end

  def extract_cookie_banner_consent(payload)
    return nil unless payload.is_a?(Hash)

    preferences = payload["preferences"]
    return nil unless preferences.is_a?(Hash)
    return preferences["consent"] if preferences.key?("consent")
    return preferences["consented"] if preferences.key?("consented")

    nil
  end

  def set_color_theme
    source = color_theme_preference_source
    theme = normalize_theme(public_option_cookie_value(source, THEME_COOKIE_KEY, :theme))

    write_preference_cookie(THEME_COOKIE_KEY, theme)
    write_public_option_cookies(source)
    @color_theme = theme
    nil
  end

  def color_theme_preference_source
    load_access_token_payload if respond_to?(:load_access_token_payload, true)
    payload = preference_payload_preferences if respond_to?(:preference_payload_preferences, true)
    return payload if payload.is_a?(Hash) && payload.present?

    Actor.preferences
  end

  def write_public_option_cookies(source)
    public_option_cookie_payload(source).each do |key, value|
      write_preference_cookie(key, value.to_s)
    end
  end

  def public_option_cookie_payload(source)
    return {} if source.blank?

    PUBLIC_OPTION_COOKIE_METHODS.each_with_object({}) do |(key, method_name), payload|
      value = public_option_cookie_value(source, key, method_name)
      payload[key] = value if value.present?
    end
  end

  def public_option_cookie_value(source, key, method_name)
    if source.respond_to?(:[])
      source[key] || source[key.to_sym]
    elsif source.respond_to?(method_name)
      source.public_send(method_name)
    end
  end

  def preference_record_theme
    return if @preferences.blank?

    option_id = @preferences.public_send(preference_theme_association)&.option_id
    theme_short_code(option_id_to_theme(option_id, preference_prefix))
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

  def preference_option_classes(prefix)
    classes =
      PreferenceClassRegistry::CHILD_RECORD_TYPES.index_with do |type|
        PreferenceClassRegistry.option_class(prefix, type)
      end
    classes
  end

  def create_preference_cookie(prefix, preference)
    klass = PreferenceClassRegistry.cookie_class(prefix)
    with_model_writing_connection(klass) do
      create_preference_association!(
        preference,
        "#{prefix.underscore}_preference_cookie",
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
          "#{prefix.underscore}_preference_#{type}",
          option_id: option_ids[type],
        )
      end
    end
  end

  def create_preference_association!(preference, association_name, attributes)
    creator = :"create_#{association_name}!"
    return preference.public_send(creator, attributes) if preference.respond_to?(creator)

    association = preference.association(association_name.to_sym)
    association.klass.create!(attributes.merge(preference: preference))
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

  def set_timezone_from_session
    Time.zone = session[:timezone] if session[:timezone].present?
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
    load_access_token_preference_record!
    return @preferences if @preferences.present?

    preference, = load_preference_record_from_refresh_token!(create_if_missing: true)
    if preference.present?
      @preferences = preference
      return @preferences
    end
    return create_new_preference_record! unless @preference_refresh_failed

    @preference_refresh_failed = false
    @refresh_token_value = nil
    @refresh_presented_digest = nil
    @refresh_public_id = nil
    create_new_preference_record!
  end

  def create_audit_log(event_id:, context:, expires_at: nil)
    expires_at_value = expires_at || REFRESH_TOKEN_TTL.from_now
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
        discarded_at: expires_at_value,
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

  def preference_theme_association
    @preference_theme_association ||= "#{preference_prefix_underscore}_theme"
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
    ensure_model_defaults!(preference_binding_method_class)
    ensure_model_defaults!(preference_dbsc_status_class)
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

  def model_connection_owner(klass)
    klass.ancestors.find do |ancestor|
      ancestor.is_a?(Class) && ancestor < ActiveRecord::Base && ancestor.abstract_class?
    end
  end

  def preference_connection_owner
    @preference_connection_owner ||=
      preference_class.ancestors.find do |ancestor|
        ancestor.is_a?(Class) && ancestor < ActiveRecord::Base && ancestor.abstract_class?
      end
  end

  def with_preference_connection(role)
    connection_owner = preference_connection_owner
    return yield if connection_owner.blank?

    connection_owner.connected_to(role: role) { yield }
  rescue ActiveRecord::ConnectionNotDefined
    raise unless role == :reading

    connection_owner.connected_to(role: :writing) { yield }
  end

  # ==========================================================================
  # 5) Refresh/access token lifecycle (Cookie/Header/Request I/O boundary)
  # ==========================================================================
  def preference_binding_method_class
    case preference_class.name
    when "AppPreference" then AppPreferenceBindingMethod
    when "ComPreference" then ComPreferenceBindingMethod
    when "OrgPreference" then OrgPreferenceBindingMethod
    when "ClientToken" then ClientTokenBindingMethod
    when "OperatorToken" then OperatorTokenBindingMethod
    when "VisitorToken" then VisitorTokenBindingMethod
    else
      raise ArgumentError, "Unknown preference class: #{preference_class.name}"
    end
  end

  def preference_dbsc_status_class
    case preference_class.name
    when "AppPreference" then AppPreferenceDbscStatus
    when "ComPreference" then ComPreferenceDbscStatus
    when "OrgPreference" then OrgPreferenceDbscStatus
    when "ClientToken" then ClientTokenDbscStatus
    when "OperatorToken" then OperatorTokenDbscStatus
    when "VisitorToken" then VisitorTokenDbscStatus
    else
      raise ArgumentError, "Unknown preference class: #{preference_class.name}"
    end
  end

  def preference_dbsc_payload_for(preference)
    return unless preference

    {
      binding_method: dbsc_binding_method_name(preference),
      status: dbsc_status_name(preference),
      session_id: preference.dbsc_session_id,
      registration_url: preference_dbsc_path,
      verification_url: preference_dbsc_path,
    }
  end

  def preference_dbsc_cookie_expires_at(preference, now: Time.current)
    return unless preference&.binding_method_dbsc?

    times = [now + 10.minutes, preference.expires_at]
    times << preference.revoked_at if preference.respond_to?(:revoked_at)
    times.compact.min
  end

  def issue_preference_dbsc_registration_header_for(preference)
    return unless preference
    return if preference.binding_method_dbsc?

    challenge = issue_preference_dbsc_challenge_for!(preference)
    return if challenge.blank?

    value = %((ES256 RS256);path="#{preference_dbsc_path}";challenge="#{challenge}")
    response.set_header(
      PreferenceIoKeys::Headers::DBSC_REGISTRATION,
      value,
    )
    response.set_header(PreferenceIoKeys::Headers::DBSC_SECURE_REGISTRATION, value)
    Rails.logger.info(
      "[dbsc] registration header issued path=#{preference_dbsc_path} challenge=#{challenge[0, 24]}",
    )
  end

  def issue_preference_dbsc_challenge_for!(preference)
    challenge = SecureRandom.urlsafe_base64(32)
    preference.update!(dbsc_challenge: challenge, dbsc_challenge_issued_at: Time.current)
    challenge
  rescue StandardError
    nil
  end

  def preference_dbsc_path
    raw =
      case preference_class.name
      when "AppPreference"
        acme_app_edge_v0_dbsc_path if respond_to?(:acme_app_edge_v0_dbsc_path)
      when "OrgPreference"
        acme_org_edge_v0_dbsc_path if respond_to?(:acme_org_edge_v0_dbsc_path)
      when "ComPreference"
        acme_com_edge_v0_dbsc_path if respond_to?(:acme_com_edge_v0_dbsc_path)
      end
    # Canonicalize: the advertised DBSC path must not carry per-request context params,
    # so the browser-registered refresh path stays stable across requests.
    dbsc_canonical_url(raw)
  end

  def dbsc_binding_method_name(record)
    return "dbsc" if record.binding_method_dbsc?
    return "legacy" if record.binding_method_legacy?

    "nothing"
  end

  def dbsc_status_name(record)
    return "pending" if record.dbsc_status_pending?
    return "active" if record.dbsc_status_active?
    return "failed" if record.dbsc_status_failed?
    return "revoke" if record.dbsc_status_revoke?

    "nothing"
  end

  def build_preferences_payload(preference)
    association_prefix = preference.class.name.underscore
    option_prefix = preference.class.name.sub("Preference", "")
    option_ids = preference_payload_option_ids(preference, association_prefix)
    consent_state = preference_cookie_consent_state(preference, association_prefix)

    {
      "ver" => Actor::Preference::SCHEMA_VERSION,
      "lx" => option_id_to_language(option_ids[:language], option_prefix) || "ja",
      "ri" => option_id_to_region(option_ids[:region], option_prefix) || "jp",
      "tz" => option_id_to_timezone(option_ids[:timezone], option_prefix) || "Asia/Tokyo",
      "ct" => normalize_theme(option_id_to_theme(option_ids[:theme], option_prefix)) || "sy",
    }.merge(
      preference_payload_extended_options(option_ids, option_prefix),
      preference_payload_consent(consent_state),
      preference_payload_explicit(preference),
    )
  end

  # Field names the user set on purpose, carried in the signed payload so the
  # Actor can let an explicit value win over dynamic region seeding (?ri).
  # Absent (older record without the marker) yields an empty list.
  def preference_payload_explicit(preference)
    return {} unless preference.respond_to?(:explicit_field_names)

    { "explicit" => preference.explicit_field_names }
  end

  def preference_payload_option_ids(preference, association_prefix)
    %i(language region timezone theme currency date_format time_format motion density
       page_size).index_with do |type|
      association_name = "#{association_prefix}_#{type}"
      next unless preference.respond_to?(association_name)

      preference.public_send(association_name)&.option_id
    end
  end

  def preference_payload_extended_options(option_ids, option_prefix)
    {
      "cu" => option_id_to_preference_value(option_ids[:currency], option_prefix, :currency) || "jpy",
      "df" => option_id_to_preference_value(option_ids[:date_format], option_prefix, :date_format) || "iso",
      "tf" => option_id_to_preference_value(option_ids[:time_format], option_prefix, :time_format) || "24",
      "mo" => option_id_to_preference_value(option_ids[:motion], option_prefix, :motion) || "standard",
      "dn" => option_id_to_preference_value(option_ids[:density], option_prefix, :density) || "standard",
      "ps" => option_id_to_preference_value(option_ids[:page_size], option_prefix, :page_size) || "infinity",
    }
  end

  def preference_payload_consent(consent_state)
    {
      "consented" => consent_state[:consented],
      "functional" => consent_state[:functional],
      "performant" => consent_state[:performant],
      "targetable" => consent_state[:targetable],
    }
  end

  def preference_cookie_consent_state(preference, association_prefix)
    cookie_name = "#{association_prefix}_cookie"
    return { consented: false,
             functional: false,
             performant: false,
             targetable: false, } unless preference.respond_to?(cookie_name)

    cookie = preference.public_send(cookie_name)
    return { consented: false, functional: false, performant: false, targetable: false } if cookie.blank?

    {
      consented: !!cookie.consented,
      functional: !!cookie.functional,
      performant: !!cookie.performant,
      targetable: !!cookie.targetable,
    }
  rescue NoMethodError
    { consented: false, functional: false, performant: false, targetable: false }
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

  def preference_payload_value(key)
    preference_payload_preferences[key.to_s]
  end

  def preference_payload_public_id
    PreferenceToken.extract_public_id(@preference_payload)
  end

  def preference_payload_jti
    PreferenceToken.extract_jti(@preference_payload)
  end

  def clear_preference_refresh_failure!
    @preference_refresh_failed = false
  end

  def preference_refresh_failed?
    @preference_refresh_failed
  end

  def preference_refresh_binding_allowed?(preference)
    return preference_refresh_dbsc_allowed?(preference) if preference.binding_method_dbsc?

    true
  end

  def preference_refresh_dbsc_allowed?(preference)
    unless preference.dbsc_status_active?
      @preference_refresh_binding_reason = "dbsc_not_active"
      return false
    end

    dbsc_cookie = preference_dbsc_cookie_names.lazy.filter_map { |cookie_name|
      cookies[cookie_name].to_s.presence
    }.first
    if dbsc_cookie.blank?
      @preference_refresh_binding_reason = "missing_bound_cookie"
      return false
    end

    if preference.dbsc_session_id.to_s.blank? || preference.dbsc_session_id != dbsc_cookie
      @preference_refresh_binding_reason = "session_id_mismatch"
      return false
    end

    true
  end

  def handle_preference_refresh_binding_denied(preference, refresh_public_id)
    clear_preference_auth_cookies!
    @preference_refresh_failed = true
    @preference_refresh_binding_denied = true

    Rails.logger.warn(
      JitLogEvent.format(
        "preference.token.refresh.binding_denied",
        reason: @preference_refresh_binding_reason || "missing",
        **preference_refresh_log_context(preference, refresh_public_id),
      ),
    )
  end

  def handle_preference_refresh_failed(preference, refresh_public_id)
    clear_preference_auth_cookies!
    @preference_refresh_failed = true

    Rails.logger.warn(
      JitLogEvent.format(
        "preference.token.refresh.failed",
        **preference_refresh_log_context(preference, refresh_public_id),
      ),
    )
  end

  def render_preference_refresh_error!
    if request.format.json?
      render json: {
        error: I18n.t("sign.token_refresh.errors.invalid_refresh_token"),
        error_code: "invalid_refresh_token",
      }, status: :unauthorized
    else
      head :unauthorized
    end
  end

  def valid_refresh_preference?(preference)
    preference.present? &&
      preference.status_id != preference_status_class::DELETED &&
      (preference.expires_at.nil? || preference.expires_at > Time.current) &&
      !preference.replay? &&
      !preference.revoked?
  end

  def find_preference_by_presented_token
    return nil if @refresh_presented_digest.blank?

    relation = preference_class.where(token_digest: @refresh_presented_digest)
    relation = relation.where(public_id: @refresh_public_id) if @refresh_public_id.present?
    relation.order(:id).last
  end

  def handle_preference_refresh_replay!(preference)
    replacement = preference_refresh_grace_replacement(preference)
    if replacement
      adopt_preference_refresh_grace!(preference, replacement)
      return :grace
    end

    now = Time.current

    with_preference_connection(:writing) do
      updates = { discarded_at: now }
      updates[:compromised_at] = now if preference.respond_to?(:compromised_at=)
      updates[:revoked_at] = now if preference.respond_to?(:revoked_at=)

      lapses_at_value = preference.discarded_at
      is_infinite = lapses_at_value.respond_to?(:infinite?) && lapses_at_value.infinite?
      already_handled =
        if preference.respond_to?(:compromised_at)
          preference.compromised_at.present?
        else
          !is_infinite && lapses_at_value <= now
        end
      preference.update!(updates) unless already_handled
    end

    clear_preference_auth_cookies!
    @preference_refresh_failed = true

    Rails.logger.info(
      JitLogEvent.format(
        "preference.token.refresh.replay_detected",
        replaced_by_id: preference.replaced_by_id,
        **preference_refresh_log_context(preference, preference.public_id),
      ),
    )
    :compromised
  end

  # Concurrency grace: when a just-rotated parent refresh token is presented
  # again within the grace window by a sibling request from the same page
  # load, return its still-usable replacement so the request can be served
  # without tripping compromise handling. Returns nil for genuine replays
  # (no replacement, replacement no longer usable, or outside the window).
  def preference_refresh_grace_replacement(preference)
    return nil unless preference.respond_to?(:rotated_within_grace?)
    return nil unless preference.rotated_within_grace?

    replacement =
      with_preference_connection(:writing) do
        preference_class
          .includes(preference_associations_to_preload)
          .find_by(id: preference.replaced_by_id)
      end

    valid_refresh_preference?(replacement) ? replacement : nil
  end

  # Adopt the rotated replacement read-only. We deliberately do NOT issue a
  # new refresh cookie here: the replacement's raw token is only available to
  # the request that performed the rotation, and the winning sibling already
  # set the new cookie. Mutating cookies here would race and clobber it.
  def adopt_preference_refresh_grace!(preference, replacement)
    @preferences = replacement
    @preference_refresh_grace = true

    if respond_to?(:preference_current_resource, true) && respond_to?(:adopt_rotated_preference!, true)
      resource = preference_current_resource
      adopt_rotated_preference!(resource, replacement) if resource
    end

    Rails.logger.info(
      JitLogEvent.format(
        "preference.token.refresh.grace_reuse",
        replaced_by_id: preference.replaced_by_id,
        **preference_refresh_log_context(replacement, preference.public_id),
      ),
    )
  end

  def log_preference_refresh_rotation_failed(preference, refresh_public_id)
    Rails.logger.warn(
      JitLogEvent.format(
        "preference.token.refresh.rotation_failed",
        **preference_refresh_log_context(preference, refresh_public_id),
      ),
    )
  end

  def preference_refresh_log_context(preference, refresh_public_id)
    {
      preference_type: preference_class.name,
      preference_public_id: preference&.public_id || refresh_public_id,
      refresh_public_id: refresh_public_id || @refresh_public_id,
      controller: controller_path,
      action: action_name.presence || params[:action],
      request_method: request.request_method,
      path: request.path,
      format: request.format&.ref,
      request_id: request.request_id,
    }.compact
  end

  # ==========================================================================
  # 6) Cookie/header/session helpers (I/O boundary)
  # ==========================================================================
  def preference_cookie_options(expires_at:, httponly:, domain: false)
    ::CoreCookieOptions.for(
      surface: ::CoreSurface.current(request),
      request: request,
      expires: expires_at,
      httponly: httponly,
      secure: ::JitSessionCookieConfig.force_secure?,
      same_site: :strict,
      path: "/",
      domain: domain,
    )
  end

  def preference_auth_cookie_options(expires_at:)
    # Inherit SameSite=Strict from preference_cookie_options. The preference JWT (access/refresh)
    # is not required on a cross-site top-level inbound navigation: a missing cookie on the first
    # external hit only means default preferences for that first paint, restored on the next
    # same-site request. This matches the accepted trade-off for the auth cookies.
    preference_cookie_options(expires_at: expires_at, httponly: true)
  end

  def access_token_cookie_name
    PreferenceCookieName.access
  end

  def access_token_cookie_names
    [access_token_cookie_name, *PreferenceCookieName.legacy_access_names(surface: preference_cookie_surface)].uniq
  end

  def refresh_token_cookie_name
    PreferenceCookieName.refresh
  end

  def preference_dbsc_cookie_name
    PreferenceCookieName.dbsc
  end

  def refresh_token_cookie_names
    [refresh_token_cookie_name, *PreferenceCookieName.legacy_refresh_names(surface: preference_cookie_surface)].uniq
  end

  def preference_dbsc_cookie_names
    [preference_dbsc_cookie_name, *PreferenceCookieName.legacy_dbsc_names(surface: preference_cookie_surface)].uniq
  end

  def preference_cookie_surface
    case preference_class.name
    when "AppPreference" then :app
    when "ComPreference" then :com
    when "OrgPreference" then :org
    end
  end

  def set_refresh_token_cookie(token, expires_at)
    cookies[refresh_token_cookie_name] = preference_auth_cookie_options(expires_at: expires_at).merge(
      value: token,
    )
    clear_legacy_preference_auth_cookies!
  end

  def set_preference_dbsc_cookie!(token, expires_at:)
    cookies[preference_dbsc_cookie_name] = preference_cookie_options(expires_at: expires_at, httponly: true).merge(
      value: token,
    )
    clear_legacy_preference_auth_cookies!
  end

  def clear_preference_auth_cookies!
    [access_token_cookie_name, refresh_token_cookie_name, preference_dbsc_cookie_name,
     *PreferenceCookieName.legacy_access_names(surface: preference_cookie_surface),
     *PreferenceCookieName.legacy_refresh_names(surface: preference_cookie_surface),
     *PreferenceCookieName.legacy_dbsc_names(surface: preference_cookie_surface),].uniq.each do |cookie_name|
      cookies.delete(cookie_name, **preference_cookie_deletion_options)
    end
    clear_legacy_preference_auth_domain_cookies!
  end

  def clear_legacy_preference_auth_cookies!
    [*PreferenceCookieName.legacy_access_names(surface: preference_cookie_surface),
     *PreferenceCookieName.legacy_refresh_names(surface: preference_cookie_surface),
     *PreferenceCookieName.legacy_dbsc_names(surface: preference_cookie_surface),].uniq.each do |cookie_name|
      next if cookie_name == access_token_cookie_name
      next if cookie_name == refresh_token_cookie_name
      next if cookie_name == preference_dbsc_cookie_name

      cookies.delete(cookie_name, **preference_cookie_deletion_options)
    end
    clear_legacy_preference_auth_domain_cookies!
  end

  def clear_legacy_preference_auth_domain_cookies!
    deletion_options = preference_domain_cookie_deletion_options
    return if deletion_options[:domain].blank?

    # Older preference credential cookies were apex-scoped. Delete only legacy
    # names with a Domain attribute so stale refresh tokens stop shadowing the
    # current host-only transport slot.
    [*PreferenceCookieName.legacy_access_names(surface: preference_cookie_surface),
     *PreferenceCookieName.legacy_refresh_names(surface: preference_cookie_surface),
     *PreferenceCookieName.legacy_dbsc_names(surface: preference_cookie_surface),].uniq.each do |cookie_name|
      next if cookie_name == access_token_cookie_name
      next if cookie_name == refresh_token_cookie_name
      next if cookie_name == preference_dbsc_cookie_name
      next if cookie_name.start_with?(PreferenceIoKeys::HOST_COOKIE_PREFIX)

      cookies.delete(cookie_name, **deletion_options)
    end
  end

  def preference_cookie_deletion_options
    opts = preference_auth_cookie_options(expires_at: nil)
    opts.delete(:expires)
    opts
  end

  def preference_domain_cookie_deletion_options
    opts = ::CoreCookieOptions.for(
      surface: ::CoreSurface.current(request),
      request: request,
      httponly: true,
      secure: ::JitSessionCookieConfig.force_secure?,
      same_site: :strict,
      path: "/",
      domain: true,
    )
    opts.delete(:expires)
    opts
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
    association_name = "#{preference_prefix_underscore}_#{child_type.to_s.underscore}"
    child = @preferences.public_send(association_name)
    return child if child.present?

    begin
      @preferences.public_send("create_#{association_name}!", default_attributes)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      @preferences.reload
      @preferences.public_send(association_name)
    end
  end

  # GET-safe counterpart to load_or_create_preference_child: renders an
  # unpersisted default value when the child row is missing instead of
  # writing to the DB. Bootstrap (create_new_preference_record!) already
  # persists every CHILD_RECORD_TYPES row for a new preference, so a missing
  # row here means a pre-bootstrap-completeness legacy record; the row is
  # backfilled at the next legitimate write point (PATCH/update), not on GET.
  def load_or_build_preference_child(child_type)
    association_name = "#{preference_prefix_underscore}_#{child_type.to_s.underscore}"
    child = @preferences.public_send(association_name)
    return child if child.present?

    PreferenceClassRegistry.record_class(preference_prefix, child_type).new(
      preference: @preferences,
      option_id: PreferenceClassRegistry.default_option_id(preference_prefix, child_type),
    )
  end
end
