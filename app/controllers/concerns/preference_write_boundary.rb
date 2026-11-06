# typed: false
# frozen_string_literal: true

# D-54/AC-24 WU-7 slice: the single static write entrance for the Preference domain.
#
# The concern does not own request parsing, cookie emission, or option semantics; each owning
# controller/realm keeps those. What it owns, exclusively, is the *closed* operation enumeration and
# the static surface-to-realm contract every Preference write must pass before any DB writer is
# reached. Refusing an unknown operation here means a later realm must not be able to bypass the
# check by inventing a new operation name at its own controller.
#
# The realm names match the three WU-7 deployables (WU-7 ships com; WU-9 opens app/org through the
# same named operations once their controllers hand over their write paths).
module PreferenceWriteBoundary
  extend ActiveSupport::Concern

  # The set two.md section 4.4 fixes as closed. `save` is Base's own authenticated write, `sign_in`
  # is the Visa one-way reflect, `sign_out` is the Visa rebuild+retire, `reset` is Base's
  # anonymous-row retirement. Anything else is unsupported and must be refused rather than guessed.
  OPERATIONS = %i(save sign_in sign_out reset).freeze
  ANONYMOUS_DISPLAY_TYPES = %i(
    theme language timezone currency date_format time_format motion density page_size
  ).freeze
  ANONYMOUS_STORED_DISPLAY_TYPES = (ANONYMOUS_DISPLAY_TYPES + [:region]).freeze
  COOKIE_CONSENT_FIELDS = %i(consented functional performant targetable).freeze
  REGIONAL_DISPLAY_DEFAULTS = {
    "jp" => { language: "ja", date_format: "iso", time_format: "24", currency: "jpy" }.freeze,
    "us" => { language: "en", date_format: "us", time_format: "12", currency: "usd" }.freeze,
  }.freeze
  ACTOR_PREFERENCE_REALMS = {
    "app" => {
      actor_class: Client,
      preference_class: ClientPreference,
      foreign_key: :client_id,
      status_class: ClientPreferenceStatus,
      prefix: "Client",
    }.freeze,
    "org" => {
      actor_class: Operator,
      preference_class: OperatorPreference,
      foreign_key: :operator_id,
      status_class: OperatorPreferenceStatus,
      prefix: "Operator",
    }.freeze,
  }.freeze

  # Static surface-to-realm map. Keys are the concrete presentation surfaces that can issue a write;
  # values name the realm and the closed operation subset the surface may use. Base owns the
  # actor-persistence writes (`save`, `reset`); Visa owns the sign-in reflection / sign-out rebuild
  # (`sign_in`, `sign_out`). A surface not listed here has no write rights at all.
  SURFACE_REALMS = {
    "base/com" => { realm: :com, operations: %i(save reset) },
    "base/app" => { realm: :app, operations: %i(save reset) },
    "base/org" => { realm: :org, operations: %i(save reset) },
    "visa/app" => { realm: :app, operations: %i(sign_in sign_out) },
    "visa/org" => { realm: :org, operations: %i(sign_in sign_out) },
  }.freeze

  class UnsupportedOperationError < StandardError; end

  class UnsupportedSurfaceError < StandardError; end

  private

  # The caller supplies its verified actor and validated changes, and changes only the yielded row.
  # Signing runs inside the transaction; response cookies are queued only after it commits.
  def write_preference!(operation:, actor:, submitted:, &block)
    return write_visa_preference!(operation:, actor:, submitted:) if %i(sign_in sign_out).include?(operation)

    case preference_class.name
    when "ComPreference"
      write_com_preference!(operation:, actor:, submitted:, &block)
    when "AppPreference", "OrgPreference"
      raise ArgumentError, "anonymous app/org preference writes do not accept callbacks" if block

      write_app_org_preference!(operation:, actor:, submitted:)
    else
      raise UnsupportedSurfaceError, "unsupported Preference writer model: #{preference_class.name}"
    end
  end

  def write_com_preference!(operation:, actor:, submitted:, &block)
    validate_com_write_request!(operation:, actor:, submitted:)
    token = matching_access_token_value
    payload = decode_matching_access_token(token) if token.present?
    public_id = PreferenceToken.extract_public_id(payload)
    issuance = nil
    setting_committed = false

    begin
      with_com_chronicle_transaction do
        with_preference_connection(:writing) do
          preference_class.transaction do
            preference = preference_class.lock.find_by(public_id: public_id) if public_id.present?
            decision_time = preference_class.database_now
            if preference && (!preference.issuance_active_at?(now: decision_time) ||
                              payload.fetch("exp") <= decision_time.to_i ||
                              !preference_access_token_current?(preference, payload))
              preference = nil
            end
            if operation == :reset
              retire_and_audit_com_preference!(preference) if preference
              preference = nil
            end
            preference ||= create_anonymous_com_preference!(decision_time)
            @preferences = preference
            yield(preference, decision_time, submitted) if operation == :save
            rotate_preference_jti!(preference)
            preference.reload
            ensure_preference_option_defaults("Com")
            issuance = prepare_anonymous_com_token(
              preference, build_preferences_payload(preference), issued_at: decision_time,
            )
            raise PreferenceBase::ResolutionError, "preference signing failed" if issuance.nil?

            confirm_com_issuance!(preference, issuance)
          end
        end
        setting_committed = true
      end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished,
           ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, IOError, SystemCallError => e
      log_com_write_failure(e, setting_committed: setting_committed)
      raise PreferenceBase::ResolutionError, "preference persistence failed"
    rescue JitSecurityJwtRegistry::ConfigurationError => e
      raise_preference_resolution_error!(:signing_configuration, e)
    end

    emit_anonymous_com_token!(issuance)
    issuance
  end

  def write_app_org_preference!(operation:, actor:, submitted:)
    context = preference_write_context
    authorization = PreferenceWriteBoundary.authorize_writer!(
      controller: self.class,
      action: action_name,
      surface_key: context.fetch(:surface_key),
      operation: operation,
      realm_model: context.fetch(:preference_model),
    )
    realm = context.fetch(:realm)
    normalized = normalize_anonymous_realm_submission(submitted, operation)
    validate_base_preference_actor!(actor, realm)
    token_payload = decode_base_preference_cookie(context)
    actor_write_requested = operation == :reset ||
      normalized.keys.intersect?(ANONYMOUS_DISPLAY_TYPES + [:region])
    authorize_base_actor_preference_write!(actor, realm) if actor && actor_write_requested

    actor_committed = false
    if actor && actor_write_requested
      actor_committed = write_actor_preference!(actor, realm, normalized, operation)
    end

    binding_value = PreferenceBrowserBinding.mint_value if realm_binding_write?(normalized)
    raw_binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    binding_was_valid = PreferenceBrowserBinding.valid_value?(raw_binding)
    binding_value = raw_binding if realm_binding_write?(normalized) && binding_was_valid
    issuance = nil
    preference_class = context.fetch(:preference_model)

    with_realm_setting_connection(preference_class) do
      preference_class.transaction do
        decision_time = preference_class.database_now
        previous = current_realm_preference_for_write(preference_class, token_payload, decision_time)
        if authorization.fetch(:operation) == :reset
          previous&.retire!
          previous = nil
        end
        preference = previous || create_anonymous_realm_preference!(preference_class, context, decision_time)
        @preferences = preference
        apply_anonymous_realm_submission!(
          preference, normalized, realm, previous:, binding_value:,
                                         binding_was_valid:, decision_time:,
        )
        preference.update!(jti: JitSecurityJwtJtiGenerator.generate)
        issuance = prepare_anonymous_realm_token!(preference, context, decision_time)
        preference.confirm_issuance!(
          issued_at: Time.at(issuance.decoded.fetch("iat")).utc,
          expires_at: issuance.expires_at,
        )
      end
    end

    emit_anonymous_realm_token!(issuance)
    write_browser_binding_cookie(binding_value, expires_at: issuance.expires_at) if binding_value
    clear_retired_preference_cookies!(clear_binding: authorization.fetch(:operation) == :reset)
    issuance
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished,
         ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, IOError, SystemCallError => e
    log_app_org_preference_write_failure(operation, e, actor_committed: actor_committed)
    raise PreferenceBase::ResolutionError, "Preference persistence failed"
  rescue JitSecurityJwtRegistry::ConfigurationError => e
    raise_preference_resolution_error!(:signing_configuration, e)
  end

  def normalize_anonymous_realm_submission(submitted, operation)
    raise ArgumentError, "Preference changes must be an object" unless submitted.is_a?(Hash)
    raise ArgumentError, "reset cannot submit Preference changes" if operation == :reset && submitted.any?
    return {} if operation == :reset
    raise ArgumentError, "unsupported Base Preference operation" unless operation == :save

    values = submitted.to_h.with_indifferent_access
    allowed = ANONYMOUS_DISPLAY_TYPES + [:region, *COOKIE_CONSENT_FIELDS, :web_push]
    unsupported = values.keys.map(&:to_sym) - allowed
    raise ArgumentError, "unsupported Preference fields: #{unsupported.sort.join(", ")}" if unsupported.any?

    normalized = {}
    ANONYMOUS_DISPLAY_TYPES.each do |field|
      next unless values.key?(field)

      value = values.fetch(field)
      allowed_values = SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.fetch(field.to_s)
      raise ArgumentError,
            "invalid #{field} Preference value" unless value.is_a?(String) && allowed_values.include?(value)

      normalized[field] = value
    end

    if values.key?(:region)
      region = values.fetch(:region)
      region = region.downcase if region.is_a?(String)
      regional_defaults =
        REGIONAL_DISPLAY_DEFAULTS.fetch(region) do
          raise ArgumentError, "unsupported Preference region: #{region.inspect}"
        end
      raise ArgumentError, "region save cannot include other Preference fields" if normalized.any? ||
        (values.keys.map(&:to_sym) - [:region]).any?

      normalized[:region] = region
      normalized.merge!(regional_defaults)
    end

    consent_fields = values.keys.map(&:to_sym) & COOKIE_CONSENT_FIELDS
    if consent_fields.any?
      raise ArgumentError,
            "cookie consent requires all four fields" unless consent_fields.sort == COOKIE_CONSENT_FIELDS.sort
      unless COOKIE_CONSENT_FIELDS.all? { |field| [true, false].include?(values.fetch(field)) }
        raise ArgumentError, "cookie consent values must be booleans"
      end

      COOKIE_CONSENT_FIELDS.each { |field| normalized[field] = values.fetch(field) }
    end

    if values.key?(:web_push)
      web_push = values.fetch(:web_push)
      raise ArgumentError, "invalid Web Push option" unless %w(enabled disabled).include?(web_push)

      normalized[:web_push] = web_push
    end

    raise ArgumentError, "empty Preference save" if normalized.empty?

    normalized.freeze
  end

  def validate_base_preference_actor!(actor, realm)
    return if actor.nil?

    config = ACTOR_PREFERENCE_REALMS.fetch(realm)
    return if actor.instance_of?(config.fetch(:actor_class)) && actor.persisted?

    raise UnsupportedSurfaceError, "Base Preference writer actor does not match its realm"
  end

  def authorize_base_actor_preference_write!(actor, realm)
    config = ACTOR_PREFERENCE_REALMS.fetch(realm)
    record = config.fetch(:preference_class).new(
      config.fetch(:foreign_key) => actor.id,
      :status_id => config.fetch(:status_class)::ACTIVE,
    )
    authorize!(record, to: :update?, context: { user: actor })
  end

  def write_actor_preference!(actor, realm, submitted, operation)
    config = ACTOR_PREFERENCE_REALMS.fetch(realm)
    preference_class = config.fetch(:preference_class)
    foreign_key = config.fetch(:foreign_key)
    status_class = config.fetch(:status_class)
    connection_class = actor.class.connection_class_for_self

    changed = false
    connection_class.connected_to(role: :writing) do
      actor.with_lock do
        status_class.ensure_defaults!
        preference = preference_class.lock.find_by(
          foreign_key => actor.id,
          :status_id => status_class::ACTIVE,
        )
        if operation == :reset
          if preference
            preference.retire!
            changed = true
          end
        elsif (values = submitted.slice(*ANONYMOUS_DISPLAY_TYPES, :region)).any?
          preference ||= preference_class.create!(
            foreign_key => actor.id,
            :status_id => status_class::ACTIVE,
            :explicit_fields => [],
          )
          explicit_fields = preference.explicit_field_names

          ensure_actor_preference_children!(preference, config.fetch(:prefix))
          update_actor_preference_children!(preference, config.fetch(:prefix), values)
          preference.update!(explicit_fields: (explicit_fields + values.keys.map(&:to_s)).uniq)
          changed = true
        end
      end
    end
    changed
  end

  def ensure_actor_preference_children!(preference, prefix)
    PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
      option_class = PreferenceClassRegistry.option_class(prefix, type)
      option_class.ensure_defaults!
      record_class = PreferenceClassRegistry.record_class(prefix, type)
      record_class.find_or_create_by!(preference_id: preference.id) do |record|
        record.preference = preference
        record.option_id = PreferenceClassRegistry.default_option_id(prefix, type)
      end
    end
  end

  def update_actor_preference_children!(preference, prefix, values)
    values.each do |type, value|
      option = preference_option_for_wire_value(prefix, type, value)
      record_class = PreferenceClassRegistry.record_class(prefix, type)
      record = record_class.find_by!(preference_id: preference.id)
      record.update!(preference: preference, option_id: option.id)
    end
  end

  def preference_option_for_wire_value(prefix, type, value)
    option_class = PreferenceClassRegistry.option_class(prefix, type)
    preference_option_from_class(option_class, prefix, type, value)
  end

  def preference_option_from_class(option_class, prefix, type, value)
    option_class.ensure_defaults!
    option = option_class.find_each.find { |candidate| candidate.name.to_s.casecmp?(value.to_s) }
    return option if option

    raise ActiveRecord::RecordNotFound, "#{prefix} #{type} option is unavailable"
  end

  def decode_base_preference_cookie(context)
    cookie_name = PreferenceCookieName.anonymous_jwt
    raw_cookie = request.get_header("HTTP_COOKIE").to_s
    matching_names =
      raw_cookie.split(";").filter_map do |part|
        name, = part.strip.split("=", 2)
        name if name == cookie_name
      end
    raise PreferenceBase::ResolutionError, "ambiguous Preference cookie" if matching_names.length > 1

    token = BrowserCredentialCookie.read(cookies, cookie_name)
    return if token.blank?

    PreferenceToken.decode(token, host: request.host, jwt_issuer_id: context.fetch(:issuer_id))
  end

  def realm_binding_write?(submitted)
    (submitted.keys & (COOKIE_CONSENT_FIELDS + [:web_push])).any?
  end

  def apply_anonymous_realm_submission!(preference, submitted, realm, previous:, binding_value:,
                                        binding_was_valid:, decision_time:)
    prefix = realm.capitalize
    display_values = submitted.slice(*ANONYMOUS_DISPLAY_TYPES, :region)
    display_values.each do |field, value|
      option = preference_option_for_wire_value(prefix, field, value)
      PreferenceClassRegistry.record_class(prefix, field).find_by!(preference_id: preference.id)
        .update!(preference: preference, option_id: option.id)
    end

    consent_values = submitted.slice(*COOKIE_CONSENT_FIELDS)
    if consent_values.any?
      enforce_realm_binding_match!(previous, realm, binding_value, binding_was_valid)
      PreferenceClassRegistry.cookie_class(prefix).find_by!(preference_id: preference.id)
        .update!(preference: preference, **consent_values)
      store_realm_consent_receipt!(preference, realm, decision_time)
      store_realm_binding!(preference, realm, binding_value)
    end

    return unless submitted.key?(:web_push)

    enforce_realm_binding_match!(previous, realm, binding_value, binding_was_valid)
    store_realm_web_push!(preference, realm, submitted.fetch(:web_push))
    store_realm_binding!(preference, realm, binding_value)
  end

  def enforce_realm_binding_match!(previous, realm, binding_value, binding_was_valid)
    return unless previous

    binding_class = (realm == "app") ? AppPreferenceBrowserBinding : OrgPreferenceBrowserBinding
    binding = binding_class.find_by(preference_id: previous.id)
    return unless binding
    return if binding_was_valid && PreferenceBrowserBinding.matches?(binding_value, binding.digest)

    raise PreferenceBrowserBinding::MismatchError
  end

  def store_realm_consent_receipt!(preference, realm, decision_time)
    receipt_class = (realm == "app") ? AppPreferenceConsentReceipt : OrgPreferenceConsentReceipt
    receipt = receipt_class.find_or_initialize_by(preference_id: preference.id)
    receipt.update!(preference: preference, version: SecureRandom.uuid, recorded_at: decision_time)
  end

  def store_realm_binding!(preference, realm, raw_value)
    binding_class = (realm == "app") ? AppPreferenceBrowserBinding : OrgPreferenceBrowserBinding
    binding = binding_class.find_or_initialize_by(preference_id: preference.id)
    binding.update!(preference: preference, digest: PreferenceBrowserBinding.digest_for(raw_value))
  end

  def store_realm_web_push!(preference, realm, value)
    record_class = (realm == "app") ? AppPreferenceWebPush : OrgPreferenceWebPush
    option_class = (realm == "app") ? AppPreferenceWebPushOption : OrgPreferenceWebPushOption
    option = preference_option_from_class(option_class, realm.capitalize, :web_push, value)
    record_class.find_by!(preference_id: preference.id).update!(preference: preference, option_id: option.id)
  end

  def clear_retired_preference_cookies!(clear_binding:)
    clear_browser_binding_cookie! if clear_binding
  end

  def log_app_org_preference_write_failure(operation, error, actor_committed:)
    Rails.logger.error(
      JitLogEvent.format(
        actor_committed ? "preference.write.actor_committed_setting_failed" : "preference.write.persistence_failed",
        operation: operation,
        error_class: error.class.name,
        request_id: request.request_id,
      ),
    )
  end

  def write_visa_preference!(operation:, actor:, submitted:)
    context = preference_write_context
    authorization = PreferenceWriteBoundary.authorize_writer!(
      controller: self.class,
      action: action_name,
      surface_key: context.fetch(:surface_key),
      operation: operation,
      realm_model: context.fetch(:preference_model),
    )
    validate_visa_preference_actor!(actor, context.fetch(:realm))
    raise ArgumentError, "Visa Preference writes do not accept request changes" unless submitted == {}

    token_payload = decode_visa_preference_cookie(context)
    actor_snapshot = explicit_actor_preference_snapshot(actor, context.fetch(:realm)) if operation == :sign_in
    preference_class = context.fetch(:preference_model)
    issuance = nil

    with_realm_setting_connection(preference_class) do
      preference_class.transaction do
        decision_time = preference_class.database_now
        previous = current_realm_preference_for_write(preference_class, token_payload, decision_time)
        if authorization.fetch(:operation) == :sign_out
          preference = create_anonymous_realm_preference!(preference_class, context, decision_time)
          copy_realm_preference_state!(previous, preference, context.fetch(:realm)) if previous
          previous&.retire!
        else
          preference = previous || create_anonymous_realm_preference!(preference_class, context, decision_time)
          apply_explicit_actor_snapshot!(preference, actor_snapshot, context.fetch(:realm))
        end

        preference.update!(jti: JitSecurityJwtJtiGenerator.generate)
        issuance = prepare_anonymous_realm_token!(preference, context, decision_time)
        preference.confirm_issuance!(
          issued_at: Time.at(issuance.decoded.fetch("iat")).utc,
          expires_at: issuance.expires_at,
        )
      end
    end

    emit_anonymous_realm_token!(issuance)
    issuance
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished,
         ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, IOError, SystemCallError => e
    log_visa_preference_write_failure(operation, e)
    raise PreferenceBase::ResolutionError, "Preference persistence failed"
  rescue JitSecurityJwtRegistry::ConfigurationError => e
    raise_preference_resolution_error!(:signing_configuration, e)
  end

  def validate_visa_preference_actor!(actor, realm)
    valid_actor =
      case realm
      when "app" then actor.is_a?(Client)
      when "org" then actor.is_a?(Operator)
      else false
      end
    raise UnsupportedSurfaceError, "Visa Preference writer actor does not match its realm" unless
      valid_actor && actor.persisted?
  end

  def decode_visa_preference_cookie(context)
    cookie_name = PreferenceCookieName.anonymous_jwt
    raw_cookie = request.get_header("HTTP_COOKIE").to_s
    matching_names =
      raw_cookie.split(";").filter_map do |part|
        name, = part.strip.split("=", 2)
        name if name == cookie_name
      end
    raise PreferenceBase::ResolutionError, "ambiguous Preference cookie" if matching_names.length > 1

    token = BrowserCredentialCookie.read(cookies, cookie_name)
    return if token.blank?

    PreferenceToken.decode(
      token, host: request.host, jwt_issuer_id: context.fetch(:issuer_id),
    )
  end

  def current_realm_preference_for_write(preference_class, payload, decision_time)
    public_id = PreferenceToken.extract_public_id(payload)
    return if public_id.blank?

    preference = preference_class.lock.find_by(public_id: public_id)
    return unless preference
    return unless preference.issuance_active_at?(now: decision_time)
    return if payload.fetch("exp") <= decision_time.to_i

    token_jti = PreferenceToken.extract_jti(payload)
    return if token_jti.blank? || preference.jti.blank?
    return unless ActiveSupport::SecurityUtils.secure_compare(preference.jti, token_jti)

    preference
  end

  def create_anonymous_realm_preference!(preference_class, context, decision_time)
    issuer_expiry = Time.at(decision_time.to_i + SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_TTL.to_i).utc
    status_class = PreferenceClassRegistry.status_class_for(preference_class)
    status_class.ensure_defaults!
    prefix = context.fetch(:realm).capitalize
    PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
      PreferenceClassRegistry.option_class(prefix, type).ensure_defaults!
    end
    ensure_realm_web_push_defaults!(context.fetch(:realm))

    preference = preference_class.create!(
      status_id: preference_class::ACTIVE_STATUS_ID,
      jti: JitSecurityJwtJtiGenerator.generate,
      last_issued_at: Time.at(decision_time.to_i).utc,
      last_issued_expires_at: issuer_expiry,
    )
    PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
      # Pass the loaded parent: with only the foreign key, each child's required belongs_to validation
      # selects the same preference row again (N+1). Every child writer below follows this rule.
      PreferenceClassRegistry.record_class(prefix, type).create!(
        preference: preference,
        option_id: PreferenceClassRegistry.default_option_id(prefix, type),
      )
    end
    PreferenceClassRegistry.cookie_class(prefix).create!(preference: preference)
    create_realm_web_push_row!(preference, context.fetch(:realm))
    preference
  end

  def ensure_realm_web_push_defaults!(realm)
    case realm
    when "app" then AppPreferenceWebPushOption.ensure_defaults!
    when "org" then OrgPreferenceWebPushOption.ensure_defaults!
    else raise ArgumentError, "unsupported Visa Preference realm: #{realm.inspect}"
    end
  end

  def create_realm_web_push_row!(preference, realm)
    case realm
    when "app"
      AppPreferenceWebPush.create!(preference: preference, option_id: AppPreferenceWebPushOption::DISABLED)
    when "org"
      OrgPreferenceWebPush.create!(preference: preference, option_id: OrgPreferenceWebPushOption::DISABLED)
    else
      raise ArgumentError, "unsupported Visa Preference realm: #{realm.inspect}"
    end
  end

  def explicit_actor_preference_snapshot(actor, realm)
    # Base explicit saves take the same actor lock; read from the owner database after that writer
    # commits so sign-in cannot reflect a lagging replica or a half-applied child set.
    case realm
    when "app"
      ClientPreference.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          preference = ClientPreference.includes(
            client_preference_language: :option,
            client_preference_timezone: :option,
            client_preference_region: :option,
            client_preference_theme: :option,
            client_preference_currency: :option,
            client_preference_date_format: :option,
            client_preference_time_format: :option,
            client_preference_motion: :option,
            client_preference_density: :option,
            client_preference_page_size: :option,
          ).find_by(client_id: actor.id, status_id: ClientPreferenceStatus::ACTIVE)
          preference&.explicit_values || {}.freeze
        end
      end
    when "org"
      OperatorPreference.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          preference = OperatorPreference.includes(
            operator_preference_language: :option,
            operator_preference_timezone: :option,
            operator_preference_region: :option,
            operator_preference_theme: :option,
            operator_preference_currency: :option,
            operator_preference_date_format: :option,
            operator_preference_time_format: :option,
            operator_preference_motion: :option,
            operator_preference_density: :option,
            operator_preference_page_size: :option,
          ).find_by(operator_id: actor.id, status_id: OperatorPreferenceStatus::ACTIVE)
          preference&.explicit_values || {}.freeze
        end
      end
    else
      raise ArgumentError, "unsupported Visa Preference realm: #{realm.inspect}"
    end
  end

  def apply_explicit_actor_snapshot!(preference, snapshot, realm)
    prefix = realm.capitalize
    snapshot.each do |field, value|
      type = anonymous_display_type_for_actor_field(field)
      option = preference_option_for_wire_value(prefix, type, value)

      PreferenceClassRegistry.record_class(prefix, type).find_by!(preference_id: preference.id)
        .update!(preference: preference, option_id: option.id)
    end
  end

  def anonymous_display_type_for_actor_field(field)
    case field
    when "theme" then :theme
    when "language" then :language
    when "timezone" then :timezone
    when "currency" then :currency
    when "date_format" then :date_format
    when "time_format" then :time_format
    when "motion" then :motion
    when "density" then :density
    when "page_size" then :page_size
    else raise ArgumentError, "actor field is not transferable to an anonymous Preference: #{field.inspect}"
    end
  end

  def copy_realm_preference_state!(source, target, realm)
    prefix = realm.capitalize
    ANONYMOUS_STORED_DISPLAY_TYPES.each do |type|
      record_class = PreferenceClassRegistry.record_class(prefix, type)
      source_record = record_class.find_by!(preference_id: source.id)
      target_record = record_class.find_by!(preference_id: target.id)
      target_record.update!(preference: target, option_id: source_record.option_id)
    end

    cookie_class = PreferenceClassRegistry.cookie_class(prefix)
    source_cookie = cookie_class.find_by!(preference_id: source.id)
    target_cookie = cookie_class.find_by!(preference_id: target.id)
    target_cookie.update!(preference: target, **source_cookie.attributes.symbolize_keys.slice(*COOKIE_CONSENT_FIELDS))
    copy_realm_receipt_and_binding!(source, target, realm)
    copy_realm_web_push!(source, target, realm)
  end

  def copy_realm_receipt_and_binding!(source, target, realm)
    case realm
    when "app"
      copy_receipt!(AppPreferenceConsentReceipt, source, target)
      copy_binding!(AppPreferenceBrowserBinding, source, target)
    when "org"
      copy_receipt!(OrgPreferenceConsentReceipt, source, target)
      copy_binding!(OrgPreferenceBrowserBinding, source, target)
    else
      raise ArgumentError, "unsupported Visa Preference realm: #{realm.inspect}"
    end
  end

  def copy_receipt!(receipt_class, source, target)
    receipt = receipt_class.find_by(preference_id: source.id)
    return unless receipt

    receipt_class.create!(preference: target, version: receipt.version, recorded_at: receipt.recorded_at)
  end

  def copy_binding!(binding_class, source, target)
    binding = binding_class.find_by(preference_id: source.id)
    return unless binding

    binding_class.create!(preference: target, digest: binding.digest)
  end

  def copy_realm_web_push!(source, target, realm)
    case realm
    when "app"
      copy_web_push!(AppPreferenceWebPush, source, target)
    when "org"
      copy_web_push!(OrgPreferenceWebPush, source, target)
    else
      raise ArgumentError, "unsupported Visa Preference realm: #{realm.inspect}"
    end
  end

  def copy_web_push!(web_push_class, source, target)
    web_push = web_push_class.find_by(preference_id: source.id)
    return unless web_push

    web_push_class.find_by!(preference_id: target.id).update!(preference: target, option_id: web_push.option_id)
  end

  def prepare_anonymous_realm_token!(preference, context, decision_time)
    snapshot = build_anonymous_realm_snapshot(preference, context.fetch(:realm))
    display = PreferenceDisplayValue.new(snapshot)
    token = PreferenceToken.encode(
      snapshot,
      host: request.host,
      preference_type: context.fetch(:preference_model).name,
      public_id: preference.public_id,
      jti: preference.jti,
      jwt_issuer_id: context.fetch(:issuer_id),
      issued_at: decision_time,
    )
    raise PreferenceBase::ResolutionError, "preference signing failed" if token.blank?

    decoded = PreferenceToken.decode(token, host: request.host, jwt_issuer_id: context.fetch(:issuer_id))
    raise PreferenceBase::ResolutionError, "preference token self-verification failed" if decoded.blank?

    expires_at = Time.at(decoded.fetch("exp")).utc
    validate_anonymous_realm_cookie_sizes!(token, display, expires_at)
    PreferenceWriteResult.new(token:, decoded:, display:, expires_at:)
  end

  def build_anonymous_realm_snapshot(preference, realm)
    prefix = realm.capitalize
    ANONYMOUS_DISPLAY_TYPES.each_with_object({}) do |type, snapshot|
      record = PreferenceClassRegistry.record_class(prefix, type).find_by!(preference_id: preference.id)
      option = PreferenceClassRegistry.option_class(prefix, type).find(record.option_id)
      name = option.name
      raise ActiveRecord::RecordNotFound, "#{realm} #{type} option has no wire name" unless
        name.is_a?(String) && name.present?

      snapshot[type.to_s] = name
    end
  end

  def with_realm_setting_connection(preference_class, &)
    preference_class.connection_class_for_self.connected_to(role: :writing, &)
  end

  def validate_anonymous_realm_cookie_sizes!(token, display, expires_at)
    cookies_to_issue = [
      [PreferenceCookieName.anonymous_jwt, token, true],
      [PreferenceIoKeys::Cookies::LANGUAGE, display.language, false],
      [PreferenceCookieName.anonymous_experience, display.experience, false],
    ]
    cookies_to_issue.each do |name, value, httponly|
      header = Rack::Utils.set_cookie_header(
        name, anonymous_realm_cookie_options(expires_at:, httponly:).merge(value: value),
      )
      if header.bytesize > SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_MAX_BYTES
        raise PreferenceBase::ResolutionError, "anonymous preference cookie exceeds size limit"
      end
    end
  end

  def emit_anonymous_realm_token!(issuance)
    expires_at = issuance.expires_at
    cookies[PreferenceCookieName.anonymous_jwt] =
      anonymous_realm_cookie_options(expires_at:, httponly: true).merge(value: issuance.token)
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] =
      anonymous_realm_cookie_options(expires_at:, httponly: false).merge(value: issuance.display.language)
    cookies[PreferenceCookieName.anonymous_experience] =
      anonymous_realm_cookie_options(expires_at:, httponly: false).merge(value: issuance.display.experience)
  end

  def anonymous_realm_cookie_options(expires_at:, httponly:)
    anonymous_com_cookie_options(expires_at:, httponly:)
  end

  def log_visa_preference_write_failure(operation, error)
    Rails.logger.error(
      JitLogEvent.format(
        "preference.visa_write.failed",
        operation: operation,
        error_class: error.class.name,
        request_id: request.request_id,
      ),
    )
  end

  def validate_com_write_request!(operation:, actor:, submitted:)
    PreferenceWriteBoundary.authorize_writer!(
      controller: self.class, action: action_name, surface_key: "base/com",
      operation: operation, realm_model: preference_class,
    )
    unless actor.equal?(Actor.current) && actor.tld == :com && actor.unauthenticated?
      raise UnsupportedSurfaceError, "com preference writes require the current anonymous com actor"
    end
    raise ArgumentError, "submitted preference changes must be a hash" unless submitted.is_a?(Hash)
    raise ArgumentError, "reset cannot submit preference changes" if operation == :reset && submitted.any?
  end

  def log_com_write_failure(error, setting_committed:)
    event =
      if setting_committed
        "preference.write.setting_committed_audit_failed"
      else
        "preference.write.persistence_failed"
      end
    Rails.logger.error(JitLogEvent.format(event, error_class: error.class.name, request_id: request.request_id))
  end

  def retire_and_audit_com_preference!(preference)
    @preferences = preference
    preference.retire!
    create_audit_log(
      event_id: ComPreferenceChronicleEvent::RESET_BY_USER_DECISION,
      context: { preference_reset: true, rebootstrap: true },
    )
  end

  def with_com_chronicle_transaction(&)
    # A setting rollback must also roll back its creation audit. The two commits remain separate:
    # a Chronicle commit failure after the setting commit cannot be made atomic by nesting them.
    ChronicleRecord.connected_to(role: :writing) do
      ChronicleRecord.transaction(requires_new: true) do
        ComPreferenceChronicle.lock_preference_audit_writers!
        yield
      end
    end
  end

  def create_anonymous_com_preference!(decision_time)
    lifetime = SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_TTL
    expiry = Time.at(decision_time.to_i + lifetime.to_i).utc
    ensure_preference_reference_defaults!
    preference = ComPreference.create!(
      jti: JitSecurityJwtJtiGenerator.generate,
      last_issued_at: Time.at(decision_time.to_i).utc,
      last_issued_expires_at: expiry,
    )
    @preferences = preference
    create_preference_options(preference, {})
    create_audit_log(
      event_id: "CREATE_NEW_PREFERENCE_TOKEN",
      context: { token_created: true },
      expires_at: expiry,
    )
    preference
  end

  def confirm_com_issuance!(preference, issuance)
    preference.confirm_issuance!(
      issued_at: Time.at(issuance.decoded.fetch("iat")).utc,
      expires_at: issuance.expires_at,
    )
  end

  class << self
    public

    def authorize_writer!(controller:, action:, surface_key:, operation:, realm_model:)
      authorization = authorize!(surface_key:, operation:, realm_model:)
      operation = authorization.fetch(:operation)
      allowed_callers = writer_callers(surface_key:, operation:, action:)
      return authorization if allowed_callers.include?(controller)

      raise UnsupportedSurfaceError,
            "#{controller}##{action} is not an authorized #{surface_key} preference writer"
    end

    # Authorize a write against the closed contract. `surface_key` is the string the controller's
    # route authority carries (e.g. "base/com"); `operation` is a Symbol drawn from OPERATIONS.
    # `realm_model` is the concrete Preference model class the surface intends to write.
    def authorize!(surface_key:, operation:, realm_model:)
      surface = SURFACE_REALMS.fetch(surface_key) { raise UnsupportedSurfaceError, surface_key.to_s }
      operation = operation.to_sym
      unless OPERATIONS.include?(operation)
        raise UnsupportedOperationError, "unsupported preference operation: #{operation.inspect}"
      end

      realm =
        if [AppPreference, "AppPreference"].include?(realm_model)
          :app
        elsif [ComPreference, "ComPreference"].include?(realm_model)
          :com
        elsif [OrgPreference, "OrgPreference"].include?(realm_model)
          :org
        end
      unless realm == surface.fetch(:realm)
        raise UnsupportedSurfaceError,
              "surface #{surface_key.inspect} may not write #{realm_model.inspect} preferences"
      end

      unless surface.fetch(:operations).include?(operation)
        raise UnsupportedOperationError,
              "surface #{surface_key.inspect} may not use operation #{operation.inspect}"
      end

      surface.slice(:realm).merge(operation:)
    end

    private

    def writer_callers(surface_key:, operation:, action:)
      case surface_key
      when "base/com" then base_com_writer_callers(operation:, action:)
      when "base/app" then base_app_writer_callers(operation:, action:)
      when "base/org" then base_org_writer_callers(operation:, action:)
      when "visa/app" then visa_app_writer_callers(operation:, action:)
      when "visa/org" then visa_org_writer_callers(operation:, action:)
      else []
      end
    end

    def base_com_writer_callers(operation:, action:)
      return [Base::Com::Preference::CustomizationsController] if operation == :reset && action == "destroy"
      return [] unless operation == :save && action == "update"

      [
        Base::Com::Api::V0::Preferences::CookiesController,
        Base::Com::Api::V0::Preferences::ThemesController,
        Base::Com::Api::V0::Preferences::WebPushesController,
        Base::Com::Preference::CookiesController,
        Base::Com::Preference::ThemesController,
        Base::Com::Preference::CurrenciesController,
        Base::Com::Preference::CalendarsController,
        Base::Com::Preference::ClocksController,
        Base::Com::Preference::MotionsController,
        Base::Com::Preference::DensitiesController,
        Base::Com::Preference::PaginationsController,
        Base::Com::Preference::LanguagesController,
        Base::Com::Preference::TimezonesController,
        Base::Com::Preference::RegionsController,
        Base::Com::Preference::ScreensController,
      ]
    end

    def base_app_writer_callers(operation:, action:)
      return [Base::App::Preference::CustomizationsController] if operation == :reset && action == "destroy"
      return [] unless operation == :save && action == "update"

      [
        Base::App::Api::V0::Preferences::CookiesController,
        Base::App::Api::V0::Preferences::ThemesController,
        Base::App::Api::V0::Preferences::WebPushesController,
        Base::App::Preference::CookiesController,
        Base::App::Preference::ThemesController,
        Base::App::Preference::CurrenciesController,
        Base::App::Preference::CalendarsController,
        Base::App::Preference::ClocksController,
        Base::App::Preference::MotionsController,
        Base::App::Preference::DensitiesController,
        Base::App::Preference::PaginationsController,
        Base::App::Preference::LanguagesController,
        Base::App::Preference::TimezonesController,
        Base::App::Preference::RegionsController,
        Base::App::Preference::ScreensController,
      ]
    end

    def base_org_writer_callers(operation:, action:)
      return [Base::Org::Preference::CustomizationsController] if operation == :reset && action == "destroy"
      return [] unless operation == :save && action == "update"

      [
        Base::Org::Api::V0::Preferences::CookiesController,
        Base::Org::Api::V0::Preferences::ThemesController,
        Base::Org::Api::V0::Preferences::WebPushesController,
        Base::Org::Preference::CookiesController,
        Base::Org::Preference::ThemesController,
        Base::Org::Preference::CurrenciesController,
        Base::Org::Preference::CalendarsController,
        Base::Org::Preference::ClocksController,
        Base::Org::Preference::MotionsController,
        Base::Org::Preference::DensitiesController,
        Base::Org::Preference::PaginationsController,
        Base::Org::Preference::LanguagesController,
        Base::Org::Preference::TimezonesController,
        Base::Org::Preference::RegionsController,
        Base::Org::Preference::ScreensController,
      ]
    end

    def visa_app_writer_callers(operation:, action:)
      return [Visa::App::Oauth::AuthorizationsController] if operation == :sign_in && action == "create"
      return [Visa::App::Oidc::Logouts::ConfirmationsController] if operation == :sign_out && action == "create"

      []
    end

    def visa_org_writer_callers(operation:, action:)
      return [Visa::Org::Oauth::AuthorizationsController] if operation == :sign_in && action == "create"
      return [Visa::Org::Oidc::Logouts::ConfirmationsController] if operation == :sign_out && action == "create"

      []
    end
  end
end
