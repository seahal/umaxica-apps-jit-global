# frozen_string_literal: true

# Verified, short-lived authentication evidence carried by the OP Access JWT.
# Callers must obtain it through StepUpEvidenceResolver and recheck it at the write boundary.
class StepUpEvidenceValue < Data.define(:acr, :amr, :auth_time, :sid, :sub, :client_id, :aud, :jti)
  MAX_AGE_SECONDS = 300

  public

  def initialize(acr:, amr:, auth_time:, sid:, sub:, client_id:, aud:, jti:)
    unless acr.is_a?(String) && acr.present? &&
        amr.is_a?(Array) && amr.all? { |method| method.is_a?(String) && method.present? } &&
        auth_time.is_a?(Integer) &&
        [sid, sub, client_id, jti].all? { |value| value.is_a?(String) && value.present? } &&
        aud.is_a?(Array) && aud.all? { |audience| audience.is_a?(String) && audience.present? }
      raise ArgumentError, "step-up evidence values are invalid"
    end

    super(
      acr: acr.dup.freeze,
      amr: amr.map { |method| method.dup.freeze }.freeze,
      auth_time:,
      sid: sid.dup.freeze,
      sub: sub.dup.freeze,
      client_id: client_id.dup.freeze,
      aud: aud.map { |audience| audience.dup.freeze }.freeze,
      jti: jti.dup.freeze,
    )
  end

  def current?(now:)
    auth_time <= now.to_i && now.to_i < auth_time + MAX_AGE_SECONDS
  end
end
