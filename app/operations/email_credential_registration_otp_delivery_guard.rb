# frozen_string_literal: true

class EmailCredentialRegistrationOtpDeliveryGuard
  class << self
    public

    def call(**arguments, &)
      raise ArgumentError, "Email registration delivery requires a transport block" unless block_given?

      new(**arguments).call(&)
    end
  end

  public

  def initialize(transaction:, email:, generation:, destination:, code:)
    @transaction, @email, @generation, @destination, @code = transaction, email, generation, destination, code
    @owner_model, @token_model, @pending_status,
      @bootstrap_model, @bootstrap_session_model, @admission_model, @catalog =
      case [transaction, email]
      in [ClientEmailCeremonyTransaction, ClientEmail]
        [Client, ClientToken, ClientEmailStatus::UNVERIFIED, ClientStepUpCeremonyTransaction,
         ClientStepUpSession, ClientAuthAdmissionBinding, StepUpScopeCatalog::APP,]
      in [VisitorEmailCeremonyTransaction, VisitorEmail]
        [Visitor, VisitorToken, VisitorEmailStatus::UNVERIFIED, VisitorStepUpCeremonyTransaction,
         VisitorStepUpSession, VisitorAuthAdmissionBinding, StepUpScopeCatalog::COM,]
      in [OperatorEmailCeremonyTransaction, OperatorEmail]
        [Operator, OperatorToken, OperatorEmailStatus::UNVERIFIED, nil, nil, nil, nil]
      else raise ArgumentError, "unsupported Email registration delivery realm"
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
              email.with_lock do
                with_original_parent(owner, token) do |parent, session, binding|
                  transaction.with_lock do
                    next false unless current_source?(owner, token) && current_ticket?(owner, token) &&
                      transaction.bootstrap_ceremony_transaction_ref == parent&.transaction_id

                    transaction.deliver_email_otp!(generation: generation, code: code) do
                      if parent
                        now = bootstrap_model.database_now
                        return false unless delivery_parent_current?(parent, owner, token, now) &&
                          delivery_parent_binding_current?(parent, session, binding, token, now)
                      end

                      yield
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :transaction, :email, :generation, :destination, :code, :owner_model, :token_model, :pending_status,
              :root_ref, :bootstrap_model, :bootstrap_session_model, :admission_model, :catalog

  def with_original_parent(owner, token)
    reference = transaction.bootstrap_ceremony_transaction_ref
    return yield(nil) unless reference
    return false if transaction.is_a?(OperatorEmailCeremonyTransaction)

    parent = bootstrap_model.find_by(transaction_id: reference)
    return false unless parent

    token_key = (transaction.surface == "app") ? :user_token_id : :visitor_token_id
    session = bootstrap_session_model.lock.find_by(token_key => token.id)
    return false unless session && session.step_up_ceremony_transaction_ref == reference

    parent.with_lock do
      bindings = admission_model.where(step_up_ceremony_transaction_id: parent.id).lock.to_a
      next false unless bindings.one?

      now = bootstrap_model.database_now
      next false unless delivery_parent_current?(parent, owner, token, now) &&
        delivery_parent_binding_current?(parent, session, bindings.first, token, now)

      yield(parent, session, bindings.first)
    end
  end

  def delivery_parent_current?(parent, owner, token, now)
    parent.status == "pending" && parent.purpose == "bootstrap" && parent.expires_at > now &&
      parent.surface == transaction.surface && parent.actor_ref == owner.public_id &&
      parent.session_ref == token.public_id &&
      parent.token_binding == token.public_id && parent.require_session_binding &&
      parent.allowed_methods_array == ["email_otp"] && parent.audience == "step_up:#{transaction.surface}" &&
      !parent.step_up_required && !parent.phishing_resistant_required && !parent.user_verification_required &&
      !parent.full_reauthentication_required
  end

  def delivery_parent_binding_current?(parent, session, binding, token, now)
    scope = parent.required_scope
    target = parent.return_to
    target.is_a?(String) && catalog.key?(scope) && catalog.fetch(scope).match?(target) &&
      session.scope == scope && session.return_to == target && session.status == "PENDING" &&
      session.discard_at > now &&
      binding.base_token_id == token.id && binding.purpose == "bootstrap_handoff" && binding.retired_at.nil?
  end

  def current_source?(owner, token)
    owned_pending =
      case email
      when ClientEmail
        email.user_id == owner.id && token.user_id == owner.id && token.device_session.user_id == owner.id &&
        email.user_email_status_id == pending_status
      when VisitorEmail
        email.visitor_id == owner.id && token.visitor_id == owner.id && token.device_session.visitor_id == owner.id &&
        email.visitor_email_status_id == pending_status
      when OperatorEmail
        email.staff_id == owner.id && token.staff_id == owner.id && token.device_session.staff_id == owner.id &&
        email.staff_email_status_id == pending_status
      end
    now = email.class.database_now
    owned_pending && owner.login_allowed? && owner.accessible?(now) && source_available?(now)
  end

  def source_available?(now)
    case email
    when ClientEmail, VisitorEmail
      email.accessible?(now) && !email.binding_finalized_at && !email.binding_released?
    when OperatorEmail then email.staff_email_status_id == pending_status
    else raise ArgumentError, "unsupported Email registration candidate"
    end
  end

  def current_ticket?(owner, token)
    now = transaction.class.database_now
    bound_root = CredentialRegistrationOtpSessionValue.load(session_ref: transaction.session_ref).root_ref
    return false unless bound_root == token.public_id && token.currently_usable?(now) && token.device_session.usable? &&
      token.device_session.current_refresh_token_id == token.id
    return false unless transaction.operation == "registration" && transaction.purpose == "credential_registration" &&
      transaction.actor_ref == owner.public_id && transaction.email_candidate_ref == email.public_id &&
      transaction.normalized_email_digest == email.address_digest
    unless destination.is_a?(String) && destination.encoding.ascii_compatible? && destination.valid_encoding?
      return false
    end

    IdentifierBlindIndex.bidx_for_email(destination, realm: transaction.surface) == email.address_digest
  end
end
