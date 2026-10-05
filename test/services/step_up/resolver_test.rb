# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module StepUp
  class ResolverTest < ActiveSupport::TestCase
    Token =
      Struct.new(
        :currently_usable,
        :public_id,
        :last_step_up_at,
        :last_step_up_scope,
        :last_step_up_aal,
        :last_step_up_method,
        :last_step_up_session_public_id,
        :last_step_up_purpose,
        :last_step_up_audience,
        :last_step_up_phishing_resistant,
        keyword_init: true,
      ) do
        def currently_usable?(_now = Time.current) = currently_usable

        def has_attribute?(attribute)
          members.include?(attribute.to_sym)
        end
      end

    test "returns satisfied when token is usable, fresh, and scope matches" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = Token.new(
        currently_usable: true,
        public_id: "token_1",
        last_step_up_at: now - 5.minutes,
        last_step_up_scope: "profile",
        last_step_up_aal: "aal2",
        last_step_up_method: "totp",
        last_step_up_session_public_id: "session_1",
      )

      step_up = StepUpResolver.call(
        token: token,
        scope: "profile",
        session_binding: "session_1",
        token_binding: "token_1",
        now: now,
      )

      assert_predicate step_up, :satisfied?
      assert_predicate step_up, :usable_token?
      assert_equal "profile", step_up.scope
      assert_nil step_up.required_aal
      assert_equal now + 10.minutes, step_up.expires_at
    end

    test "phishing resistance requires recorded evidence even when method and AAL match" do
      now = Time.utc(2026, 10, 3, 12)
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", required_aal: :aal2,
        allowed_methods: [:passkey], phishing_resistant_required: true,
      )
      token = Token.new(
        currently_usable: true, public_id: "token_1",
        last_step_up_at: now - 1.minute, last_step_up_scope: "settings_passkey",
        last_step_up_aal: "aal2", last_step_up_method: "passkey",
      )

      [nil, false, "true", 1].each do |recorded|
        token.last_step_up_phishing_resistant = recorded

        assert_not StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?,
                   "recorded phishing resistance #{recorded.inspect} must not grant access"
      end
      token.last_step_up_phishing_resistant = true

      assert_predicate StepUpResolver.call(token: token, requirement: requirement, now: now), :satisfied?
    end

    test "freshness rejects a verification time one microsecond in the future" do
      now = Time.utc(2026, 10, 3, 12)
      token = Token.new(
        currently_usable: true, public_id: "token_1", last_step_up_scope: "profile",
        last_step_up_method: "totp", last_step_up_aal: "aal2",
      )

      [-1, 0, 1].each do |microseconds|
        token.last_step_up_at = now + Rational(microseconds, 1_000_000)

        assert_equal microseconds <= 0,
                     StepUpResolver.call(token: token, scope: "profile", now: now).satisfied?
      end
    end

    test "freshness rejects exactly at and one microsecond after expiry" do
      verified_at = Time.utc(2026, 10, 3, 12)
      token = Token.new(
        currently_usable: true, public_id: "token_1", last_step_up_scope: "profile",
        last_step_up_method: "totp", last_step_up_aal: "aal2", last_step_up_at: verified_at,
      )
      [-1, 0, 1].each do |microseconds|
        now = verified_at + 15.minutes + Rational(microseconds, 1_000_000)

        assert_equal microseconds < 0,
                     StepUpResolver.call(token: token, scope: "profile", now: now).satisfied?
      end
    end

    test "returns unsatisfied when token is expired, unusable, or scope mismatched" do
      now = Time.zone.parse("2026-05-25 00:00:00")

      expired = token_at(now - 16.minutes, scope: "profile")
      unusable = token_at(now - 5.minutes, currently_usable: false, scope: "profile")
      mismatched = token_at(now - 5.minutes, scope: "other")

      assert_not StepUpResolver.call(token: expired, scope: "profile", now: now).satisfied?
      assert_not StepUpResolver.call(token: unusable, scope: "profile", now: now).satisfied?
      assert_not StepUpResolver.call(token: mismatched, scope: "profile", now: now).satisfied?
    end

    test "satisfies just before ttl and rejects exactly at ttl" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      ttl = 15.minutes

      just_before = token_at(now - ttl + 1.second, scope: "profile")
      exactly_at = token_at(now - ttl, scope: "profile")

      assert_predicate StepUpResolver.call(token: just_before, scope: "profile", now: now, ttl: ttl), :satisfied?
      assert_not StepUpResolver.call(token: exactly_at, scope: "profile", now: now, ttl: ttl).satisfied?
    end

    test "blank requested scope is never satisfied" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(now - 1.minute, scope: "settings_email")

      assert_not StepUpResolver.call(token: token, scope: nil, now: now).satisfied?
      assert_not StepUpResolver.call(token: token, scope: "", now: now).satisfied?
      assert_not StepUpResolver.call(token: token, scope: "settings_passkey", now: now).satisfied?
    end

    test "rejects wrong method, unsupported aal, and binding mismatch" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(now - 1.minute, scope: "settings_passkey", method: "email_otp")

      assert_not StepUpResolver.call(token: token, scope: "settings_passkey", now: now).satisfied?
      assert_not StepUpResolver.call(token: token, scope: "settings_passkey", required_aal: :aal3, now: now).satisfied?
      assert_not StepUpResolver.call(
        token: token_at(now - 1.minute, scope: "settings_passkey"),
        scope: "settings_passkey",
        session_binding: "other_session",
        token_binding: "token_1",
        now: now,
      ).satisfied?
    end

    test "rejects wrong purpose and audience when requirement binds them" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(
        now - 1.minute,
        scope: "settings_email",
        purpose: "step_up",
        audience: "step_up:app",
      )
      requirement = StepUpRequirement.new(
        scope: "settings_email",
        purpose: "step_up",
        audience: "step_up:app",
      )

      assert_predicate StepUpResolver.call(token: token, requirement: requirement, now: now), :satisfied?

      wrong_purpose = StepUpRequirement.new(
        scope: "settings_email",
        purpose: "other",
        audience: "step_up:app",
      )
      wrong_audience = StepUpRequirement.new(
        scope: "settings_email",
        purpose: "step_up",
        audience: "step_up:org",
      )

      assert_not StepUpResolver.call(token: token, requirement: wrong_purpose, now: now).satisfied?
      assert_not StepUpResolver.call(token: token, requirement: wrong_audience, now: now).satisfied?
    end

    test "rejects missing session binding when requirement explicitly requires it" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(now - 1.minute, scope: "settings_email", session_public_id: nil)
      requirement = StepUpRequirement.new(
        scope: "settings_email",
        session_binding: nil,
        require_session_binding: true,
      )

      step_up = StepUpResolver.call(token: token, requirement: requirement, now: now)

      assert_not_predicate step_up, :satisfied?
    end

    test "rejects mismatched session binding when requirement explicitly requires it" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(now - 1.minute, scope: "settings_email", session_public_id: "session_1")
      requirement = StepUpRequirement.new(
        scope: "settings_email",
        session_binding: "session_2",
        require_session_binding: true,
      )

      assert_not StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?
    end

    test "still allows step-up without a session binding when it is not required" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(now - 1.minute, scope: "settings_email", session_public_id: nil)
      requirement = StepUpRequirement.new(scope: "settings_email")

      assert_predicate StepUpResolver.call(token: token, requirement: requirement, now: now), :satisfied?
    end

    test "browser step-up contract requires a live session binding" do
      now = Time.zone.parse("2026-05-25 00:00:00")
      token = token_at(now - 1.minute, scope: "settings_email", session_public_id: "session_1")
      requirement = StepUpRequirement.new(
        scope: "settings_email",
        session_binding: "session_1",
        require_session_binding: true,
      )

      assert_predicate StepUpResolver.call(token: token, requirement: requirement, now: now), :satisfied?
      assert_not StepUpResolver.call(
        token: token_at(now - 1.minute, scope: "settings_email", session_public_id: nil),
        requirement: requirement,
        now: now,
      ).satisfied?
      assert_not StepUpResolver.call(
        token: token_at(now - 1.minute, scope: "settings_email", session_public_id: "other_session"),
        requirement: requirement,
        now: now,
      ).satisfied?
    end

    private

    def token_at(time, currently_usable: true, scope:, aal: "aal2", method: "totp",
                 public_id: "token_1", session_public_id: "session_1",
                 purpose: nil, audience: nil)
      Token.new(
        currently_usable: currently_usable,
        public_id: public_id,
        last_step_up_at: time,
        last_step_up_scope: scope,
        last_step_up_aal: aal,
        last_step_up_method: method,
        last_step_up_session_public_id: session_public_id,
        last_step_up_purpose: purpose,
        last_step_up_audience: audience,
      )
    end
  end
end
