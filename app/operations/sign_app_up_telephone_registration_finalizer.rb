# typed: false
# frozen_string_literal: true

# Atomically finalizes a pending telephone sign-up.
#
# Until this runs the telephone stays UNVERIFIED_WITH_SIGN_UP, so an
# abandoned cycle (OTP passed but passkey never completed) is still
# collectable by the pending-signup cleanup and the phone number can be
# reused. The durable VERIFIED_WITH_SIGN_UP transition, client promotion,
# and account creation only happen here, in one transaction, after the
# required passkey exists.
#
# See adr/sign-up-authentication-handoff-and-social-rt.md (telephone
# finalization is durable only after required Sign Up setup succeeds).
class SignAppUpTelephoneRegistrationFinalizer
  Result = Data.define(:user)

  # Raised when finalization is attempted before the required passkey
  # exists. This is a guard, not an expected path.
  class PasskeyMissingError < StandardError; end

  class << self
    public

    def call(**arguments)
      new(**arguments).call
    end
  end

  public

  def initialize(telephone:, actor_context:, operation_ref:, flow:, session_nonce:)
    unless telephone.is_a?(ClientTelephone) && flow.is_a?(ClientSignUpFlow) && operation_ref == flow.public_id
      raise ArgumentError, "APP Telephone signup finalization binding mismatch"
    end

    @telephone = telephone
    @actor_context = actor_context
    @operation_ref = operation_ref
    @flow, @session_nonce = flow, session_nonce
  end

  def call
    user = nil

    AppTicketRecord.connected_to(role: :writing) do
      @flow.with_cycle_lock do
        @flow.reload
        Client.connection_class_for_self.connected_to(role: :writing) do
          ClientTelephone.transaction do
            user = Client.lock.find(@flow.principal_id)
            raise ActiveRecord::RecordNotSaved, "Contact owner is unavailable" unless user.active?

            telephone = ClientTelephone.lock.find(@telephone.id)
            raise ArgumentError, "telephone sign-up owner mismatch" unless telephone.user_id == user.id

            passkey = user.client_passkeys.active.lock.first
            unless passkey&.accessible?(ClientPasskey.database_now)
              raise PasskeyMissingError, "telephone sign-up requires an active passkey"
            end

            ceremony_for(user, telephone).with_lock do
              finalize_source(user, telephone)
            end
          end
        end
      end
    end

    Result.new(user: user)
  end

  private

  def ceremony_for(user, telephone)
    expected_session = Digest::SHA256.hexdigest(
      JSON.generate(["telephone_sign_up", @flow.public_id, @flow.nonce_digest]),
    )
    matches = ClientTelephoneCeremonyTransaction.where(
      surface: "app", operation: "sign_up", purpose: "sign_up", actor_ref: user.public_id,
      session_ref: expected_session, telephone_candidate_ref: telephone.public_id,
      normalized_number_digest: telephone.number_digest,
    )
    raise ArgumentError, "APP Telephone signup ceremony is unavailable" unless matches.exists?

    @transaction = matches.sole
  end

  def finalize_source(user, telephone)
    unless valid_attribution?(user)
      raise ArgumentError, "APP Telephone signup actor attribution mismatch"
    end

    retained = telephone.binding_effective?
    telephone.finalize_sign_up_binding!(flow: @flow, transaction: @transaction, session_nonce: @session_nonce)
    user.finalize_telephone_sign_up!(telephone: telephone, flow: @flow)
    if retained
      unless ClientContactAuditOutbox.exists?(
        operation_ref: @operation_ref, owner_ref: user.public_id, contact_ref: telephone.public_id,
        contact_kind: "telephone", event_name: "finalized",
        actor_ref: @actor_context.authenticated? ? @actor_context.subject.public_id : nil,
      )
        raise ArgumentError, "APP Telephone signup committed attribution is unavailable"
      end
    else
      ContactBindingAuditRecorder.call!(
        actor_context: @actor_context, actor: user, contact: telephone,
        operation_ref: @operation_ref, event_name: "finalized",
      )
    end
  end

  def valid_attribution?(user)
    @actor_context.is_a?(ActorValuesContext) && @actor_context.tld == :app &&
      ((@actor_context.unauthenticated? && @actor_context.subject.equal?(Unauthenticated.instance)) ||
       (@actor_context.actor_type == :client && @actor_context.subject == user))
  end
end
