# frozen_string_literal: true

class TelephoneCredentialRegistrationOtpFinalizer
  class DependencyFailure < StandardError; end

  class << self
    public

    def call!(**arguments)
      new(**arguments).call!
    end
  end

  public

  def initialize(actor:, actor_context:, token:, telephone:, transaction:, browser_nonce:, requirement:, code:,
                 step_up_evidence: nil)
    @actor, @actor_context, @token, @telephone = actor, actor_context, token, telephone
    @transaction, @browser_nonce, @requirement, @code = transaction, browser_nonce, requirement, code
    @step_up_evidence = step_up_evidence
    @surface, @policy_model, @audit_model =
      case [actor, token, telephone, transaction]
      in [Client, ClientToken, ClientTelephone, ClientTelephoneCeremonyTransaction]
        ["app", ClientTelephonePolicy, ClientContactAuditOutbox]
      else raise ArgumentError, "unsupported Telephone registration finalization realm"
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

            telephone.with_lock do
              case consume_ticket_result!
              when :committed
                :finalized
              when :consumed
                unless finalize_source!
                  raise IdentityTelephoneCeremony::Error,
                        "Telephone Source finalization refused after Ticket consumption"
                end

                :finalized
              else
                :unavailable
              end
            end
          end
        end
      end

    if actor.is_a?(Client) && telephone.user_id == actor.id
      AppRegisteredContactDestinationGuard.with_available_destination(contact: telephone, owner: actor, &finalize)
    else
      finalize.call
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    raise DependencyFailure, "Telephone registration storage is unavailable: #{e.class}"
  end

  private

  attr_reader :actor, :actor_context, :token, :telephone, :transaction, :browser_nonce, :requirement, :code,
              :surface, :policy_model, :audit_model, :step_up_evidence

  def consume_ticket_result!
    transaction.class.connection_owner.connected_to(role: :writing) do
      transaction.class.transaction do
        token_device_session.with_lock do
          token.with_lock do
            transaction.with_lock { consume_ticket_result_locked! }
          end
        end
      end
    end
  end

  def consume_ticket_result_locked!
    now = transaction.class.database_now
    return :unavailable unless original_authority?(now) && current_policy_matches?

    if transaction.consumed?
      return :committed if telephone.binding_effective? && committed_provenance?

      return :unavailable
    end
    return :unavailable if telephone.binding_effective? || telephone.binding_finalized_at || telephone.binding_released?

    consumption_now = transaction.class.database_now
    return :unavailable unless original_authority?(consumption_now) && current_policy_matches? &&
      StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token)

    transaction.consume_registration_result!
    unless root_current?(transaction.consumed_at)
      raise IdentityTelephoneCeremony::Error.new(
        "Telephone registration Root expired before Ticket consumption committed", code: "transaction_unavailable",
      )
    end
    :consumed
  end

  def finalize_source!
    now = transaction.class.database_now
    return false unless original_authority?(now) && current_policy_matches?
    return committed_provenance? if telephone.binding_effective?
    return false if telephone.binding_finalized_at || telephone.binding_released?

    previous = previous_bindings.lock.to_a
    return false unless transaction.consumed?

    previous.each do |binding|
      binding.release_binding!
      record_audit!(binding, "released")
    end
    telephone.finalize_registration_binding!(transaction: transaction, code: code, session_ref: session_ref)
    record_audit!(telephone, "finalized")
    # The Step-Up was consumed in Ticket before Source finalization.
    true
  end

  def original_authority?(now)
    source_now = telephone.class.database_now
    return false unless actor.login_allowed? && actor.accessible?(source_now) && telephone.accessible?(source_now) &&
      source_owned? && actor_context_matches? && ticket_root_authority_current?(now)
    return false unless transaction.surface == surface &&
      transaction.normalized_number_digest == telephone.number_digest && transaction.session_ref == session_ref

    transaction.telephone_registration_otp_evidence?(
      code: code, actor_ref: actor.public_id, session_ref: session_ref, candidate_ref: telephone.public_id,
    )
  end

  def session_ref
    CredentialRegistrationOtpSessionValue.for(
      surface: surface, channel: :telephone, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
  end

  def source_owned?
    case actor
    when Client
      token.user_id == actor.id && token_device_session.user_id == actor.id && telephone.user_id == actor.id
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
      requirement.to_h == policy_model.new(
        telephone,
        user: actor,
      ).credential_registration_requirement(token: token).to_h
  end

  def previous_bindings
    case actor
    when Client then ClientTelephone.where(user_id: actor.id).effective_binding.where.not(id: telephone.id)
    end
  end

  def committed_provenance?
    !telephone.binding_released? && audit_model.exists?(
      operation_ref: transaction.transaction_id, owner_ref: actor.public_id, actor_ref: actor.public_id,
      contact_ref: telephone.public_id, contact_kind: "telephone", event_name: "finalized",
    )
  end

  def record_audit!(subject, event_name)
    ContactBindingAuditRecorder.call!(
      actor_context: actor_context, actor: actor, contact: subject,
      operation_ref: transaction.transaction_id, event_name: event_name,
    )
  end
end
