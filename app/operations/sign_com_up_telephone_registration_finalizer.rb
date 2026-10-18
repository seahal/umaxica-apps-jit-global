# typed: false
# frozen_string_literal: true

# Atomically finalizes a pending telephone sign-up for the Com surface.
#
# Mirrors SignAppUpTelephoneRegistrationFinalizer, but operates
# on VisitorTelephone/Visitor instead of ClientTelephone/Client.
#
# Until this runs the telephone stays UNVERIFIED_WITH_SIGN_UP, so an
# abandoned cycle is still collectable by the pending-signup cleanup
# and the phone number can be reused. The durable
# VERIFIED_WITH_SIGN_UP transition and rp_account creation only happen
# here, in one transaction.
class SignComUpTelephoneRegistrationFinalizer
  Result = Data.define(:visitor)

  class << self
    public

    def call(**arguments)
      new(**arguments).call
    end
  end

  public

  def initialize(telephone:, actor_context:, operation_ref:, flow:, session_nonce:)
    unless telephone.is_a?(VisitorTelephone) && flow.is_a?(VisitorSignUpFlow) && operation_ref == flow.public_id
      raise ArgumentError, "COM Telephone signup finalization binding mismatch"
    end

    @telephone = telephone
    @actor_context = actor_context
    @operation_ref = operation_ref
    @flow, @session_nonce = flow, session_nonce
  end

  def call
    visitor = nil

    OpBaseComRecord.connected_to(role: :writing) do
      @flow.with_cycle_lock do
        @flow.reload
        Visitor.connection_class_for_self.connected_to(role: :writing) do
          VisitorTelephone.transaction do
            visitor = Visitor.lock.find(@flow.principal_id)
            raise ActiveRecord::RecordNotSaved, "Contact owner is unavailable" unless visitor.active?

            telephone = VisitorTelephone.lock.find(@telephone.id)
            raise ArgumentError, "telephone sign-up owner mismatch" unless telephone.visitor_id == visitor.id

            ceremony_for(visitor, telephone).with_lock do
              finalize_source(visitor, telephone)
            end
          end
        end
      end
    end

    Result.new(visitor: visitor)
  end

  private

  def ceremony_for(visitor, telephone)
    expected_session = Digest::SHA256.hexdigest(
      JSON.generate(["telephone_sign_up", @flow.public_id, @flow.nonce_digest]),
    )
    matches = VisitorTelephoneCeremonyTransaction.where(
      surface: "com", operation: "sign_up", purpose: "sign_up", actor_ref: visitor.public_id,
      session_ref: expected_session, telephone_candidate_ref: telephone.public_id,
      normalized_number_digest: telephone.number_digest,
    )
    raise ArgumentError, "COM Telephone signup ceremony is unavailable" unless matches.exists?

    @transaction = matches.sole
  end

  def finalize_source(visitor, telephone)
    unless valid_attribution?(visitor)
      raise ArgumentError, "COM Telephone signup actor attribution mismatch"
    end

    retained = telephone.binding_effective?
    telephone.finalize_sign_up_binding!(flow: @flow, transaction: @transaction, session_nonce: @session_nonce)
    if retained
      unless VisitorContactAuditOutbox.exists?(
        operation_ref: @operation_ref, owner_ref: visitor.public_id, contact_ref: telephone.public_id,
        contact_kind: "telephone", event_name: "finalized",
        actor_ref: @actor_context.authenticated? ? @actor_context.subject.public_id : nil,
      )
        raise ArgumentError, "COM Telephone signup committed attribution is unavailable"
      end
    else
      ContactBindingAuditRecorder.call!(
        actor_context: @actor_context, actor: visitor, contact: telephone,
        operation_ref: @operation_ref, event_name: "finalized",
      )
    end
  end

  def valid_attribution?(visitor)
    @actor_context.is_a?(ActorValuesContext) && @actor_context.tld == :com &&
      ((@actor_context.unauthenticated? && @actor_context.subject.equal?(Unauthenticated.instance)) ||
       (@actor_context.actor_type == :visitor && @actor_context.subject == visitor))
  end
end
