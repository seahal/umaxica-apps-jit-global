# frozen_string_literal: true

class EmailCredentialRegistrationOtpResendIssuer
  class << self
    public

    def call(**arguments)
      new(**arguments).call
    end
  end

  public

  def initialize(actor:, token:, email:, transaction:, browser_nonce:)
    @actor, @token, @email, @transaction, @browser_nonce = actor, token, email, transaction, browser_nonce
    @surface, @pending_status, @bootstrap_model =
      case [actor, token, email, transaction]
      in [Client, ClientToken, ClientEmail, ClientEmailCeremonyTransaction]
        ["app", ClientEmailStatus::UNVERIFIED, ClientStepUpCeremonyTransaction]
      in [Visitor, VisitorToken, VisitorEmail, VisitorEmailCeremonyTransaction]
        ["com", VisitorEmailStatus::UNVERIFIED, VisitorStepUpCeremonyTransaction]
      else raise ArgumentError, "unsupported Email registration resend realm"
      end
  end

  def call
    expected = CredentialRegistrationOtpSessionValue.for(
      surface: surface, channel: :email, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
    return result(:unavailable) unless transaction.session_ref == expected

    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        transaction.class.connection_owner.connected_to(role: :writing) do
          token_device_session.with_lock do
            token.with_lock do
              email.with_lock do
                resend_under_original_parent(expected)
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :actor, :token, :email, :transaction, :browser_nonce, :surface, :pending_status

  def resend_under_original_parent(expected)
    transaction.reload
    reference = transaction.bootstrap_ceremony_transaction_ref
    return transaction.with_lock { resend_locked(expected) } unless reference

    @bootstrap_parent = @bootstrap_model.find_by(transaction_id: reference)
    return result(:unavailable) unless @bootstrap_parent

    EmailCredentialRegistrationBootstrapGuard.call(
      actor: actor, token: token, bootstrap_transaction: @bootstrap_parent, browser_nonce: browser_nonce,
    ) do |_, session|
      @bootstrap_session = session
      transaction.with_lock { resend_locked(expected) }
    end || result(:unavailable)
  end

  def resend_locked(expected)
    ticket_now = transaction.class.database_now
    source_now = email.class.database_now
    return result(:unavailable) unless source_current?(source_now) && root_current?(ticket_now) &&
      ticket_current?(expected, ticket_now) && original_bootstrap_current?(ticket_now)
    return result(:locked) if email.locked?(now: source_now)
    return result(:rate_limited) if email.otp_cooldown_active?(now: source_now)

    code = transaction.reissue_email_otp!
    email.update!(otp_last_sent_at: source_now)
    EmailCredentialRegistrationOtpIssueResult.new(status: :issued, transaction: transaction, code: code.freeze)
  end

  def original_bootstrap_current?(now)
    return true unless transaction.bootstrap_ceremony_transaction_ref

    @bootstrap_parent&.status == "pending" && @bootstrap_parent.expires_at > now &&
      @bootstrap_session&.status == "PENDING" && @bootstrap_session.discard_at > now
  end

  def source_current?(now)
    owned_pending =
      case actor
      when Client
        token.user_id == actor.id && token_device_session.user_id == actor.id && email.user_id == actor.id &&
        email.user_email_status_id == pending_status
      when Visitor
        token.visitor_id == actor.id && token_device_session.visitor_id == actor.id && email.visitor_id == actor.id &&
        email.visitor_email_status_id == pending_status
      end
    owned_pending && actor.login_allowed? && actor.accessible?(now) && email.accessible?(now) &&
      !email.binding_finalized_at && !email.binding_released?
  end

  def root_current?(now)
    token.currently_usable?(now) && token_device_session.usable? &&
      token_device_session.current_refresh_token_id == token.id
  end

  def token_device_session
    @token_device_session ||= token.device_session_record!
  end

  def ticket_current?(expected, now)
    transaction.surface == surface && transaction.actor_ref == actor.public_id && transaction.session_ref == expected &&
      transaction.operation == "registration" && transaction.purpose == "credential_registration" &&
      transaction.email_candidate_ref == email.public_id &&
      transaction.normalized_email_digest == email.address_digest &&
      transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: now)
  end

  def result(status)
    EmailCredentialRegistrationOtpIssueResult.new(status: status, transaction: nil, code: nil)
  end
end
