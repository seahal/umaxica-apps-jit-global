# frozen_string_literal: true

class TelephoneCredentialRegistrationOtpDeliveryGuard
  class << self
    public

    def call(**arguments, &)
      raise ArgumentError, "Telephone registration delivery requires a transport block" unless block_given?

      new(**arguments).call(&)
    end
  end

  public

  def initialize(transaction:, telephone:, generation:, destination:, code:)
    @transaction, @telephone, @generation, @destination, @code = transaction, telephone, generation, destination, code
    @owner_model, @token_model, @pending_status, @surface =
      case [transaction, telephone]
      in [ClientTelephoneCeremonyTransaction, ClientTelephone]
        [Client, ClientToken, ClientTelephoneStatus::UNVERIFIED, "app"]
      in [VisitorTelephoneCeremonyTransaction, VisitorTelephone]
        [Visitor, VisitorToken, VisitorTelephoneStatus::UNVERIFIED, "com"]
      in [OperatorTelephoneCeremonyTransaction, OperatorTelephone]
        [Operator, OperatorToken, OperatorTelephoneStatus::UNVERIFIED, "org"]
      else raise ArgumentError, "unsupported Telephone registration delivery realm"
      end
    @root_ref = CredentialRegistrationOtpSessionValue.load(session_ref: transaction.session_ref).root_ref
  end

  def call
    owner_model.connection_class_for_self.connected_to(role: :writing) do
      owner = owner_model.find_by(public_id: transaction.actor_ref)
      next false unless owner

      owner.with_lock do
        transaction.class.connection_owner.connected_to(role: :writing) do
          token = token_model.find_by(public_id: root_ref)
          next false unless token

          token.device_session.with_lock do
            token.with_lock do
              telephone.with_lock do
                transaction.with_lock do
                  next false unless current_source?(owner, token) && current_ticket?(owner, token)

                  transaction.deliver_telephone_otp!(generation: generation, code: code) { yield }
                end
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :transaction, :telephone, :generation, :destination, :code, :owner_model, :token_model,
              :pending_status, :root_ref, :surface

  def current_source?(owner, token)
    owned_pending =
      case telephone
      when ClientTelephone
        telephone.user_id == owner.id && token.user_id == owner.id && token.device_session.user_id == owner.id &&
        telephone.user_telephone_status_id == pending_status
      when VisitorTelephone
        telephone.visitor_id == owner.id && token.visitor_id == owner.id &&
        token.device_session.visitor_id == owner.id &&
        telephone.visitor_telephone_status_id == pending_status
      when OperatorTelephone
        telephone.staff_id == owner.id && token.staff_id == owner.id && token.device_session.staff_id == owner.id &&
        telephone.staff_telephone_status_id == pending_status
      end
    now = telephone.class.database_now
    owned_pending && owner.login_allowed? && owner.accessible?(now) && source_pending?(now)
  end

  def source_pending?(now)
    case telephone
    when ClientTelephone, VisitorTelephone
      telephone.accessible?(now) && !telephone.binding_finalized_at && !telephone.binding_released?
    when OperatorTelephone then telephone.staff_telephone_status_id == pending_status
    end
  end

  def candidate_ref
    case telephone
    when ClientTelephone, VisitorTelephone then telephone.public_id
    when OperatorTelephone then telephone.id.to_s
    end
  end

  def current_ticket?(owner, token)
    now = transaction.class.database_now
    bound_root = CredentialRegistrationOtpSessionValue.load(session_ref: transaction.session_ref).root_ref
    return false unless bound_root == token.public_id && token.currently_usable?(now) && token.device_session.usable? &&
      token.device_session.current_refresh_token_id == token.id
    return false unless transaction.surface == surface && transaction.operation == "registration" &&
      transaction.purpose == "credential_registration" && transaction.actor_ref == owner.public_id &&
      transaction.telephone_candidate_ref == candidate_ref &&
      transaction.normalized_number_digest == telephone.number_digest
    unless destination.is_a?(String) && destination.encoding.ascii_compatible? && destination.valid_encoding?
      return false
    end

    IdentifierBlindIndex.bidx_for_telephone(destination, realm: surface) == telephone.number_digest
  end
end
