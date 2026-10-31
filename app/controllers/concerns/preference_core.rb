# typed: false
# frozen_string_literal: true

module PreferenceCore
  extend ActiveSupport::Concern
  include CommonRedirect
  include PreferenceBase

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    helper_method :preference_base_i18n_key, :preference_acme_i18n_key
  end

  def set_region_preferences_edit
    with_preference_connection(:reading) do
      @preference_region = load_or_refresh_preference_child_for_edit("Region")
    end
  end

  def set_region_preferences_update
    if anonymous_app_org_preference?
      @preference_region = write_anonymous_realm_region_from_params!(preference_region_params)
      return
    end

    with_preference_connection(:writing) do
      @preference_region = load_or_refresh_preference_child("Region", option_id: nil)
      @preference_language = load_or_refresh_preference_child("Language", option_id: nil)
      @preference_date_format = load_or_refresh_preference_child("DateFormat", option_id: nil)
      @preference_time_format = load_or_refresh_preference_child("TimeFormat", option_id: nil)
      @preference_currency = load_or_refresh_preference_child("Currency", option_id: nil)

      update_region_and_regional_defaults!
    end
  end

  def set_language_preferences_edit
    with_preference_connection(:reading) do
      @preference_language = load_or_refresh_preference_child_for_edit("Language")
    end

  end

  def set_language_preferences_update
    if anonymous_app_org_preference?
      @preference_language = write_anonymous_realm_option_from_params!(:language, preference_language_params)
      return
    end

    with_preference_connection(:writing) do
      @preference_language = load_or_refresh_preference_child("Language", option_id: nil)

      update_preference_child_dual_write!(
        @preference_language,
        sanitize_option_id(preference_language_params, option_type: :language),
        option_type: :language,
        audit_event: "UPDATE_PREFERENCE_LANGUAGE",
      )
    end

    return if @preference_language.option_id.blank?

    language = option_id_to_language(@preference_language.option_id, preference_prefix)
  end

  def set_timezone_preferences_edit
    with_preference_connection(:reading) do
      @preference_timezone = load_or_refresh_preference_child_for_edit("Timezone")
    end

    timezone = option_id_to_timezone(@preference_timezone.option_id, preference_prefix)
    Time.zone = timezone if timezone.present?
  end

  def set_timezone_preferences_update
    if anonymous_app_org_preference?
      @preferences ||= preference_class.new
      submitted = sanitize_option_id(preference_timezone_params, option_type: :timezone)
      @preference_timezone = write_anonymous_realm_option_from_params!(:timezone, submitted)
      timezone = resolved_writable_timezone(@preference_timezone, submitted[PreferenceIoKeys::Params::OPTION_ID])
      return if timezone.blank?

      Time.zone = timezone
      session[:timezone] = timezone
      return
    end

    @preferences ||= ensure_preferences_record
    raise PreferenceOperationError if @preferences.blank?

    submitted_timezone = preference_timezone_params[PreferenceIoKeys::Params::OPTION_ID]

    with_preference_connection(:writing) do
      ensure_model_defaults!(PreferenceClassRegistry.option_class(preference_prefix, :timezone))
      @preference_timezone = load_or_refresh_preference_child("Timezone", option_id: nil)

      begin
        update_preference_child_dual_write!(
          @preference_timezone,
          sanitize_option_id(preference_timezone_params, option_type: :timezone),
          option_type: :timezone,
          audit_event: "UPDATE_PREFERENCE_TIMEZONE",
        )
      rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ArgumentError
        raise PreferenceOperationError
      end
    end

    return if @preference_timezone.option_id.blank?

    @preference_timezone.reload
    timezone = resolved_writable_timezone(@preference_timezone, submitted_timezone)
    return if timezone.blank?

    Time.zone = timezone
    session[:timezone] = timezone
  rescue ArgumentError
    raise PreferenceOperationError
  end

  def set_theme_preferences_edit
    with_preference_connection(:reading) do
      @preference_theme = load_or_refresh_preference_child_for_edit("Theme")
    end
  end

  def set_theme_preferences_update
    if anonymous_app_org_preference?
      @preference_theme = write_anonymous_realm_option_from_params!(:theme, preference_theme_params)
      return
    end

    with_preference_connection(:writing) do
      @preference_theme = load_or_refresh_preference_child("Theme", option_id: nil)

      update_preference_child_dual_write!(
        @preference_theme,
        sanitize_option_id(preference_theme_params, option_type: :theme),
        option_type: :theme,
        audit_event: "UPDATE_PREFERENCE_COLORTHEME",
      )
    end

    return if @preference_theme.option_id.blank?

    theme = option_id_to_theme(@preference_theme.option_id, preference_prefix)
    short_code = theme_short_code(theme)
  end

  def set_selectable_preference_edit(type)
    @preference_option_type = type.to_sym
    with_preference_connection(:reading) do
      @preference_option = load_or_build_selectable_preference_child(type)
    end
  end

  def set_selectable_preference_update(type)
    type = type.to_sym
    @preference_option_type = type

    if anonymous_app_org_preference?
      @preference_option = write_anonymous_realm_option_from_params!(type, selectable_preference_params(type))
      return
    end

    with_preference_connection(:writing) do
      ensure_model_defaults!(PreferenceClassRegistry.option_class(preference_prefix, type))
      @preference_option = load_or_refresh_preference_child(preference_child_class_suffix(type), option_id: nil)

      update_preference_child_dual_write!(
        @preference_option,
        sanitize_option_id(selectable_preference_params(type), option_type: type),
        option_type: type,
        audit_event: "UPDATE_PREFERENCE_#{type.to_s.upcase}",
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ArgumentError
      raise PreferenceOperationError
    end
  end

  def set_selectable_preference_view_context(type)
    @preference_option_type = type.to_sym
    @preference_surface_key = preference_surface_key
    @preference_option_scope = :"preference_#{type}"
    @preference_option_update_url = preference_update_url(type)
    option_class = PreferenceClassRegistry.option_class(preference_prefix, type)
    @preference_option_choices =
      preference_ordered_options(option_class, type).filter_map do |option|
        next if option.name.blank?

        [preference_option_label(type, option.name), option.id]
      end
    group_screen = preference_group_screen(type)
    @preference_option_back_url =
      if group_screen
        preference_edit_url(group_screen, preference_context_redirect_params)
      else
        preference_index_url(preference_context_redirect_params)
      end
  end

  def set_cookie_preferences_edit
    with_preference_connection(:reading) do
      @preference_cookie = load_or_refresh_preference_child_for_edit(
        "Cookie",
        targetable: false, performant: false, functional: false, consented: false,
      )
    end
  end

  def set_cookie_preferences_update
    if anonymous_app_org_preference?
      values = preference_cookie_params.to_h.with_indifferent_access.slice(
        :consented, :functional, :performant, :targetable,
      )
      unless values.keys.map(&:to_sym).sort == PreferenceWriteBoundary::COOKIE_CONSENT_FIELDS.sort
        raise PreferenceOperationError
      end

      submitted = values.transform_values do |value|
        parsed = normalize_preference_boolean(value)
        raise PreferenceOperationError if parsed.nil?

        parsed
      end
      write_preference!(operation: :save, actor: preference_write_actor, submitted:)
      @preference_cookie = PreferenceClassRegistry.cookie_class(preference_prefix).new(submitted)
      return
    end

    with_preference_connection(:writing) do
      @preference_cookie = load_or_refresh_preference_child(
        "Cookie",
        targetable: false, performant: false, functional: false, consented: false,
      )

      update_params = build_cookie_update_params(@preference_cookie, preference_cookie_params)

      update_preference_cookie_dual_write!(
        @preference_cookie,
        update_params,
        audit_event: "UPDATE_PREFERENCE_COOKIE",
      )
    end
  end

  private

  def anonymous_app_org_preference?
    %w(AppPreference OrgPreference).include?(preference_class.name)
  end

  def write_anonymous_realm_option_from_params!(type, option_params)
    params_hash = sanitize_option_id(option_params, option_type: type).to_h.with_indifferent_access
    write_anonymous_realm_option!(type, params_hash[PreferenceIoKeys::Params::OPTION_ID])
  end

  def write_anonymous_realm_region_from_params!(option_params)
    params_hash = sanitize_option_id(option_params, option_type: :region).to_h.with_indifferent_access
    option_id = params_hash[PreferenceIoKeys::Params::OPTION_ID]
    raise PreferenceOperationError if option_id.blank?

    option_class = PreferenceClassRegistry.option_class(preference_prefix, :region)
    option = option_class.find_by!(id: option_id)
    raise PreferenceOperationError if option.name.blank?

    write_preference!(operation: :save, actor: preference_write_actor, submitted: { region: option.name.downcase })
    assign_anonymous_realm_preference_child(
      :region, PreferenceClassRegistry.record_class(preference_prefix, :region).find_by!(preference_id: @preferences.id),
    )
    assign_anonymous_realm_preference_child(
      :language,
      PreferenceClassRegistry.record_class(preference_prefix, :language).find_by!(preference_id: @preferences.id),
    )
    assign_anonymous_realm_preference_child(
      :date_format,
      PreferenceClassRegistry.record_class(preference_prefix, :date_format).find_by!(preference_id: @preferences.id),
    )
    assign_anonymous_realm_preference_child(
      :time_format,
      PreferenceClassRegistry.record_class(preference_prefix, :time_format).find_by!(preference_id: @preferences.id),
    )
    assign_anonymous_realm_preference_child(
      :currency,
      PreferenceClassRegistry.record_class(preference_prefix, :currency).find_by!(preference_id: @preferences.id),
    )
    @preference_region
  rescue ActiveRecord::RecordNotFound, ArgumentError
    raise PreferenceOperationError
  end

  def write_anonymous_realm_option!(type, option_id)
    type = PreferenceClassRegistry::TYPE_KEY_MAP.fetch(type, type).to_sym
    raise PreferenceOperationError if option_id.blank?

    option_class = PreferenceClassRegistry.option_class(preference_prefix, type)
    option = option_class.find_by!(id: option_id)
    value = type == :theme ? option_id_to_theme(option.id, preference_prefix) : option.name
    raise PreferenceOperationError if value.blank?

    write_preference!(operation: :save, actor: preference_write_actor, submitted: { type => value })
    record_class = PreferenceClassRegistry.record_class(preference_prefix, type)
    child = record_class.find_by!(preference_id: @preferences.id)
    assign_anonymous_realm_preference_child(type, child)
  rescue ActiveRecord::RecordNotFound, ArgumentError
    raise PreferenceOperationError
  end

  def assign_anonymous_realm_preference_child(type, child)
    case type
    when :region then @preference_region = child
    when :language then @preference_language = child
    when :timezone then @preference_timezone = child
    when :theme then @preference_theme = child
    when :currency then @preference_currency = child
    when :date_format then @preference_date_format = child
    when :time_format then @preference_time_format = child
    when :motion then @preference_motion = child
    when :density then @preference_density = child
    when :page_size then @preference_page_size = child
    else raise ArgumentError, "unsupported Preference child: #{type.inspect}"
    end
    @preference_option = child if @preference_option_type == type
    child
  end

  def normalize_preference_boolean(value)
    case value
    when true, false then value
    when 1, "1", "true", "TRUE", "t", "T" then true
    when 0, "0", "false", "FALSE", "f", "F" then false
    end
  end

  # Resolves the timezone that may be persisted to Time.zone / session / cookie.
  # Only IANA names accepted by ActiveSupport::TimeZone may flow through; any
  # raw submitted string must pass this allowlist before being trusted.
  def resolved_writable_timezone(preference_record, submitted_value)
    submitted = normalize_known_timezone(submitted_value)
    return submitted if submitted.present?

    normalize_known_timezone(option_id_to_timezone(preference_record.option_id, preference_prefix))
  end

  def normalize_known_timezone(value)
    TimezoneIdentifier.normalize(value)
  end

  def load_or_refresh_preference_child(child_type, default_attributes = {})
    association_name = :"#{preference_prefix_underscore}_#{child_type.to_s.underscore}"
    @preferences ||= ensure_preferences_record

    # Access-token loading can leave a child association memoized on @preferences. Reset only that
    # target so the explicit child query below reads the current DB value without association.reload
    # triggering strict loading for the already-loaded target.
    if @preferences.persisted?
      association = @preferences.association(association_name)
      association.reset if association.loaded?
    end

    load_or_create_preference_child(child_type, default_attributes)
  end

  # GET-safe variant of load_or_refresh_preference_child: never persists a
  # missing child row. Use this from *_preferences_edit actions; the
  # persisting loader above stays reserved for *_preferences_update (a
  # legitimate write point) since GET must not mutate state.
  def load_or_refresh_preference_child_for_edit(child_type, default_attributes = {})
    association_name = :"#{preference_prefix_underscore}_#{child_type.to_s.underscore}"
    @preferences ||= ensure_preferences_record

    if @preferences.persisted?
      association = @preferences.association(association_name)
      association.reset if association.loaded?
    end

    load_or_build_preference_child(child_type, default_attributes)
  end

  def update_preference_child_dual_write!(child, attributes, option_type:, audit_event:)
    raise PreferenceOperationError if child.blank? || attributes.blank?
    raise PreferenceBase::ResolutionError, "com preference writes require their write boundary" if
      child.is_a?(ComSettingRecord)
    raise PreferenceBase::ResolutionError, "unsupported Preference model" unless
      %w(AppPreference OrgPreference).include?(preference_class.name)

    p_hash = attributes.to_h.with_indifferent_access
    write_anonymous_realm_option!(option_type, p_hash[PreferenceIoKeys::Params::OPTION_ID])
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActionPolicy::Unauthorized, ArgumentError => e
    record_preference_write_error("preference.write.option_error", e, target: option_type)
    raise PreferenceOperationError
  end

  def update_preference_cookie_dual_write!(cookie, attributes, audit_event:)
    raise PreferenceOperationError if cookie.blank? || attributes.blank?
    raise PreferenceBase::ResolutionError, "com consent writes require their write boundary" if
      cookie.is_a?(ComPreferenceCookie)
    raise PreferenceBase::ResolutionError, "unsupported Preference model" unless
      %w(AppPreference OrgPreference).include?(preference_class.name)

    values = attributes.to_h.with_indifferent_access.slice(*PreferenceWriteBoundary::COOKIE_CONSENT_FIELDS)
    raise PreferenceOperationError unless values.keys.map(&:to_sym).sort ==
      PreferenceWriteBoundary::COOKIE_CONSENT_FIELDS.sort

    submitted = values.transform_values do |value|
      parsed = normalize_preference_boolean(value)
      raise PreferenceOperationError if parsed.nil?

      parsed
    end
    write_preference!(operation: :save, actor: preference_write_actor, submitted:)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActionPolicy::Unauthorized, ArgumentError => e
    Rails.logger.warn(
      JitLogEvent.format(
        "preference.write.cookie_error", error_class: e.class.name,
                                         message: e.message,
      ),
    )
    record_preference_write_error("preference.write.cookie_error", e, target: :cookie)
    raise PreferenceOperationError
  end

  def render_preference_update_response
    render json: { preference: preference_response_payload }, status: :ok
  end

  def preference_response_payload
    snapshot = resolved_preference_snapshot(@preferences)
    cookie = resolved_preference_cookie(@preferences)

    {
      lx: snapshot[:language] || Actor::Preference::DEFAULTS[:language],
      ct: snapshot[:theme] || Actor::Preference::DEFAULTS[:theme],
      ri: snapshot[:region] || Actor::Preference::DEFAULTS[:region],
      tz: snapshot[:timezone] || Actor::Preference::DEFAULTS[:timezone],
      cu: snapshot[:currency] || "jpy",
      df: snapshot[:date_format] || "iso",
      tf: snapshot[:time_format] || "24",
      mo: snapshot[:motion] || "standard",
      dn: snapshot[:density] || "standard",
      ps: snapshot[:page_size] || "infinity",
      consented: cookie[:consented],
      functional: cookie[:functional],
      performant: cookie[:performant],
      targetable: cookie[:targetable],
    }
  end

  def preference_cookie_params
    return params.fetch(:preference_cookie, {}).permit(
      :functional, :performant, :targetable, :consented, :consented_at,
    ) if params[:preference_cookie]

    params.permit(:functional, :performant, :targetable, :consented, :consented_at)
  end

  def build_cookie_update_params(cookie, params)
    # Ensure nested params are a Hash with indifferent access for reliable key access.
    # Note: Rails 8 `expect` returns an ActionController::Parameters object,
    # which we want to convert to Hash with indifferent access after ensuring it's permitted.
    p_hash = params.to_h.with_indifferent_access
    return p_hash unless p_hash.has_key?(:consented)

    consent_value = ActiveModel::Type::Boolean.new.cast(p_hash[:consented])

    if consent_value && !cookie.consented?
      p_hash[:consented_at] = Time.current
    elsif !consent_value && cookie.consented?
      p_hash[:consented_at] = nil
    end
    p_hash
  end

  def preference_language_params
    params.fetch(:preference_language, {}).permit(:option_id)
  end

  def preference_timezone_params
    params.fetch(:preference_timezone, {}).permit(:option_id)
  end

  def preference_region_params
    params.fetch(:preference_region, {}).permit(:option_id)
  end

  def preference_theme_params
    return params.fetch(:preference_theme, {}).permit(:option_id) if params[:preference_theme]
    return params.fetch(:preference_colortheme, {}).permit(:option_id) if params[:preference_colortheme]

    ActionController::Parameters.new(
      option_id: params[:option_id] || params[:theme] || params[:ct],
    ).permit(:option_id)
  end

  def selectable_preference_params(type)
    param_scope = :"preference_#{type}"
    return params.fetch(param_scope, {}).permit(:option_id) if params[param_scope]

    ActionController::Parameters.new(
      option_id: params[:option_id] || params[type],
    ).permit(:option_id)
  end

  def load_or_build_selectable_preference_child(type)
    type = type.to_sym
    record_class = PreferenceClassRegistry.record_class(preference_prefix, type)
    child = record_class.find_by(preference_id: @preferences.id) if @preferences.persisted?
    return child if child.present?

    record_class.new(
      preference: @preferences,
      option_id: PreferenceClassRegistry.default_option_id(preference_prefix, type),
    )
  end

  def record_preference_write_error(event_name, error, target:)
    Rails.logger.info(
      JitLogEvent.format(
        event_name,
        error: error.class.name,
        message: error.message,
        preference_type: preference_class.name,
        target: target.to_s,
        surface: preference_surface_key,
        owner_id: preference_write_owner_id,
        request_id: request.request_id,
      ),
    )
  end

  def preference_write_owner_id
    resource = preference_current_resource
    resource&.id
  end

  # Resolves the post-update redirect target carried by params[:pt].
  # Delegates path validation to CommonRedirect so the same rules
  # (no scheme, no host, no protocol-relative '//', no encoded backslash)
  # apply consistently across the app.
  def safe_pt_path
    raw = params["pt"]
    return if raw.blank?

    safe_internal_path(raw.to_s)
  end

  def preference_edit_url(screen, params_hash = {})
    public_send(preference_edit_url_helper_name(screen), compact_url_params(params_hash))
  end

  def preference_update_url(screen, params_hash = {})
    public_send(preference_url_helper_name(screen), compact_url_params(params_hash))
  end

  def preference_index_url(params_hash = {})
    public_send(
      "#{preference_route_authority}_#{preference_surface_key}_preference_url",
      compact_url_params(params_hash),
    )
  end

  def preference_context_redirect_params
    PreferenceGlobal::PARAM_CONTEXT_KEYS.each_with_object({}) do |key, memo|
      memo[key] = params[key] if params[key].present?
    end
  end

  def preference_write_redirect_params(except: nil)
    except_keys = Array(except).compact
    except_keys.map!(&:to_sym)
    preference_context_redirect_params.except(*except_keys).tap do |redirect_params|
      except_keys.each { |key| redirect_params[key] = nil }
      redirect_params[:ri] = params[:ri].presence || get_region unless except_keys.include?(:ri)
    end
  end

  def language_preference_redirect_params
    preference_write_redirect_params(except: :lx)
  end

  def apply_language_preference_to_session
    return if @preference_language&.option_id.blank?

    session[:language] = option_id_to_language(@preference_language.option_id, preference_prefix)
  end

  # The child options a region owns and the constant that names each one's value per region. A
  # region change is a regional-bundle reset: it rewrites language, date format, clock format
  # and currency to the region's defaults and marks each one explicit, the same way it has
  # always done for language. Individual screens still let a person override any of them afterwards.
  REGIONAL_DEFAULT_OPTION_NAMES = {
    "jp" => { language: :JA, date_format: :ISO, time_format: :HOUR_24, currency: :JPY },
    "us" => { language: :EN, date_format: :US, time_format: :HOUR_12, currency: :USD },
  }.freeze

  def update_region_and_regional_defaults!
    raise PreferenceBase::ResolutionError, "region writes use the anonymous Preference boundary"
  end

  # region option id -> { language:, date_format:, time_format:, currency: } option ids, or nil
  # when the submitted region is not one this application models.
  def regional_default_option_ids(region_option_id)
    region = option_id_to_region(region_option_id, preference_prefix)
    names = REGIONAL_DEFAULT_OPTION_NAMES[region]
    return nil if names.nil?

    names.to_h do |field, constant_name|
      [field, PreferenceClassRegistry.option_class(preference_prefix, field).const_get(constant_name)]
    end
  end

  def compact_url_params(params_hash)
    params_hash.to_h
  end

  def preference_context_key_for_screen(screen)
    {
      currency: :cu,
      date_format: :df,
      time_format: :tf,
      motion: :mo,
      density: :dn,
      page_size: :ps,
    }[screen.to_sym]
  end

  def reset_preference_by_rebootstrap!
    if anonymous_preference_claim_shape?(preference_class)
      write_preference!(operation: :reset, actor: preference_write_actor, submitted: {})
      return
    end
    raise PreferenceBase::ResolutionError, "unsupported Preference reset model"
  end

  private

  def preference_surface_key
    preference_class.name.delete_suffix("Preference").downcase
  end

  def preference_base_i18n_key(*segments)
    ["base", preference_surface_key, *segments].join(".")
  end

  def preference_acme_i18n_key(*segments)
    ["acme", preference_surface_key, *segments].join(".")
  end

  def preference_edit_url_helper_name(screen)
    "edit_#{preference_url_helper_name(screen)}"
  end

  def preference_url_helper_name(screen)
    suffix =
      case screen
      when :region then "region"
      when :language then "language"
      when :timezone then "timezone"
      when :currency then "currency"
      when :date_format then "calendar"
      when :time_format then "clock"
      when :motion then "motion"
      when :density then "density"
      when :page_size then "pagination"
      when :theme then "theme"
      when :cookie then "cookie"
      when :reset then "reset"
      else
        raise ArgumentError, "Unknown preference screen: #{screen.inspect}"
      end

    "#{preference_route_authority}_#{preference_surface_key}_preference_#{suffix}_url"
  end

  def preference_route_authority
    controller_path.to_s.split("/").first.presence || "sign"
  end

  def preference_group_screen(screen)
    case screen.to_sym
    when :currency, :date_format, :time_format then :region
    end
  end

  def preference_option_label(type, value)
    key = "acme.#{preference_surface_key}.preference.#{type}.options.#{value}"
    label = I18n.t(key)
    label = "#{label} (#{value.to_s.upcase})" if type.to_sym == :currency
    label
  end

end
