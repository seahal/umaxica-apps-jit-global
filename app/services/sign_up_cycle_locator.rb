# typed: false
# frozen_string_literal: true

class SignUpCycleLocator
  class OwnershipMismatch < StandardError; end

  BINDING_CLASSES = { app: ClientAuthAdmissionBinding, com: VisitorAuthAdmissionBinding }.freeze
  SESSION_KEYS = {
    app: :app_sign_up_flow_locator,
    com: :com_sign_up_flow_locator,
  }.freeze

  CYCLE_CLASSES = {
    app: ClientSignUpFlow,
    com: VisitorSignUpFlow,
  }.freeze

  NONCE_BYTES = 32

  def initialize(session, surface:, cycle_class: nil)
    @session = session
    @surface = normalize_surface(surface)
    @cycle_class = cycle_class || CYCLE_CLASSES.fetch(@surface)
    return if @cycle_class == CYCLE_CLASSES.fetch(@surface)

    raise ArgumentError, "sign-up cycle class does not match its surface"

  end

  public

  def current(admission_binding:, ceremony_session:, public_id: nil)
    binding_class = BINDING_CLASSES.fetch(surface)
    binding_class.connection_owner.connected_to(role: :writing) do
      binding = admitted_owner!(binding_class, admission_binding, ceremony_session)
      owned = cycle_class.current.where(auth_admission_binding_id: binding.id).to_a
      cycle = owned.find { |candidate| !terminal?(candidate) }
      payload = current_payload
      # A hint naming this Binding's own ended attempt is not a mismatch: the attempt is over and
      # its terminal state decides the response.
      return nil if payload && !cycle && ended_own_attempt?(owned, payload)

      # A hint left by an earlier admission's attempt is dropped only once that attempt is over and
      # its background cleanup has completed; an attempt still held keeps the request refused.
      if payload && released_foreign_attempt?(owned, payload)
        @released_public_id = payload["public_id"]
        clear!
        payload = nil
      end
      public_id = nil if public_id.present? && public_id == released_public_id
      if payload && (!cycle || payload["public_id"] != cycle.public_id ||
          !cycle.nonce_matches?(payload["nonce"]))
        raise OwnershipMismatch, "sign-up admission ownership mismatch"
      end
      if public_id.present? && (!cycle || public_id != cycle.public_id)
        raise OwnershipMismatch, "sign-up admission ownership mismatch"
      end

      cycle
    end
  end

  # Fail-closed sign-up entry: whether this Binding still owns an attempt that is not over and
  # cleaned up. A nonterminal attempt (including one past its deadline that the expiry job has not
  # reached yet) or a terminal attempt whose artifact cleanup has not completed (pending, failed, or
  # past its retry cap) keeps the entry refused. Only the background cleanup releases it.
  def unreleased_attempt?(admission_binding:, ceremony_session:)
    binding_class = BINDING_CLASSES.fetch(surface)
    binding_class.connection_owner.connected_to(role: :writing) do
      binding = admitted_owner!(binding_class, admission_binding, ceremony_session)
      cycle_class.current.where(auth_admission_binding_id: binding.id).any? { |cycle| unreleased?(cycle) }
    end
  end

  def issue!(cycle, nonce: new_nonce)
    ensure_supported_cycle!(cycle)
    cycle.class.connection_class_for_self.connected_to(role: :writing) do
      cycle.update!(nonce_digest: cycle.class.digest_nonce(nonce))
    end
    session[session_key] = {
      "public_id" => cycle.public_id,
      "nonce" => nonce,
    }
    cycle
  end

  def clear!
    session.delete(session_key)
  end

  # The public id of an earlier admission's released attempt whose hint `current` dropped, so the
  # caller can drop its own copy of that hint.
  attr_reader :released_public_id

  private

  attr_reader :session, :surface, :cycle_class

  def admitted_owner!(binding_class, admission_binding, ceremony_session)
    unless admission_binding.is_a?(binding_class) &&
        ceremony_session.is_a?(binding_class.auth_admission_session_class)
      raise OwnershipMismatch, "sign-up admission ownership mismatch"
    end

    binding = binding_class.find_by(id: admission_binding.id)
    ceremony = binding_class.auth_admission_session_class.find_by(id: ceremony_session.id)
    # Bindings are strict-loading; the parent is read explicitly by its id.
    parent = binding && binding.association(:authorization_transaction).scope.take
    unless binding&.redeemed? && !binding.retired? && binding.purpose == "authentication_handoff" &&
        binding.entry_intent == "sign_up" && binding.admitted_auth_ceremony_session_id == ceremony&.id &&
        ceremony&.active? && ceremony.admitted? && ceremony.admission_purpose == binding.purpose &&
        matching_authorization_parent?(parent, ceremony, binding_class)
      raise OwnershipMismatch, "sign-up admission ownership mismatch"
    end

    binding
  end

  def matching_authorization_parent?(parent, ceremony, binding_class)
    parent && parent.surface == surface.to_s && parent.status == "pending" &&
      parent.expires_at > binding_class.database_now &&
      ceremony.authorization_transaction_ref == parent.transaction_id
  end

  def current_payload
    payload = session[session_key]
    return nil if payload.nil?
    return payload.stringify_keys if payload.is_a?(Hash)

    raise OwnershipMismatch, "sign-up admission ownership mismatch"
  end

  def ended_own_attempt?(owned, payload)
    owned.any? do |candidate|
      terminal?(candidate) && candidate.public_id == payload["public_id"] && candidate.nonce_matches?(payload["nonce"])
    end
  end

  def released_foreign_attempt?(owned, payload)
    return false if owned.any? { |candidate| candidate.public_id == payload["public_id"] }

    earlier = cycle_class.find_by(public_id: payload["public_id"])
    earlier.present? && earlier.nonce_matches?(payload["nonce"]) && terminal?(earlier) && !unreleased?(earlier)
  end

  def unreleased?(cycle)
    return true unless terminal?(cycle)
    return false if cycle.status_id == cycle.status_id_for("COMPLETED")

    !cycle.cleanup_completed?
  end

  def terminal?(cycle)
    %w(COMPLETED FAILED EXPIRED CANCELLED HALTED).any? do |status_name|
      cycle.status_id == cycle.status_id_for(status_name)
    end
  end

  def ensure_supported_cycle!(cycle)
    return if cycle.is_a?(cycle_class)

    raise ArgumentError, "unsupported sign-up cycle"
  end

  def session_key
    SESSION_KEYS.fetch(surface)
  end

  def normalize_surface(value)
    normalized = value&.to_sym
    return normalized if SESSION_KEYS.key?(normalized)

    raise ArgumentError, "unsupported sign-up cycle surface"
  end

  def new_nonce
    SecureRandom.urlsafe_base64(NONCE_BYTES)
  end
end
