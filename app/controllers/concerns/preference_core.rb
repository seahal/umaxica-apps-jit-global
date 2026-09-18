# typed: false
# frozen_string_literal: true

module PreferenceCore
  extend ActiveSupport::Concern
  include CommonRedirect
  include PreferenceBase
  include PreferenceResourceSync

  included do
    helper_method :preference_base_i18n_key, :preference_acme_i18n_key
  end

  COOKIE_EXPIRY = 400.days

  def set_region_preferences_edit
    with_preference_connection(:writing) do
      @preference_region = load_or_refresh_preference_child_for_edit("Region")
    end
  end

  def set_region_preferences_update
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
    with_preference_connection(:writing) do
      @preference_language = load_or_refresh_preference_child_for_edit("Language")
    end

    pin_locale_to_saved_language(@preference_language)
  end

  # Render the language settings screen in the user's *saved* language so the
  # page text matches the option pre-selected in the form. The selector reflects
  # the persisted DB/JWT value (@preference_language.option_id), but the page
  # locale is otherwise resolved by ActorSupport#overlay_language, which lets a
  # transient ?lx=/?ri= request param win over the saved value. Without this pin
  # the page renders in the overlay locale while the selector shows the saved one
  # (e.g. an English page with Japanese selected). On the settings screen the saved
  # value is the source of truth, so align the display to it.
  def pin_locale_to_saved_language(language_preference)
    option_id = language_preference&.option_id
    return if option_id.blank?

    locale = option_id_to_language(option_id, preference_prefix)
    return if locale.blank?

    locale = locale.to_sym
    I18n.locale = locale if I18n.available_locales.include?(locale)
  end

  def set_language_preferences_update
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
    write_preference_cookie(PreferenceBase::LANGUAGE_COOKIE_KEY, language) if language.present?
  end

  def set_timezone_preferences_edit
    with_preference_connection(:writing) do
      ensure_model_defaults!(PreferenceClassRegistry.option_class(preference_prefix, :timezone))
      @preference_timezone = load_or_refresh_preference_child_for_edit("Timezone")
    end

    timezone = option_id_to_timezone(@preference_timezone.option_id, preference_prefix)
    Time.zone = timezone if timezone.present?
  end

  def set_timezone_preferences_update
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
    write_preference_cookie(PreferenceBase::TIMEZONE_COOKIE_KEY, timezone)
  rescue ArgumentError
    raise PreferenceOperationError
  end

  def set_theme_preferences_edit
    with_preference_connection(:writing) do
      @preference_theme = load_or_refresh_preference_child_for_edit("Theme")
    end
  end

  def set_theme_preferences_update
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
    write_preference_cookie(PreferenceBase::THEME_COOKIE_KEY, short_code) if short_code.present?
  end

  def set_selectable_preference_edit(type)
    @preference_option_type = type.to_sym
    with_preference_connection(:writing) do
      ensure_model_defaults!(PreferenceClassRegistry.option_class(preference_prefix, type))
      @preference_option = load_or_build_selectable_preference_child(type)
    end
  end

  def set_selectable_preference_update(type)
    type = type.to_sym
    @preference_option_type = type

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
    @preference_option_choices =
      PreferenceClassRegistry.option_class(
        preference_prefix,
        type,
      ).order(:id).filter_map do |option|
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
    with_preference_connection(:writing) do
      @preference_cookie = load_or_refresh_preference_child(
        "Cookie",
        targetable: false, performant: false, functional: false, consented: false,
      )
    end
  end

  def set_cookie_preferences_update
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

    # Access-token loading can leave a child association memoized on @preferences.
    # Reload it here so preference edit/update screens render the latest DB value
    # without forcing the generic loader to refresh associations for every caller.
    if @preferences.persisted?
      association = @preferences.association(association_name)
      association.reload if association.loaded?
    end

    load_or_create_preference_child(child_type, default_attributes)
  end

  # GET-safe variant of load_or_refresh_preference_child: never persists a
  # missing child row. Use this from *_preferences_edit actions; the
  # persisting loader above stays reserved for *_preferences_update (a
  # legitimate write point) since GET must not mutate state.
  def load_or_refresh_preference_child_for_edit(child_type)
    association_name = :"#{preference_prefix_underscore}_#{child_type.to_s.underscore}"
    @preferences ||= ensure_preferences_record

    if @preferences.persisted?
      association = @preferences.association(association_name)
      association.reload if association.loaded?
    end

    load_or_build_preference_child(child_type)
  end

  def reload_preferences_and_reissue_token!(sync_resource: true)
    @preferences.reload
    # Force reload all preference associations to ensure they reflect DB state
    PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
      assoc_name = "#{preference_prefix_underscore}_#{type}"
      @preferences.association(assoc_name.to_sym).reload if @preferences.respond_to?(assoc_name)
    end
    issue_access_token_from(@preferences)

    sync_to_resource_preference! if sync_resource
  end

  def update_preference_child_dual_write!(child, attributes, option_type:, audit_event:)
    raise PreferenceOperationError if child.blank? || attributes.blank?

    p_hash = attributes.to_h.with_indifferent_access
    resource_pref = preference_write_resource_preference!
    authorize_resource_preference_write!(resource_pref)

    # Source (token) first, mirror (resource) second, both inside one cross-DB
    # boundary so a failure on either side rolls the whole change back instead
    # of leaving the two databases out of sync.
    with_dual_write_transaction(resource_pref) do
      update_preference_child_with_audit(child, p_hash, audit_event)
      # Record that this field was set on purpose so localization can let the saved
      # value win over dynamic region seeding (?ri). Must run before the token is
      # reissued so the explicit list rides along in the preference payload.
      mark_preference_field_explicit!(option_type)
      write_resource_preference_option!(
        resource_pref, option_type,
        p_hash[PreferenceIoKeys::Params::OPTION_ID],
      ) if resource_pref
    end

    reload_preferences_and_reissue_token!(sync_resource: false)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActionPolicy::Unauthorized, ArgumentError => e
    record_preference_write_error("preference.write.option_error", e, target: option_type)
    raise PreferenceOperationError
  end

  # Mark a preference field as explicitly chosen on the session preference record.
  # No-op when the record is missing or predates the explicit-fields marker.
  def mark_preference_field_explicit!(option_type)
    return if @preferences.blank?
    return unless @preferences.respond_to?(:mark_field_explicit!)

    with_preference_connection(:writing) do
      @preferences.mark_field_explicit!(option_type)
    end
  end

  def update_preference_cookie_dual_write!(cookie, attributes, audit_event:)
    raise PreferenceOperationError if cookie.blank? || attributes.blank?

    p_hash = attributes.to_h.with_indifferent_access
    resource_pref = preference_write_resource_preference!
    authorize_resource_preference_write!(resource_pref)

    # Source (token) first, mirror (resource) second, both inside one cross-DB
    # boundary so a failure on either side rolls the whole change back instead
    # of leaving the two databases out of sync.
    with_dual_write_transaction(resource_pref) do
      update_preference_child_with_audit(cookie, p_hash, audit_event)
      write_resource_preference_cookie!(resource_pref, p_hash) if resource_pref
    end

    reload_preferences_and_reissue_token!(sync_resource: false)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActionPolicy::Unauthorized, ArgumentError => e
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
    association_name = :"#{preference_prefix_underscore}_#{type}"
    child = @preferences.public_send(association_name)
    return child if child.present?

    PreferenceClassRegistry.record_class(preference_prefix, type).new(
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

  def preference_update_notice
    t([preference_translation_scope, "update_success"].join("."))
  end

  def preference_reset_destroyed_notice
    t(["acme", preference_surface_key, "preference.resets.destroyed"].join("."))
  end

  def preference_operation_failed_alert
    I18n.t("errors.messages.preference_operation_failed")
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

  REGIONAL_DEFAULT_AUDIT_EVENTS = {
    language: "UPDATE_PREFERENCE_LANGUAGE",
    date_format: "UPDATE_PREFERENCE_DATE_FORMAT",
    time_format: "UPDATE_PREFERENCE_TIME_FORMAT",
    currency: "UPDATE_PREFERENCE_CURRENCY",
  }.freeze

  def update_region_and_regional_defaults!
    region_attributes = sanitize_option_id(preference_region_params, option_type: :region)
    derived_option_ids = regional_default_option_ids(region_attributes[PreferenceIoKeys::Params::OPTION_ID])
    raise PreferenceOperationError if derived_option_ids.blank?

    resource_pref = preference_write_resource_preference!
    authorize_resource_preference_write!(resource_pref)

    with_dual_write_transaction(resource_pref) do
      write_regional_bundle_field!(
        resource_pref, :region, @preference_region,
        region_attributes[PreferenceIoKeys::Params::OPTION_ID], "UPDATE_PREFERENCE_REGION",
      )

      derived_option_ids.each do |field, option_id|
        write_regional_bundle_field!(
          resource_pref, field, instance_variable_get(:"@preference_#{field}"),
          option_id, REGIONAL_DEFAULT_AUDIT_EVENTS.fetch(field),
        )
      end
    end

    reload_preferences_and_reissue_token!(sync_resource: false)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActionPolicy::Unauthorized, ArgumentError => e
    record_preference_write_error("preference.write.option_error", e, target: :region)
    raise PreferenceOperationError
  end

  def write_regional_bundle_field!(resource_pref, field, child, option_id, audit_event)
    update_preference_child_with_audit(child, { PreferenceIoKeys::Params::OPTION_ID => option_id }, audit_event)
    mark_preference_field_explicit!(field)
    write_resource_preference_option!(resource_pref, field, option_id) if resource_pref
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

  def delete_preference_cookie
    preference = find_preference_for_delete
    if preference.present?
      log_preference_reset(preference)
      # Keep cookies and records intact on logout; do not delete or reset preference values.
      # The preference record and cookies remain so the user retains their settings.
    end
    reset_preference_state
    nil
  end

  # Reset preferences to defaults (explicit user action, not logout).
  # Resets BOTH AppPreference/OrgPreference AND ClientPreference/OperatorPreference.
  def reset_preference_to_defaults!
    return if @preferences.blank?

    resource_pref = preference_write_resource_preference!
    authorize_resource_preference_write!(resource_pref)

    # Same dual-write contract as the option/cookie writes: source (token) first,
    # mirror (resource) second, both inside one cross-DB boundary so a failure
    # rolls back the whole reset instead of leaving the databases out of sync.
    with_dual_write_transaction(resource_pref) do
      reset_app_org_preference_to_defaults!(@preferences)
      reset_resource_preference_defaults_for_write!(resource_pref) if resource_pref

      create_audit_log(
        event_id: preference_audit_event_class::RESET_BY_USER_DECISION,
        context: { preference_reset: true, reset_to_defaults: true },
      )
    end

    reload_preferences_and_reissue_token!(sync_resource: false)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActionPolicy::Unauthorized, ArgumentError => e
    record_preference_write_error("preference.reset.error", e, target: :reset)
    raise PreferenceOperationError
  end

  def reset_preference_by_rebootstrap!
    return if @preferences.blank?

    old_preference = @preferences
    resource_pref = existing_resource_preference_for_reset
    authorize_resource_preference_write!(resource_pref)

    create_audit_log(
      event_id: preference_audit_event_class::RESET_BY_USER_DECISION,
      context: { preference_reset: true, rebootstrap: true },
    )

    retire_preference_for_reset!(old_preference)
    destroy_resource_preference_for_reset!(resource_pref)
    clear_preference_auth_cookies!
    clear_preference_context_cookies!
    reset_preference_state

    @preferences = create_new_preference_record!(params_hash: {})
    issue_access_token_from(@preferences)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActionPolicy::Unauthorized, ArgumentError => e
    record_preference_write_error("preference.reset.error", e, target: :reset)
    raise PreferenceOperationError
  end

  private

  def find_preference_for_delete
    return @preferences if @preferences.present?

    token_value = refresh_token_value
    @refresh_token_value = token_value
    return nil if token_value.blank?

    token_digest = refresh_token_lookup_digest(token_value)
    return nil unless token_digest

    with_preference_connection(:writing) do
      preference_class.find_by(token_digest: token_digest)
    end
  end

  def log_preference_reset(preference)
    @preferences = preference
    create_audit_log(
      event_id: preference_audit_event_class::RESET_BY_USER_DECISION,
      context: { preference_reset: true, kept_values: true },
    )
  rescue StandardError => e
    Rails.logger.error("log_preference_reset failed: #{e.class} - #{e.message}")
  end

  def reset_app_org_preference_to_defaults!(preference)
    association_prefix = preference.class.name.underscore
    prefix = preference_prefix

    with_preference_connection(:writing) do
      PreferenceAdoption::CHILD_RECORD_TYPES.each do |type|
        child = preference.public_send("#{association_prefix}_#{type}")
        next unless child

        ensure_model_defaults!(PreferenceClassRegistry.option_class(prefix, type))
        default_id = PreferenceClassRegistry.default_option_id(prefix, type)
        child.update!(option_id: default_id) if child.option_id != default_id
      end

      cookie = preference.public_send("#{association_prefix}_cookie")
      cookie&.update!(
        consented: false,
        functional: false,
        performant: false,
        targetable: false,
        consented_at: nil,
      )

      # Reset clears explicit intent: every field returns to default-seeded state
      # so dynamic region seeding (?ri) applies again until the user sets a value.
      preference.clear_explicit_fields! if preference.respond_to?(:clear_explicit_fields!)
    end
  end

  def existing_resource_preference_for_reset
    return unless respond_to?(:current_resource, true)

    resource = preference_current_resource
    return if resource.blank?

    case preference_class.name
    when "AppPreference" then resource.user_preference
    when "OrgPreference" then resource.staff_preference
    when "ComPreference" then resource.visitor_preference
    end
  end

  def retire_preference_for_reset!(preference)
    now = Time.current
    with_preference_connection(:writing) do
      preference.update!(
        discarded_at: [preference.created_at, now].compact.max,
        purged_at: now + PreferenceBase::REFRESH_TOKEN_TTL,
        status_id: preference_status_class::DELETED,
        token_digest: nil,
        jti: JitSecurityJwtJtiGenerator.generate,
        dbsc_session_id: nil,
      )
    end
  end

  def destroy_resource_preference_for_reset!(resource_pref)
    return if resource_pref.blank?

    preference_connection_class(resource_pref.class).connected_to(role: :writing) do
      destroy_resource_preference_children_for_reset!(resource_pref)
      resource_pref.delete
    end
    reset_current_resource_preference_association(resource_pref)
  end

  def destroy_resource_preference_children_for_reset!(resource_pref)
    resource_preference_child_reflections_for_reset(resource_pref).each do |reflection|
      reflection.klass.where(reflection.foreign_key => resource_pref.id).find_each(&:destroy!)
    end
  end

  def resource_preference_child_reflections_for_reset(resource_pref)
    seen = []

    resource_pref.class.reflect_on_all_associations.filter_map do |reflection|
      next unless reflection.options[:dependent] == :destroy
      next unless reflection.foreign_key

      reflection_key = [reflection.klass.name, reflection.foreign_key]
      next if seen.include?(reflection_key)

      seen << reflection_key
      reflection
    end
  end

  def reset_current_resource_preference_association(resource_pref)
    return unless respond_to?(:current_resource, true)

    resource = preference_current_resource
    return if resource.blank?

    association_name =
      case resource_pref
      when ClientPreference then :user_preference
      when OperatorPreference then :staff_preference
      when VisitorPreference then :visitor_preference
      end
    resource.association(association_name).reset if association_name && resource.respond_to?(association_name)
  end

  def clear_preference_context_cookies!
    preference_context_cookie_names.each do |cookie_name|
      cookies.delete(cookie_name, **preference_cookie_deletion_options)
    end
  end

  def preference_context_cookie_names
    [
      PreferenceIoKeys::Cookies::LANGUAGE,
      PreferenceIoKeys::Cookies::THEME,
      PreferenceIoKeys::Cookies::TIMEZONE,
      PreferenceIoKeys::Cookies::CURRENCY,
      PreferenceIoKeys::Cookies::DATE_FORMAT,
      PreferenceIoKeys::Cookies::TIME_FORMAT,
      PreferenceIoKeys::Cookies::MOTION,
      PreferenceIoKeys::Cookies::DENSITY,
      PreferenceIoKeys::Cookies::PAGE_SIZE,
      PreferenceIoKeys::Cookies::CONSENTED,
      PreferenceIoKeys::Params::RI.to_s,
    ].uniq
  end

  def reset_preference_state
    @preferences = nil
    @preference_payload = nil
    @refresh_token_value = nil
    @refresh_presented_digest = nil
    @refresh_public_id = nil
  end

  def safe_return_to_path
    safe_return_path(params[:return_to])
  end

  def preference_surface_key
    preference_class.name.delete_suffix("Preference").downcase
  end

  def preference_translation_scope
    "acme.#{preference_surface_key}.preferences"
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
