# typed: false
# frozen_string_literal: true

module PreferenceGlobal
  extend ActiveSupport::Concern
  include PreferenceBase
  include PreferenceLocalization
  include PreferenceSignOutRotation

  PUBLIC_CONTEXT_KEYS = RequestContextContract.public_keys
  PARAM_CONTEXT_KEYS = (RequestContextContract.required_keys + RequestContextContract.optional_overlay_keys).freeze
  OPTIONAL_PARAM_KEYS = RequestContextContract.optional_overlay_keys
  ALLOWED_REGION_VALUES = RequestContextContract.allowed_regions

  DEFAULT_CONTEXT =
    PreferenceConstants::DEFAULT_PREFERENCES
      .transform_keys(&:to_sym)
      .transform_values { |value| value.to_s.downcase }
      .freeze

  def resolve_param_context
    effective_context
  end

  def ensure_required_ri!
    return if performed?

    normalized_current = normalized_param_ri
    desired = required_ri
    return if desired.blank? || desired == normalized_current

    redirect_to(
      build_ri_redirect_url(desired),
      allow_other_host: false,
      status: redirect_status_for_ri?,
    )
  end

  def default_context
    DEFAULT_CONTEXT
  end

  def requested_context
    request_context.slice(*PARAM_CONTEXT_KEYS)
  end

  def request_context
    PUBLIC_CONTEXT_KEYS.each_with_object({}) do |key, memo|
      value = request_context_value(key)
      memo[key] = value if value.present?
    end
  end

  def cookie_context
    preferences = preference_payload_preferences
    return {} if preferences.blank?

    preference_context_from_hash(preferences).compact
  end

  def effective_context
    default_context.merge(cookie_context).merge(requested_context)
  end

  def required_ri
    effective_context[:ri]
  end

  def default_url_options
    base_options = super || {}
    context = requested_context.slice(*PARAM_CONTEXT_KEYS)
    context.present? ? base_options.merge(context) : base_options
  end

  def preference_context_from_hash(preferences)
    {
      ri: normalized_preference_value(preferences, "ri"),
      lx: normalized_preference_value(preferences, "lx"),
      tz: preferences["tz"],
      ct: theme_short_code(preferences["ct"]),
      cu: normalized_preference_value(preferences, "cu"),
      df: normalized_preference_value(preferences, "df"),
      tf: normalized_preference_value(preferences, "tf"),
      mo: normalized_preference_value(preferences, "mo"),
      dn: normalized_preference_value(preferences, "dn"),
      ps: normalized_preference_value(preferences, "ps"),
    }
  end

  def normalized_preference_value(preferences, key)
    preferences[key]&.to_s&.downcase
  end

  private

  def normalized_param_ri
    request_context_ri
  end

  def request_context_value(key)
    key = key.to_sym
    return unless PUBLIC_CONTEXT_KEYS.include?(key)

    raw_value = params[key].presence
    return if raw_value.blank?

    normalized_value = RequestContextContract.normalize(key, raw_value)
    return unless valid_requested_context_value?(key, normalized_value)

    normalized_value
  end

  PUBLIC_CONTEXT_KEYS.each do |key|
    define_method(:"request_context_#{key}") do
      request_context_value(key)
    end
  end

  def valid_ri_value?(value)
    value.present? && allowed_region_values.include?(value)
  end

  def valid_requested_context_value?(key, value)
    case key
    when :ri
      valid_ri_value?(value)
    when :lx
      normalized_locale(value).present?
    when :ct
      normalize_theme(value).present?
    when :tz
      valid_timezone_value?(value)
    else
      true
    end
  end

  def valid_timezone_value?(value)
    return false if value.blank?

    allowed_requested_timezone_values.include?(value.to_s.downcase)
  end

  def allowed_requested_timezone_values
    %w(
      utc
      etc/utc
      asia/tokyo
      america/new_york
      america/chicago
      america/denver
      america/los_angeles
      america/anchorage
      pacific/honolulu
    ).freeze
  end

  def allowed_region_values
    return ALLOWED_REGION_VALUES if @preferences.blank?

    @allowed_region_values ||=
      begin
        region_option_class = PreferenceClassRegistry.option_class(preference_prefix, :region)
        values = region_option_class.filter_map { |option| option.name&.downcase }.presence
        values || ALLOWED_REGION_VALUES
      rescue KeyError, NameError
        ALLOWED_REGION_VALUES
      end
  end

  def build_ri_redirect_url(ri_value)
    query = request.query_parameters.merge("ri" => ri_value)
    base = "#{request.base_url}#{request.path}"
    query_string = query.to_query
    query_string.blank? ? base : "#{base}?#{query_string}"
  end

  def redirect_status_for_ri?
    (request.get? || request.head?) ? :found : :see_other
  end

  def get_language
    I18n.locale.to_s
  end

  def get_region
    required_ri.presence || "jp"
  end

  def current_region_identifier
    RequestContextContract.normalize_region(params[:ri])
  end

  def set_region
    return if request_format_json?

    normalized_ri = normalized_param_ri
    redirect_params = sanitized_context_query_parameters
    query_changed = redirect_params != request.query_parameters

    if valid_ri_value?(normalized_ri)
      return unless query_changed && (request.get? || request.head?)

      return redirect_to_context_query(redirect_params)
    end

    return unless request.get? || request.head? || params[:ri].present?

    redirect_params = redirect_params.merge("ri" => get_region)
    redirect_to_context_query(redirect_params)
  end

  def sanitized_context_query_parameters
    request.query_parameters.dup.tap do |query|
      query.delete("lx") if query.key?("lx") && !valid_requested_context_value?(:lx, query["lx"])
      query.delete("ct") if query.key?("ct") && !valid_requested_context_value?(:ct, query["ct"])
      query.delete("tz") if query.key?("tz") && !valid_requested_context_value?(:tz, query["tz"])
      query["tz"] = RequestContextContract.normalize(:tz, query["tz"]) if query.key?("tz")
    end
  end

  def redirect_to_context_query(redirect_params)
    # Preserve the actual request path rather than regenerating it from
    # controller/action. Acme routes every preference screen through a single
    # `screens` controller, so url_for(controller:, action:) would collapse to
    # the first screen route (region) and bounce the user off their current
    # screen. Building on request.path (as build_ri_redirect_url does) keeps the
    # redirect on the same screen for both sign and acme surfaces.
    base = "#{request.base_url}#{request.path}"
    query_string = redirect_params.to_query
    redirect_url = query_string.blank? ? base : "#{base}?#{query_string}"

    redirect_to(redirect_url, status: redirect_status_for_ri?)
  end

  def request_format_json?
    request.respond_to?(:format) && request.format.json?
  end

  def set_locale
    locale = normalized_locale(requested_context[:lx])
    locale ||= Actor.preferences.locale if defined?(Actor)
    I18n.locale = locale if locale.present?
    write_preference_cookie(PreferenceBase::LANGUAGE_COOKIE_KEY, I18n.locale.to_s.downcase)
  end

  # The only request-time writer of Time.zone. It always resolves to a concrete
  # zone rather than inheriting whatever the thread was last left with, so the
  # rendered date -- the copyright year included -- depends on the preference and
  # not on the request that happened to run before this one.
  def set_timezone
    timezone = effective_context[:tz]
    timezone = Actor.preferences.timezone if timezone.blank? && defined?(Actor)
    timezone_value = TimezoneIdentifier.resolve(timezone)
    Time.zone = timezone_value
    session[:timezone] = timezone_value
    write_preference_cookie(PreferenceBase::TIMEZONE_COOKIE_KEY, timezone_value)
  end

  private :preference_context_from_hash, :normalized_preference_value
end
