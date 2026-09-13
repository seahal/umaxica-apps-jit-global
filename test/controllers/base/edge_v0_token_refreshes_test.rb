# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::EdgeV0TokenRefreshesTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :visitors

  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      build_token: ->(test_case) { ClientToken.create!(user: test_case.clients(:one)) },
      resource: ->(test_case) { test_case.clients(:one) },
    },
    {
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      build_token: ->(test_case) { VisitorToken.create!(visitor: test_case.visitors(:reserved_visitor)) },
      resource: ->(test_case) { test_case.visitors(:reserved_visitor) },
    },
    {
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      build_token: ->(test_case) { OperatorToken.create!(staff: test_case.operators(:one)) },
      resource: ->(test_case) { test_case.operators(:one) },
    },
  ].freeze

  test "POST refresh without a refresh token returns a validation error on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      post "/edge/v0/token/refresh",
           headers: { "Host" => host, "Accept" => "application/json" },
           as: :json

      assert_response :bad_request
      assert_equal "missing_refresh_token", response.parsed_body.fetch("error_code")
    end
  end

  test "POST refresh with a valid cookie refresh token succeeds on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      token_record = surface.fetch(:build_token).call(self)
      absolute_expiry = 2.minutes.from_now.change(usec: 0)
      token_record.update!(discarded_at: absolute_expiry)
      refresh_plain = token_record.rotate_refresh_token!

      host! host

      post "/edge/v0/token/refresh",
           headers: {
             "Host" => host,
             "Accept" => "application/json",
             "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
           },
           as: :json

      assert_response :success
      assert response.parsed_body["refreshed"]
      access_claims = JWT.decode(response.cookies[AuthenticationBase::ACCESS_COOKIE_KEY], nil, false).first
      assert_operator Time.at(access_claims.fetch("exp")).utc, :<=, absolute_expiry

      audit_class, event_id = if token_record.is_a?(OperatorToken)
                                [OperatorChronicle, OperatorChronicleEvent::TOKEN_REFRESHED]
                              else
                                [ClientChronicle, ClientChronicleEvent::TOKEN_REFRESHED]
                              end
      subject_id = if token_record.respond_to?(:user_id)
                     token_record.user_id
                   elsif token_record.respond_to?(:visitor_id)
                     token_record.visitor_id
                   else
                     token_record.staff_id
                   end
      audit = ChronicleRecord.connected_to(role: :writing) do
        audit_class.where(event_id: event_id, subject_id: subject_id.to_s).order(occurred_at: :desc).first
      end
      assert_predicate audit, :present?
      assert_empty audit.context
      refute_includes audit.context.to_s, refresh_plain
    end
  end

  test "POST refresh rejects body refresh tokens on the browser cookie endpoint" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      token_record = surface.fetch(:build_token).call(self)
      refresh_plain = token_record.rotate_refresh_token!

      host! host

      post "/edge/v0/token/refresh",
           params: { refresh_token: refresh_plain },
           headers: { "Host" => host, "Accept" => "application/json" },
           as: :json

      assert_response :bad_request
      assert_equal "invalid_refresh_transport", response.parsed_body.fetch("error_code")
    end
  end

  test "POST refresh rejects authorization header transport on the browser cookie endpoint" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      token_record = surface.fetch(:build_token).call(self)
      refresh_plain = token_record.rotate_refresh_token!

      host! host

      post "/edge/v0/token/refresh",
           headers: {
             "Host" => host,
             "Accept" => "application/json",
             "Authorization" => "Bearer #{refresh_plain}",
             "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
           },
           as: :json

      assert_response :unauthorized
      assert_not_equal true, response.parsed_body["refreshed"] if response.media_type == "application/json"
    end
  end

  test "POST refresh with an invalid refresh token returns a structured error on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      post "/edge/v0/token/refresh",
           headers: {
             "Host" => host,
             "Accept" => "application/json",
             "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=bogus-refresh-token",
           },
           as: :json

      assert_response :unauthorized
      assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
    end
  end

  test "POST refresh rejects an administratively locked resource on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      token_record = surface.fetch(:build_token).call(self)
      refresh_plain = token_record.rotate_refresh_token!
      resource = surface.fetch(:resource).call(self)
      resource.update!(
        access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
        admin_locked_at: Time.current,
        admin_locked_by_operator_id: operators(:one).id,
        admin_locked_reason_code: "security_incident",
      )

      host!(host)

      post(
        "/edge/v0/token/refresh",
        headers: {
          "Host" => host,
          "Accept" => "application/json",
          "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
        },
        as: :json,
      )

      assert_response :forbidden
      assert_equal "administrative_access_locked", response.parsed_body.fetch("error_code")
    ensure
      resource&.update!(
        access_state: AdministrativeAccessLockable::ACCESS_STATE_ENABLED,
        admin_locked_at: nil,
        admin_locked_by_operator_id: nil,
        admin_locked_reason_code: nil,
      )
    end
  end

  test "POST refresh rejects a restricted session on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      token_record = surface.fetch(:build_token).call(self)
      refresh_plain = token_record.rotate_refresh_token!
      token_record.update!(
        token_record.class.token_status_foreign_key => token_record.class.token_status_model::RESTRICTED,
      )

      host!(host)

      post(
        "/edge/v0/token/refresh",
        headers: {
          "Host" => host,
          "Accept" => "application/json",
          "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
        },
        as: :json,
      )

      assert_response :forbidden
      assert_equal "restricted_session", response.parsed_body.fetch("error_code")
    end
  end

  test "POST refresh revokes and rejects an expired restricted session on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      token_record = surface.fetch(:build_token).call(self)
      refresh_plain = token_record.rotate_refresh_token!
      token_record.update!(
        token_record.class.token_status_foreign_key => token_record.class.token_status_model::RESTRICTED,
        :discarded_at => Time.current,
      )

      host!(host)

      post(
        "/edge/v0/token/refresh",
        headers: {
          "Host" => host,
          "Accept" => "application/json",
          "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
        },
        as: :json,
      )

      assert_response :forbidden
      assert_equal "restricted_session", response.parsed_body.fetch("error_code")
      assert_predicate token_record.reload, :revoked?
    end
  end
end
