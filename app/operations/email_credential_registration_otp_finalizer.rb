# frozen_string_literal: true

class EmailCredentialRegistrationOtpFinalizer
  class DependencyFailure < StandardError; end

  class << self
    public

    def call!(**arguments)
      new(**arguments).call!
    end

    def bootstrap_receipt_recoverable?(**arguments)
      new(**arguments).bootstrap_receipt_recoverable?
    end
  end

  public

  def initialize(actor:, actor_context:, token:, email:, transaction:, browser_nonce:, requirement:, code:,
                 step_up_evidence: nil, bootstrap_transaction: nil)
    @actor, @actor_context, @token, @email = actor, actor_context, token, email
    @transaction, @browser_nonce, @requirement, @code = transaction, browser_nonce, requirement, code
    @step_up_evidence = step_up_evidence
    @bootstrap_transaction = bootstrap_transaction
    @surface, @policy_model, @audit_model =
      case [actor, token, email, transaction]
      in [Client, ClientToken, ClientEmail, ClientEmailCeremonyTransaction]
        ["app", ClientEmailPolicy, ClientContactAuditOutbox]
      else raise ArgumentError, "unsupported Email registration finalization realm"
      end
  end

  def call!
    return :unavailable unless browser_nonce.is_a?(String) && browser_nonce.encoding.ascii_compatible? &&
      browser_nonce.valid_encoding? && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

    finalize =
      lambda do
        actor.class.connection_class_for_self.connected_to(role: :writing) do
          actor.with_lock do
            next :unavailable unless actor.active?

            email.with_lock do
              case consume_ticket_result!
              when :committed
                :finalized
              when :consumed
                unless finalize_source!
                  raise IdentityEmailCeremonyContract::Error,
                        "Email Source finalization refused after Ticket consumption"
                end

                :finalized
              else
                :unavailable
              end
            end
          end
        end
      end

    if actor.is_a?(Client) && email.user_id == actor.id
      AppRegisteredContactDestinationGuard.with_available_destination(contact: email, owner: actor, &finalize)
    else
      finalize.call
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    raise DependencyFailure, "Email registration storage is unavailable: #{e.class}"
  end

  def bootstrap_receipt_recoverable?
    return false unless bootstrap_transaction && valid_browser_nonce?

    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        email.with_lock do
          transaction.class.connection_owner.connected_to(role: :writing) do
            transaction.class.transaction do
              token_device_session.with_lock do
                token.with_lock do
                  EmailCredentialRegistrationBootstrapGuard.call(
                    actor: actor, token: token, bootstrap_transaction: bootstrap_transaction,
                    browser_nonce: browser_nonce, credential_ref: email.public_id, receipt: true,
                  ) do
                    transaction.with_lock do
                      now = transaction.class.database_now
                      original_binding?(now) && current_policy_matches? && bounded_consumed_receipt?(now) &&
                        email.binding_effective? && committed_provenance?
                    end
                  end || false
                end
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :actor, :actor_context, :token, :email, :transaction, :browser_nonce, :requirement, :code,
              :surface, :policy_model, :audit_model, :step_up_evidence, :bootstrap_transaction

  def consume_ticket_result!
    transaction.class.connection_owner.connected_to(role: :writing) do
      transaction.class.transaction do
        token_device_session.with_lock do
          token.with_lock do
            if bootstrap_transaction
              unless transaction.bootstrap_ceremony_transaction_ref == bootstrap_transaction.transaction_id
                next :unavailable
              end

              EmailCredentialRegistrationBootstrapGuard.call(
                actor: actor, token: token, bootstrap_transaction: bootstrap_transaction,
                browser_nonce: browser_nonce, credential_ref: email.public_id,
                receipt: transaction.consumed?,
              ) do
                transaction.with_lock { consume_ticket_result_locked! }
              end || :unavailable
            else
              transaction.with_lock { consume_ticket_result_locked! }
            end
          end
        end
      end
    end
  end

  def consume_ticket_result_locked!
    now = transaction.class.database_now
    return :unavailable unless original_authority?(now) && current_policy_matches?

    if transaction.consumed?
      return :committed if email.binding_effective? && committed_provenance?

      return :unavailable
    end
    return :unavailable if email.binding_effective? || email.binding_finalized_at || email.binding_released?

    consumption_now = transaction.class.database_now
    return :unavailable unless original_authority?(consumption_now) && current_policy_matches?
    return :unavailable unless bootstrap_transaction || StepUpEvidenceVerifier.call(
      evidence: step_up_evidence, actor: actor, token: token,
    )

    bootstrap_transaction&.consume_email_registration!(registered_credential_ref: email.public_id)
    transaction.consume_registration_result!
    unless root_current?(transaction.consumed_at)
      raise IdentityEmailCeremonyContract::Error.new(
        "Email registration Root expired before Ticket consumption committed", code: "transaction_unavailable",
      )
    end
    :consumed
  end

  def finalize_source!
    now = transaction.class.database_now
    return false unless original_authority?(now) && current_policy_matches?
    return committed_provenance? if email.binding_effective?
    return false if email.binding_finalized_at || email.binding_released?

    previous = previous_bindings.lock.to_a
    return false unless transaction.consumed?

    previous.each do |binding|
      binding.release_binding!
      record_audit!(binding, "released")
    end
    email.finalize_registration_binding!(transaction: transaction, code: code, session_ref: transaction.session_ref)
    record_audit!(email, "finalized")
    # The Step-Up (or bootstrap authority) was consumed in Ticket before Source finalization.
    true
  end

  def original_authority?(now)
    return false unless original_binding?(now)

    transaction.email_registration_otp_evidence?(
      code: code, actor_ref: actor.public_id, session_ref: transaction.session_ref, candidate_ref: email.public_id,
    )
  end

  def original_binding?(now)
    source_now = email.class.database_now
    return false unless actor.login_allowed? && actor.accessible?(source_now) && email.accessible?(source_now) &&
      source_owned? && actor_context_matches? && ticket_root_authority_current?(now)

    expected = CredentialRegistrationOtpSessionValue.for(
      surface: surface, channel: :email, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
    transaction.surface == surface && transaction.normalized_email_digest == email.address_digest &&
      transaction.actor_ref == actor.public_id && transaction.email_candidate_ref == email.public_id &&
      transaction.operation == "registration" && transaction.purpose == "credential_registration" &&
      transaction.session_ref == expected && original_bootstrap_matches?(now)
  end

  def bounded_consumed_receipt?(now)
    transaction.consumed? && transaction.consumed_at <= now && transaction.expires_at > now &&
      transaction.otp_cancelled_at.nil? && transaction.otp_consumed_at && transaction.otp_consumed_at <= now &&
      transaction.otp_result_expires_at && transaction.otp_result_expires_at > now &&
      transaction.otp_receipt_verifier.is_a?(String) && transaction.otp_receipt_verifier.match?(/\A[0-9a-f]{64}\z/)
  end

  def original_bootstrap_matches?(now)
    return false unless transaction.bootstrap_ceremony_transaction_ref == bootstrap_transaction&.transaction_id
    return true unless bootstrap_transaction

    return bootstrap_transaction.expires_at > now if bootstrap_transaction.status == "pending"
    return false unless transaction.consumed? && bootstrap_transaction.consumed?

    bootstrap_transaction.consumed_at <= bootstrap_transaction.expires_at &&
      bootstrap_transaction.verified_credential_ref == email.public_id &&
      bootstrap_transaction[:method] == "email_otp"
  end

  def valid_browser_nonce?
    browser_nonce.is_a?(String) && browser_nonce.encoding.ascii_compatible? &&
      browser_nonce.valid_encoding? && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)
  end

  def source_owned?
    case actor
    when Client
      token.user_id == actor.id && token_device_session.user_id == actor.id && email.user_id == actor.id
    end
  end

  def root_current?(now)
    token.active_status?(now) && token_device_session.usable? &&
      token.device_session_id == token_device_session.id && token_device_session.current_refresh_token_id == token.id
  end

  def ticket_root_authority_current?(now)
    return root_current?(now) unless transaction.consumed?

    transaction.consumed_at <= now
  end

  def token_device_session
    @token_device_session ||= token.device_session_record!
  end

  def actor_context_matches?
    actor_context.is_a?(ActorValuesContext) && actor_context.subject == actor &&
      actor_context.tld.to_s == surface && actor_context.surface == :base &&
      actor_context.actor_type == :client
  end

  def current_policy_matches?
    requirement.is_a?(StepUpRequirement) &&
      requirement.to_h == policy_model.new(email, user: actor).credential_registration_requirement(token: token).to_h
  end

  def previous_bindings
    case actor
    when Client then actor.client_emails.effective_binding.where.not(id: email.id)
    end
  end

  def committed_provenance?
    !email.binding_released? && audit_model.exists?(
      operation_ref: transaction.transaction_id, owner_ref: actor.public_id, actor_ref: actor.public_id,
      contact_ref: email.public_id, contact_kind: "email", event_name: "finalized",
    )
  end

  def record_audit!(subject, event_name)
    ContactBindingAuditRecorder.call!(
      actor_context: actor_context, actor: actor, contact: subject,
      operation_ref: transaction.transaction_id, event_name: event_name,
    )
  end
end
