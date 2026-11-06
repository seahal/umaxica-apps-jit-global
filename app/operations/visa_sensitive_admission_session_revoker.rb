# frozen_string_literal: true

# Serializes Base RP-session revocation against Auth's O-9 source commit on the Visa-owned
# admission rows. The caller authenticates the Base client and the actor's current Access JWT.
class VisaSensitiveAdmissionSessionRevoker
  class InvalidAuthority < StandardError; end

  class << self
    public

    def call!(actor:, token:, grant:, actor_subject:, grant_sid:, client_id:, rp_session_ref:)
      new(
        actor:, token:, grant:, actor_subject:, grant_sid:, client_id:, rp_session_ref:,
      ).call
    end
  end

  def initialize(actor:, token:, grant:, actor_subject:, grant_sid:, client_id:, rp_session_ref:)
    @actor = actor
    @token = token
    @grant = grant
    @actor_subject = actor_subject
    @grant_sid = grant_sid
    @client_id = client_id
    @rp_session_ref = rp_session_ref
  end

  public

  def call
    validate_record_pair!

    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        raise InvalidAuthority unless actor.login_allowed?

        admission_model.connection_owner.connected_to(role: :writing) do
          admission_model.transaction do
            device_session = token.device_session_record!
            device_session.with_lock do
              token.with_lock do
                grant.with_lock do
                  now = admission_model.database_now
                  validate_locked_authority!(device_session, now)
                  cancel_pending_admissions!(now)
                end
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :actor, :token, :grant, :actor_subject, :grant_sid, :client_id, :rp_session_ref

  def validate_record_pair!
    valid_pair = (actor.is_a?(Client) && token.is_a?(ClientToken) && grant.is_a?(OpAppGrant)) ||
      (actor.is_a?(Operator) && token.is_a?(OperatorToken) && grant.is_a?(OpOrgGrant))
    raise InvalidAuthority unless valid_pair
  end

  def validate_locked_authority!(device_session, now)
    owner_matches =
      case [actor, token, grant]
      in [Client, ClientToken, OpAppGrant]
        token.user_id == actor.id && grant.client_token_id == token.id && client_id == "base-app-ww" &&
        admission_model == ClientVisaSensitiveAdmission
      in [Operator, OperatorToken, OpOrgGrant]
        token.staff_id == actor.id && grant.operator_token_id == token.id && client_id == "base-org-ww" &&
        admission_model == OperatorVisaSensitiveAdmission
      else
        false
      end

    unless owner_matches && token.active_status?(now) && device_session.usable? &&
        device_session.current_refresh_token_id == token.id && grant.device_session_id == device_session.id &&
        grant.oidc_client_id == client_id && grant.public_id == grant_sid && grant.active?(now)
      raise InvalidAuthority
    end
  end

  def cancel_pending_admissions!(now)
    admission_models.each do |model|
      model.where(
        actor_subject: actor_subject,
        grant_sid: grant_sid,
        rp_session_ref: rp_session_ref,
        status: %w(issued browser_confirmed),
      ).order(:id).lock.each do |admission|
        admission.update!(status: "cancelled", updated_at: now)
      end
    end
  end

  def admission_models
    case actor
    when Client then [ClientVisaSensitiveAdmission, ClientVisaSocialLinkAdmission]
    when Operator then [OperatorVisaSensitiveAdmission]
    else raise InvalidAuthority
    end
  end

  def admission_model
    case actor
    when Client then ClientVisaSensitiveAdmission
    when Operator then OperatorVisaSensitiveAdmission
    else raise InvalidAuthority
    end
  end
end
