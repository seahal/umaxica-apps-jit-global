# typed: false
# frozen_string_literal: true

# Rotates refresh tokens using one-time consume semantics.
# Old rows are preserved and replay is detected via rotated_at.
#
# acme/www owns refresh token rotation. This class is the physical home of the
# rotation, replay-detection, family-revoke, and audit logic. The sign-side
# `SignRefreshTokenIssuer` is only a compatibility subclass and must not be
# read as sign-side refresh authority.
class AcmeRefreshTokenIssuer
  Result =
    Data.define(:success, :token, :refresh_token, :previous_token, :reason) do
      def success? = success

      def [](key)
        public_send(key)
      end

      def fetch(key)
        value = self[key]
        return value unless value.nil?

        raise KeyError, "key not found: #{key.inspect}"
      end
    end

  def self.call(refresh_token:)
    new(refresh_token).call
  end

  def initialize(refresh_token)
    @refresh_token = refresh_token
  end

  def call
    parsed = parse_refresh_token
    return failure(:invalid_format) unless parsed

    public_id, verifier = parsed

    result = nil
    ActiveRecord::Base.connected_to(role: :writing) do
      operation = -> { find_token(public_id) }
      token = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call

      return failure(:token_not_found) unless token
      return failure(:invalid_digest, token: token) unless token.refresh_token_digest_matches?(verifier)

      digest = token.class.digest_refresh_token(verifier)
      result = token.class.rotate_refresh!(
        presented_refresh_digest: digest,
        now: Time.current,
      )
    end

    case result[:status]
    when :rotated
      touch_oidc_connection!(result[:token])
      success(
        token: result[:token],
        refresh_token: result[:refresh_token],
        previous_token: result[:previous_token],
      )
    when :replay
      handle_refresh_token_reuse(result[:token])
      failure(:refresh_token_reuse_detected, token: result[:token])
    else
      failure(:inactive_token, token: result[:token])
    end
  end

  private

  def touch_oidc_connection!(token)
    return unless token.respond_to?(:oidc_connection)

    ActiveRecord::Base.connected_to(role: :writing) do
      # rubocop:disable Rails/SkipsModelValidations
      token.oidc_connection&.update_columns(last_used_at: Time.current, updated_at: Time.current)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def parse_refresh_token
    ClientToken.parse_refresh_token(@refresh_token)
  end

  def find_token(public_id)
    ClientToken.find_by(public_id: public_id) ||
      OperatorToken.find_by(public_id: public_id) ||
      VisitorToken.find_by(public_id: public_id)
  end

  # When reuse is observed (a valid token that no longer matches the
  # stored digest), we treat the event as a family compromise and revoke
  # every token in the same refresh token family. This is logged without
  # the raw refresh verifier to avoid exposing secret_credentials.
  def handle_refresh_token_reuse(token)
    with_token_writing_connection(token) do
      family_scope = refresh_token_family_scope(token)
      now = Time.current
      # rubocop:disable Rails/SkipsModelValidations
      family_scope.update_all(discarded_at: now)
      # rubocop:enable Rails/SkipsModelValidations

      actor_key = actor_identifier_column(token) || :user_id
      SignRiskEmitter.emit(
        "refresh_reuse_detected",
        actor_key => actor_identifier(token),
        :user_token_id => token.public_id,
      )
    end

    RefreshTokenReuseActivityRecorder.call(token: token, result: "token_family_revoked")

    Rails.logger.warn(
      # This is an internal diagnostic, not user-facing copy.
      # rubocop:disable I18n/RailsI18n/DecorateString
      "Refresh token reuse detected; the refresh token family was revoked so the user can sign in again.",
      # rubocop:enable I18n/RailsI18n/DecorateString
    )
    Rails.logger.info(
      JitLogEvent.format(
        "authentication.refresh.reuse_detected",
        # This is an internal diagnostic, not user-facing copy.
        # rubocop:disable I18n/RailsI18n/DecorateString
        message: "Refresh token reuse detected; the refresh token family was revoked.",
        # rubocop:enable I18n/RailsI18n/DecorateString
        token_id: token.public_id,
        refresh_token_family_id: token.refresh_token_family_id,
        actor_type: actor_type_label(token),
        actor_id: actor_identifier(token),
      ),
    )
  end

  def refresh_token_family_scope(token)
    family_id = token.refresh_token_family_id.to_s
    return token.class.where(id: token.id) if family_id.blank?

    token.class.where(refresh_token_family_id: family_id)
  end

  def with_token_writing_connection(token, &)
    owner = connection_owner_for(token.class)
    return yield if owner.blank?

    owner.connected_to(role: :writing, &)
  end

  def connection_owner_for(klass)
    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end

  def actor_identifier_column(token)
    return :user_id if token.respond_to?(:user_id) && token.user_id.present?
    return :staff_id if token.respond_to?(:staff_id) && token.staff_id.present?
    return :visitor_id if token.respond_to?(:visitor_id) && token.visitor_id.present?

    nil
  end

  def actor_identifier(token)
    column = actor_identifier_column(token)
    column ? token.public_send(column) : nil
  end

  def actor_type_label(token)
    actor_identifier_column(token)&.to_s&.delete_suffix("_id")
  end

  def success(token:, refresh_token:, previous_token:)
    Result.new(
      success: true,
      token: token,
      refresh_token: refresh_token,
      previous_token: previous_token,
      reason: nil,
    )
  end

  def failure(reason, token: nil)
    Result.new(
      success: false,
      token: token,
      refresh_token: nil,
      previous_token: nil,
      reason: reason,
    )
  end
end
