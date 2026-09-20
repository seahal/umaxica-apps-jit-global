# typed: false
# frozen_string_literal: true

# Concern for auditing authorization failures
# Records when users/staff attempt unauthorized actions
module AuthorizationAudit
  extend ActiveSupport::Concern

  include CommonRedirect

  private

  def handle_authorization_error(exception)
    # Log the authorization failure
    log_authorization_failure(exception)

    # Respond based on request format
    respond_to do |format|
      format.html do
        flash[:alert] = I18n.t("errors.messages.not_authorized")
        safe_redirect_back_or_to(authorization_failure_fallback_path)
      end
      format.json do
        render json: { error: "Unauthorized" }, status: :forbidden
      end
    end
  end

  def log_authorization_failure(exception)
    actor = authorization_audit_actor
    return unless actor

    log_data = build_log_data(actor, exception)

    # Log the authorization failure event
    Rails.logger.info(JitLogEvent.format("authorization.failure", log_data))

    create_audit_record(actor, log_data)
  rescue StandardError => e
    # Don't let audit logging break the application
    Rails.logger.error(
      JitLogEvent.format(
        "authorization.failure_log.failed", error_class: e.class.name,
                                            message: e.message,
      ),
    )
  end

  def authorization_failure_fallback_path
    return root_path if respond_to?(:root_path)

    "/"
  end

  def build_log_data(actor, exception)
    {
      actor_type: actor.class.name,
      actor_id: audit_identifier(actor),
      actor_state: defined?(Actor) ? Actor.whoami : nil,
      login_public_id: defined?(Actor) ? Actor.authn.login_public_id : nil,
      action: action_name,
      controller: controller_name,
      # ActionPolicy::Unauthorized carries the policy class and rule, not the authorized record.
      policy: exception.policy.name,
      query: exception.rule,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      request_id: request.respond_to?(:request_id) ? request.request_id : nil,
      trace_id: defined?(Actor) ? Actor.trace_id : nil,
      span_id: defined?(Actor) ? Actor.span_id : nil,
      timestamp: Time.current,
    }.compact
  end

  # Denials usually happen on GET requests, which run on the reading role, so the chronicle
  # write needs the writing role explicitly.
  def create_audit_record(actor, log_data)
    ChronicleRecord.connected_to(role: :writing) do
      if actor.is_a?(Client)
        create_user_authorization_audit(actor, log_data)
      elsif actor.is_a?(Operator)
        create_staff_authorization_audit(actor, log_data)
      elsif defined?(Visitor) && actor.is_a?(Visitor)
        create_visitor_authorization_audit(actor, log_data)
      end
    end
  end

  def create_user_authorization_audit(user, log_data)
    audit = ClientChronicle.new(
      actor: user,
      event_id: ClientChronicleEvent::AUTHORIZATION_FAILED,
      ip_address: log_data[:ip_address],
      occurred_at: log_data[:timestamp],
    )
    audit.user = user
    audit.save!
  rescue ActiveRecord::RecordInvalid => e
    # Event ID might not exist in the database yet
    # ActiveRecord::RecordInvalid#message quotes the offending values, and
    # "error_message" is not matched by ObservabilityRedactor::SENSITIVE_KEY_PATTERN,
    # so it would reach the log unredacted. Attribute names carry the same
    # diagnostic value without the values themselves.
    Rails.logger.info(
      JitLogEvent.format(
        "authorization.audit.user_creation_failed",
        error_class: e.class.name,
        invalid_attributes: e.record&.errors&.attribute_names,
      ),
    )
  end

  def create_staff_authorization_audit(staff, log_data)
    audit = OperatorChronicle.new(
      actor: staff,
      event_id: OperatorChronicleEvent::AUTHORIZATION_FAILED,
      ip_address: log_data[:ip_address],
      occurred_at: log_data[:timestamp],
    )
    audit.staff = staff
    audit.save!
  rescue ActiveRecord::RecordInvalid => e
    # Event ID might not exist in the database yet
    # ActiveRecord::RecordInvalid#message quotes the offending values, and
    # "error_message" is not matched by ObservabilityRedactor::SENSITIVE_KEY_PATTERN,
    # so it would reach the log unredacted. Attribute names carry the same
    # diagnostic value without the values themselves.
    Rails.logger.info(
      JitLogEvent.format(
        "authorization.audit.staff_creation_failed",
        error_class: e.class.name,
        invalid_attributes: e.record&.errors&.attribute_names,
      ),
    )
  end

  def create_visitor_authorization_audit(visitor, log_data)
    audit = ClientChronicle.new(
      actor: visitor,
      actor_id: visitor.id,
      actor_type: visitor.class.name,
      subject_id: visitor.id.to_s,
      subject_type: visitor.class.name,
      event_id: ClientChronicleEvent::AUTHORIZATION_FAILED,
      ip_address: log_data[:ip_address],
      occurred_at: log_data[:timestamp],
    )
    audit.context = { request_id: log_data[:request_id],
                      trace_id: log_data[:trace_id], }.compact if audit.respond_to?(:context=)
    audit.save!
  rescue ActiveRecord::RecordInvalid => e
    # ActiveRecord::RecordInvalid#message quotes the offending values, and
    # "error_message" is not matched by ObservabilityRedactor::SENSITIVE_KEY_PATTERN,
    # so it would reach the log unredacted. Attribute names carry the same
    # diagnostic value without the values themselves.
    Rails.logger.info(
      JitLogEvent.format(
        "authorization.audit.visitor_creation_failed",
        error_class: e.class.name,
        invalid_attributes: e.record&.errors&.attribute_names,
      ),
    )
  end

  def authorization_audit_actor
    legacy_actor = current_client_or_staff

    if defined?(Actor) && Actor.authenticated?
      actor = Actor.actor
      return actor if usable_authorization_audit_actor?(actor, legacy_actor)
    end

    legacy_actor
  end

  def usable_authorization_audit_actor?(actor, legacy_actor)
    return false if actor.blank?
    return false if defined?(Unauthenticated) && actor.equal?(Unauthenticated.instance)
    return true if legacy_actor.blank?

    actor == legacy_actor
  end

  def audit_identifier(record)
    return if record.blank?
    return record.public_id if record.respond_to?(:public_id) && record.public_id.present?

    record.id if record.respond_to?(:id)
  end

  def current_client_or_staff
    return current_client if respond_to?(:current_client) && current_client
    return current_user if respond_to?(:current_user) && current_user

    # Try current_operator (for Operator controllers)
    return current_operator if respond_to?(:current_operator) && current_operator
    return current_visitor if respond_to?(:current_visitor) && current_visitor

    nil
  end

  def current_user_or_staff = current_client_or_staff
end
