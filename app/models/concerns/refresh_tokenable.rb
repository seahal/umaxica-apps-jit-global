# typed: false
# frozen_string_literal: true

# Shared refresh-token behavior for token models.
# Keeps raw tokens out of the database by storing only digests.
# Required gem: sha3

module RefreshTokenable
  extend ActiveSupport::Concern
  include RefreshTokenShared

  REFRESH_TTL = SecurityTokenLifetimes::CLIENT_REFRESH_TOKEN_TTL

  included do
    before_validation :ensure_lapses_at, on: :create
    before_validation :ensure_refresh_token_family_id, on: :create
    before_validation :ensure_refresh_token_generation, on: :create
    before_validation :ensure_device_session_record, on: :create
    validates :refresh_token_digest, uniqueness: true, allow_nil: true
  end

  class_methods do
    def rotate_refresh!(presented_refresh_digest:, now: Time.current)
      return { status: :invalid, token: nil } if presented_refresh_digest.blank?

      operation =
        lambda do
          transaction do
            current_token = lock_refresh_token_record_by_digest(
              presented_refresh_digest,
              digest_column: :refresh_token_digest,
              now: now,
            )

            return { status: :invalid, token: nil } unless current_token
            return { status: :replay, token: current_token } if current_token.rotated_at.present?
            return { status: :invalid, token: current_token } unless current_token.currently_usable?(now)

            current_token.update!(rotated_at: now, last_used_at: now, updated_at: now)

            replacement, raw_refresh_token = create_rotated_token_record!(current_token)

            {
              status: :rotated,
              token: replacement,
              previous_token: current_token,
              refresh_token: raw_refresh_token,
            }
          end
        end

      defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    end

    private

    def create_rotated_token_record!(previous_token)
      attrs = rotated_token_attributes(previous_token)
      release_unique_dbsc_session_id!(previous_token) if attrs[:dbsc_session_id].present?
      replacement = new(attrs)
      replacement.skip_session_limit_check = true if replacement.respond_to?(:skip_session_limit_check=)
      replacement.save!

      raw_refresh_token, verifier = generate_refresh_token(public_id: replacement.public_id)
      replacement.update!(refresh_token_digest: digest_refresh_token(verifier))
      update_device_session_after_rotation!(previous_token, replacement)
      [replacement, raw_refresh_token]
    end

    def rotated_token_attributes(previous_token)
      attrs = rotated_token_core_attributes(previous_token)
      copy_rotated_token_optional_attributes(attrs, previous_token)
      copy_rotated_token_binding_attributes(attrs, previous_token)
      copy_rotated_token_authentication_context(attrs, previous_token)
      attrs
    end

    # Rotation replaces the session row, so anything the replacement does not
    # copy is silently dropped. The authentication context must not be: a
    # Restricted Mode session that rotated into a row with no context would
    # become a Normal session, which is exactly the upgrade the design forbids.
    # Kept as its own step rather than one more line in the optional-attribute
    # list, because this one is a security invariant
    # (docs/security/org-emergency-access.md).
    def copy_rotated_token_authentication_context(attrs, previous_token)
      return unless previous_token.has_attribute?(:authentication_context)

      attrs[:authentication_context] = previous_token.authentication_context
    end

    def rotated_token_core_attributes(previous_token)
      {
        refresh_token_family_id: previous_token.refresh_token_family_id.presence || SecureRandom.uuid,
        refresh_token_generation: Integer(previous_token.refresh_token_generation.to_s, 10) + 1,
        discarded_at: previous_token.discarded_at,
        dbsc_session_id: previous_token.dbsc_session_id,
        dbsc_public_key: previous_token.dbsc_public_key,
        dbsc_challenge: previous_token.dbsc_challenge,
        dbsc_challenge_issued_at: previous_token.dbsc_challenge_issued_at,
      }
    end

    def copy_rotated_token_optional_attributes(attrs, previous_token)
      copy_attribute_if_present(attrs, previous_token, :device_session_id)
      copy_attribute_if_present(attrs, previous_token, :dpop_jkt)
      copy_attribute_if_present(attrs, previous_token, :purged_at)
      copy_attribute_if_present(attrs, previous_token, :oidc_connection_id)
      copy_attribute_if_present(attrs, previous_token, :oidc_client_id)
      copy_attribute_if_present(attrs, previous_token, :oidc_scope)
      copy_attribute_if_present(attrs, previous_token, :oidc_sid)

      actor_key = actor_foreign_key_from(previous_token)
      token_status_key = token_status_key_from(previous_token)
      token_kind_key = token_kind_key_from(previous_token)
      operation =
        lambda do
          attrs[actor_key] = previous_token.public_send(actor_key) if actor_key
          attrs[token_status_key] = previous_token.public_send(token_status_key) if token_status_key
          attrs[token_kind_key] = previous_token.public_send(token_kind_key) if token_kind_key
        end
      defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    end

    def copy_rotated_token_binding_attributes(attrs, previous_token)
      copy_attribute_if_present(attrs, previous_token, :user_token_binding_method_id)
      copy_attribute_if_present(attrs, previous_token, :staff_token_binding_method_id)
      copy_attribute_if_present(attrs, previous_token, :visitor_token_binding_method_id)
      copy_attribute_if_present(attrs, previous_token, :user_token_dbsc_status_id)
      copy_attribute_if_present(attrs, previous_token, :staff_token_dbsc_status_id)
      copy_attribute_if_present(attrs, previous_token, :visitor_token_dbsc_status_id)
    end

    def copy_attribute_if_present(attrs, previous_token, name)
      attrs[name] = previous_token.public_send(name) if previous_token.has_attribute?(name)
    end

    def update_device_session_after_rotation!(previous_token, replacement)
      return unless replacement.respond_to?(:device_session)

      device_session = replacement.device_session || previous_token.try(:device_session)
      return if device_session.blank?

      attrs = {
        current_refresh_token_id: replacement.id,
        refresh_token_family_id: replacement.refresh_token_family_id,
        last_seen_at: Time.current,
      }
      attrs[:dpop_jkt] = replacement.dpop_jkt if replacement.has_attribute?(:dpop_jkt)
      # rubocop:disable Rails/SkipsModelValidations
      device_session.update_columns(attrs)
      # rubocop:enable Rails/SkipsModelValidations
    end

    def release_unique_dbsc_session_id!(previous_token)
      return unless previous_token.has_attribute?(:dbsc_session_id)
      return if previous_token.dbsc_session_id.blank?

      previous_token.update!(dbsc_session_id: nil)
    end

    def actor_foreign_key_from(token)
      return :user_id if token.has_attribute?(:user_id)
      return :staff_id if token.has_attribute?(:staff_id)

      :visitor_id
    end

    def token_status_key_from(token)
      return :user_token_status_id if token.has_attribute?(:user_token_status_id)
      return :staff_token_status_id if token.has_attribute?(:staff_token_status_id)

      :visitor_token_status_id
    end

    def token_kind_key_from(token)
      return :user_token_kind_id if token.has_attribute?(:user_token_kind_id)
      return :staff_token_kind_id if token.has_attribute?(:staff_token_kind_id)

      :visitor_token_kind_id
    end
  end

  # Whether the refresh token has expired.
  def expired_refresh?
    return false if discarded_at.blank?
    return false if discarded_at.respond_to?(:infinite?) && discarded_at.infinite?

    discarded_at <= Time.current
  end

  # Whether the token is active.
  def active?
    !revoked? && !expired_refresh?
  end

  # Rotate (refresh) the token and return the raw token for the client.
  def rotate_refresh_token!(discarded_at: nil)
    # Use a transaction to keep token state consistent.
    transaction do
      token, verifier = generate_refresh_token(public_id: public_id)

      self.refresh_token_digest = digest_refresh_token(verifier)
      self.discarded_at =
        if discarded_at
          SessionAbsoluteExpiryValue.cap(proposed_expiry: discarded_at, absolute_expiry: self.discarded_at)
        elsif self.discarded_at.respond_to?(:infinite?) && self.discarded_at.infinite?
          default_lapses_at
        else
          self.discarded_at
        end
      self.last_used_at = Time.current
      self.refresh_token_generation = Integer(refresh_token_generation.to_s, 10) + 1
      save!
      self.class.send(:update_device_session_after_rotation!, self, self) if respond_to?(:device_session)

      # Return the combined token for the client.
      token
    end
  end

  def refresh_token=(verifier)
    self.refresh_token_digest = verifier.blank? ? nil : digest_refresh_token(verifier)
  end

  # Authenticate the refresh token.
  def authenticate_refresh_token(verifier)
    return false unless active?

    refresh_token_digest_matches?(verifier)
  end

  def refresh_token_digest_matches?(verifier)
    return false if verifier.blank? || refresh_token_digest.blank?

    candidate = digest_refresh_token(verifier)

    secure_compare?(refresh_token_digest, candidate)
  end

  private

  def default_lapses_at
    Time.current + REFRESH_TTL
  end

  def ensure_lapses_at
    return if discarded_at.present? && !(discarded_at.respond_to?(:infinite?) && discarded_at.infinite?)

    self.discarded_at = default_lapses_at
  end

  def ensure_refresh_token_family_id
    self.refresh_token_family_id ||= SecureRandom.uuid
  end

  def ensure_refresh_token_generation
    self.refresh_token_generation ||= 0
  end

  def ensure_device_session_record
    return unless has_attribute?(:device_session_id)
    return if device_session_id.present?

    klass = device_session_class
    actor_key = device_session_actor_key
    return unless klass && actor_key && public_send(actor_key).present?

    attrs = {
      actor_key => public_send(actor_key),
      :dpop_jkt => has_attribute?(:dpop_jkt) ? dpop_jkt.presence : nil,
      :refresh_token_family_id => refresh_token_family_id,
      :last_seen_at => Time.current,
    }
    operation =
      lambda do
        session = klass.new(attrs)
        session.save!(validate: false)
        session
      end
    self.device_session = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def device_session_class
    case self.class.name
    when "ClientToken" then ClientDeviceSession
    when "OperatorToken" then OperatorDeviceSession
    when "VisitorToken" then VisitorDeviceSession
    end
  end

  def device_session_actor_key
    return :user_id if has_attribute?(:user_id)
    return :staff_id if has_attribute?(:staff_id)

    :visitor_id if has_attribute?(:visitor_id)
  end
end
