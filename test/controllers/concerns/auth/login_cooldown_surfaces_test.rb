# typed: false
# frozen_string_literal: true

require "test_helper"

# The login cooldown lives in the shared AuthenticationBase, so every sign-in surface must enforce it
# against its own token table and answer it the same way. Each surface is exercised through its real
# Base application controller and the public `log_in` boundary.
#
# The anchor is `root_login_established_at`, written only when a root login commits
# (adr/root-login-establishment-boundary.md). Token creation time, RP sessions, and revocation do
# not move it.
class AuthLoginCooldownSurfacesTest < ActiveSupport::TestCase
  # Accounts are created per test so no fixture token shares the actor.

  WINDOW = 30.seconds

  SURFACES = {
    app: {
      controller: Base::App::ApplicationController,
      host: "PUBLIC_BASE_SERVICE_URL",
      token_class: ClientToken,
      resource: -> { Client.create!(status_id: ClientStatus::NOTHING, birthdate: "2000-01-01") },
      token: ->(resource, attrs) { ClientToken.create!(user: resource, **attrs) },
    },
    com: {
      controller: Base::Com::ApplicationController,
      host: "PUBLIC_BASE_CORPORATE_URL",
      token_class: VisitorToken,
      resource: -> { Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR) },
      token: ->(resource, attrs) { VisitorToken.create!(visitor_id: resource.id, **attrs) },
    },
    org: {
      controller: Base::Org::ApplicationController,
      host: "PUBLIC_BASE_STAFF_URL",
      token_class: OperatorToken,
      resource: -> { Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF) },
      token: ->(resource, attrs) { OperatorToken.create!(staff_id: resource.id, **attrs) },
    },
  }.freeze

  SURFACES.each do |surface, config|
    test "#{surface}: a root login 29 seconds after the previous one is refused" do
      freeze_time do
        resource = config[:resource].call
        config[:token].call(resource, root_login_established_at: (WINDOW - 1.second).ago)

        with_login_cooldown(WINDOW) do
          assert_raises(AuthenticationBase::LoginCooldownError) { root_login(config, resource) }
        end
      end
    end

    # Storage precision boundary: timestamptz keeps microseconds, so one microsecond inside the
    # window is the nearest representable value below the boundary.
    test "#{surface}: a root login one microsecond inside the window is refused" do
      freeze_time do
        resource = config[:resource].call
        config[:token].call(resource, root_login_established_at: WINDOW.ago + Rational(1, 1_000_000))

        with_login_cooldown(WINDOW) do
          assert_raises(AuthenticationBase::LoginCooldownError) { root_login(config, resource) }
        end
      end
    end

    test "#{surface}: a root login exactly 30 seconds after the previous one is not refused by the cooldown" do
      freeze_time do
        resource = config[:resource].call
        signed_out_token(config, resource, root_login_established_at: WINDOW.ago)

        with_login_cooldown(WINDOW) { assert_committed_root_login(config, resource) }
      end
    end

    test "#{surface}: a root login 31 seconds after the previous one is not refused by the cooldown" do
      freeze_time do
        resource = config[:resource].call
        signed_out_token(config, resource, root_login_established_at: (WINDOW + 1.second).ago)

        with_login_cooldown(WINDOW) { assert_committed_root_login(config, resource) }
      end
    end

    test "#{surface}: signing out does not clear the anchor (revoked root login inside the window)" do
      freeze_time do
        resource = config[:resource].call
        token = config[:token].call(resource, root_login_established_at: 10.seconds.ago)
        token.revoke!

        with_login_cooldown(WINDOW) do
          assert_raises(AuthenticationBase::LoginCooldownError) { root_login(config, resource) }
        end
      end
    end

    test "#{surface}: a token created this instant without a root login record does not trigger the cooldown" do
      freeze_time do
        resource = config[:resource].call
        signed_out_token(config, resource, {})

        with_login_cooldown(WINDOW) { assert_committed_root_login(config, resource) }
      end
    end

    test "#{surface}: a refusal writes nothing and does not move the anchor" do
      freeze_time do
        resource = config[:resource].call
        anchor = 10.seconds.ago
        config[:token].call(resource, root_login_established_at: anchor)

        with_login_cooldown(WINDOW) do
          assert_no_difference(-> { config[:token_class].where(fk_for(config) => resource.id).count }) do
            2.times { assert_raises(AuthenticationBase::LoginCooldownError) { root_login(config, resource) } }
          end
        end

        assert_equal anchor, latest_anchor(config, resource)
      end
    end

    test "#{surface}: an RP session neither checks nor records the root login anchor" do
      freeze_time do
        resource = config[:resource].call
        anchor = 1.second.ago
        signed_out_token(config, resource, root_login_established_at: anchor)

        with_login_cooldown(WINDOW) do
          result = build_controller(config).log_in(resource, establishment: :rp_session)

          assert_equal :success, result.fetch(:status)
        end

        assert_equal anchor, latest_anchor(config, resource)
      end
    end

    test "#{surface}: a zero cooldown disables the gate even for a root login committed this instant" do
      freeze_time do
        resource = config[:resource].call
        signed_out_token(config, resource, root_login_established_at: Time.current)

        with_login_cooldown(0.seconds) { assert_committed_root_login(config, resource) }
      end
    end

    # The refusal must not tell an attacker that the account exists or when it last signed in:
    # the message is generic and Retry-After is the full window, never the time remaining.
    test "#{surface}: a cooldown refusal is generic, with the full-window Retry-After and no-store" do
      controller = build_controller(config)

      with_login_cooldown(WINDOW) do
        assert controller.rescue_with_handler(AuthenticationBase::LoginCooldownError.new)
      end

      assert_equal 429, controller.response.status
      assert_equal WINDOW.to_i.to_s, controller.response.headers["Retry-After"]
      assert_equal "no-store", controller.response.headers["Cache-Control"]
      assert_includes controller.response.body, "/sign"
      assert_no_match(/\d+\s*(秒|seconds?)/, controller.response.body)
      assert_not_includes controller.response.body, "サインインが完了"
    end
  end

  private

  # The previous session was signed out, so the one-session limit on com and org does not hide the
  # cooldown decision under test.
  def signed_out_token(config, resource, attrs)
    config[:token].call(resource, attrs).tap(&:revoke!)
  end

  def root_login(config, resource)
    build_controller(config).log_in(resource, establishment: :root_login)
  end

  def fk_for(config)
    { ClientToken => :user_id, VisitorToken => :visitor_id, OperatorToken => :staff_id }.fetch(config[:token_class])
  end

  def latest_anchor(config, resource)
    config[:token_class].where(fk_for(config) => resource.id).maximum(:root_login_established_at)
  end

  def build_controller(config)
    request = ActionDispatch::TestRequest.create
    request.host = ENV.fetch(config[:host])
    # log_in writes the session once the gate is passed; a bare TestRequest has no session store.
    request.session = ActionController::TestSession.new
    controller_class = config[:controller]
    controller = controller_class.new
    controller.set_request!(request)
    controller.set_response!(controller_class.make_response!(request))
    controller
  end

  # Past the cooldown gate, log_in commits a root login and records its anchor.
  def assert_committed_root_login(config, resource)
    result = root_login(config, resource)

    assert_equal :success, result.fetch(:status)
    assert_equal Time.current, latest_anchor(config, resource)
  end
end
