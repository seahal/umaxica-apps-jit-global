# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyFreshnessCommitter
  Commit = Data.define(:result, :token)

  def self.call!(result_token:, token:, expected_scope:, expected_aal:, expected_method:,
                 expected_phishing_resistant: false, audience:, now: Time.current)
    new(
      result_token: result_token,
      token: token,
      expected_scope: expected_scope,
      expected_aal: expected_aal,
      expected_method: expected_method,
      expected_phishing_resistant: expected_phishing_resistant,
      audience: audience,
      now: now,
    ).call!
  end

  def initialize(result_token:, token:, expected_scope:, expected_aal:, expected_method:,
                 expected_phishing_resistant: false, audience:, now: Time.current)
    @result_token = result_token
    @token = token
    @expected_scope = expected_scope.to_s
    @expected_aal = expected_aal.to_s
    @expected_method = expected_method.to_s
    @expected_phishing_resistant = !!expected_phishing_resistant
    @audience = audience.to_s
    @now = now
  end

  def call!
    validate!
    update_token!
    Commit.new(result: result, token: token)
  end

  private

  attr_reader :result_token, :token, :expected_scope, :expected_aal, :expected_method, :expected_phishing_resistant,
              :audience, :now

  def validate!
    raise IdentityStepUpCeremonyContract::Error, "token is required" if token.blank?
    # An Emergency (Restricted Mode) session is not eligible to hold step-up
    # freshness at all. Rejecting the commit here means that even a ceremony
    # result that was somehow produced under an Emergency session cannot be
    # turned into usable freshness on the session row.
    raise IdentityStepUpCeremonyContract::Error,
          "authentication context is not eligible for step-up" if emergency_authentication_context?
    raise IdentityStepUpCeremonyContract::Error,
          "result actor does not match current actor" unless result["actor_ref"].to_s == token_actor_ref
    raise IdentityStepUpCeremonyContract::Error,
          "result session does not match current session" unless result["session_ref"].to_s == token.public_id.to_s
    raise IdentityStepUpCeremonyContract::Error,
          "result scope does not match requirement" unless result["scope"].to_s == expected_scope
    raise IdentityStepUpCeremonyContract::Error,
          "result method does not match ceremony" unless result["method"].to_s == expected_method
    raise IdentityStepUpCeremonyContract::Error,
          "result AAL is insufficient" unless aal_rank(result["aal"]) >= aal_rank(expected_aal)
  end

  def emergency_authentication_context?
    token.respond_to?(:emergency_authentication_context?) && token.emergency_authentication_context?
  end

  def update_token!
    token.update!(freshness_attributes)
  end

  def freshness_attributes
    attributes = {
      last_step_up_at: verified_at,
      last_step_up_scope: result["scope"],
    }
    attributes[:last_step_up_aal] = result["aal"] if token_has_attribute?(:last_step_up_aal)
    attributes[:last_step_up_method] = result["method"] if token_has_attribute?(:last_step_up_method)
    attributes[:last_step_up_phishing_resistant] =
      result.phishing_resistant? if token_has_attribute?(:last_step_up_phishing_resistant)
    attributes[:last_step_up_purpose] = "step_up" if token_has_attribute?(:last_step_up_purpose)
    attributes[:last_step_up_audience] = audience if token_has_attribute?(:last_step_up_audience)
    if token_has_attribute?(:last_step_up_session_public_id)
      attributes[:last_step_up_session_public_id] = token.public_id
    end
    attributes
  end

  def token_has_attribute?(attribute)
    token.respond_to?(:has_attribute?) && token.has_attribute?(attribute.to_s)
  end

  def token_actor_ref
    actor =
      if token.respond_to?(:user)
        token.user
      elsif token.respond_to?(:visitor)
        token.visitor
      elsif token.respond_to?(:staff)
        token.staff
      end
    actor&.public_id.to_s
  end

  def verified_at
    Time.zone.at(Integer(result["verified_at"]))
  end

  def aal_rank(value)
    IdentityStepUpCeremonyContract::AALS.index(value.to_s) || -1
  end

  def result
    @result ||= IdentityStepUpCeremonyResult.decode(
      result_token,
      issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  def surface
    @surface ||= IdentityStepUpCeremonyContract.decode_unverified_payload(result_token)["surface"].to_s
  end
end
