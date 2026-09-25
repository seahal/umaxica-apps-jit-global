# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_tokens
# Database name: com_ticket
#
#  id                                 :bigint           not null, primary key
#  dbsc_challenge                     :text
#  dbsc_challenge_issued_at           :datetime
#  dbsc_public_key                    :jsonb
#  discard_at                       :datetime         default(Infinity), not null
#  dpop_jkt                           :string
#  last_step_up_aal                   :string
#  last_step_up_at                    :datetime
#  last_step_up_audience              :string
#  last_step_up_method                :string
#  last_step_up_purpose               :string
#  last_step_up_scope                 :string
#  last_used_at                       :datetime
#  oidc_jti                           :uuid
#  oidc_scope                         :string
#  oidc_sid                           :uuid
#  purge_eligible_at                          :datetime         default(Infinity), not null
#  refresh_token_digest               :binary
#  refresh_token_generation           :integer          default(0), not null
#  rotated_at                         :datetime
#  selected_at                        :datetime
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  dbsc_session_id                    :string
#  device_session_id                  :bigint
#  last_step_up_session_public_id     :string
#  oidc_client_id                     :string(64)
#  oidc_connection_id                 :bigint
#  public_id                          :string(21)       default(""), not null
#  refresh_token_family_id            :string
#  selected_account_public_id         :string
#  selected_collective_public_id      :string
#  selected_collective_unit_public_id :string
#  visitor_id                         :bigint           not null
#  visitor_token_binding_method_id    :bigint           default(0), not null
#  visitor_token_dbsc_status_id       :bigint           default(0), not null
#  visitor_token_kind_id              :bigint           default(1), not null
#  visitor_token_status_id            :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_tokens_on_created_at                       (created_at)
#  index_visitor_tokens_on_dbsc_session_id                  (dbsc_session_id) UNIQUE
#  index_visitor_tokens_on_device_session_id                (device_session_id)
#  index_visitor_tokens_on_discard_at                     (discard_at)
#  index_visitor_tokens_on_oidc_connection_id               (oidc_connection_id)
#  index_visitor_tokens_on_oidc_jti                         (oidc_jti)
#  index_visitor_tokens_on_oidc_sid                         (oidc_sid)
#  index_visitor_tokens_on_public_id                        (public_id) UNIQUE
#  index_visitor_tokens_on_purge_eligible_at                        (purge_eligible_at)
#  index_visitor_tokens_on_refresh_token_digest             (refresh_token_digest) UNIQUE
#  index_visitor_tokens_on_refresh_token_family_id          (refresh_token_family_id)
#  index_visitor_tokens_on_rotated_at                       (rotated_at)
#  index_visitor_tokens_on_selected_account_public_id       (selected_account_public_id)
#  index_visitor_tokens_on_selected_collective_public_id    (selected_collective_public_id)
#  index_visitor_tokens_on_visitor_id_and_last_step_up_at   (visitor_id,last_step_up_at)
#  index_visitor_tokens_on_visitor_id_and_oidc_client_id    (visitor_id,oidc_client_id)
#  index_visitor_tokens_on_visitor_token_binding_method_id  (visitor_token_binding_method_id)
#  index_visitor_tokens_on_visitor_token_dbsc_status_id     (visitor_token_dbsc_status_id)
#  index_visitor_tokens_on_visitor_token_kind_id            (visitor_token_kind_id)
#  index_visitor_tokens_on_visitor_token_status_id          (visitor_token_status_id)
#
# Foreign Keys
#
#  fk_customer_tokens_on_customer_token_binding_method_id  (visitor_token_binding_method_id => visitor_token_binding_methods.id)
#  fk_customer_tokens_on_customer_token_dbsc_status_id     (visitor_token_dbsc_status_id => visitor_token_dbsc_statuses.id)
#  fk_customer_tokens_on_customer_token_kind_id            (visitor_token_kind_id => visitor_token_kinds.id)
#  fk_customer_tokens_on_customer_token_status_id          (visitor_token_status_id => visitor_token_statuses.id)
#
require "test_helper"

class VisitorTokenTest < ActiveSupport::TestCase
  def setup
    ensure_visitor_reference_records!
    ensure_visitor_token_reference_records!
    @visitor = Visitor.create!
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
  end

  private

  public

  test "inherits from ComTicketRecord" do
    assert_operator VisitorToken, :<, ComTicketRecord
    assert_operator VisitorToken, :<, ApplicationRecord
    assert_not_operator VisitorToken, :<, OrgTicketRecord
  end

  test "belongs to visitor" do
    association = VisitorToken.reflect_on_association(:visitor)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
  end

  test "does not delete a token while a sign-up flow still references it" do
    VisitorSignUpFlowStatus.ensure_defaults!
    VisitorSignUpFlowCleanupStatus.ensure_defaults!
    flow = VisitorSignUpFlow.create!(
      token: @token,
      status_id: VisitorSignUpFlowStatus::CANCELLED,
      step: "cancelled",
      nonce_digest: VisitorSignUpFlow.digest_nonce("nonce"),
      issued_at: 20.minutes.ago,
      expires_at: 5.minutes.ago,
      entry_method: "email",
      cleanup_status_id: VisitorSignUpFlowCleanupStatus::COMPLETED,
    )

    assert_raises(ActiveRecord::DeleteRestrictionError) { @token.destroy }
    assert VisitorToken.exists?(@token.id)
    assert VisitorSignUpFlow.exists?(flow.id)

    assert_raises(ActiveRecord::InvalidForeignKey) do
      VisitorToken.transaction(requires_new: true) do
        VisitorToken.where(id: @token.id).delete_all
      end
    end

    assert VisitorToken.exists?(@token.id)
    assert VisitorSignUpFlow.exists?(flow.id)
  end

  test "can be created with visitor" do
    assert_not_nil @token
    assert_equal @visitor.id, @token.visitor_id
  end

  test "device session rejects a current token owned by another session" do
    other_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    session = @token.device_session

    error =
      assert_raises(ActiveRecord::InvalidForeignKey) do
        VisitorDeviceSession.transaction(requires_new: true) do
          session.update_column(:current_refresh_token_id, other_token.id)
          VisitorDeviceSession.lease_connection.execute(
            "SET CONSTRAINTS fk_visitor_device_sessions_on_current_refresh_token_owner IMMEDIATE",
          )
        end
      end
    assert_equal "23503", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_equal "fk_visitor_device_sessions_on_current_refresh_token_owner",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
  end

  test "token device session reference must exist while remaining nullable" do
    missing_session_id = VisitorDeviceSession.lease_connection.select_value(
      "SELECT nextval(pg_get_serial_sequence('visitor_device_sessions', 'id'))",
    )

    error =
      assert_raises(ActiveRecord::InvalidForeignKey) do
        VisitorToken.transaction(requires_new: true) do
          @token.update_column(:device_session_id, missing_session_id)
        end
      end
    assert_equal "23503", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_includes %w(fk_visitor_tokens_on_device_session_id fk_visitor_tokens_on_visitor_id_and_device_session_id),
                    error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)

    @token.update_column(:device_session_id, nil)

    assert_nil @token.reload.device_session_id
  end

  test "token device session must belong to the same visitor" do
    other_visitor = Visitor.create!
    other_token = VisitorToken.create!(visitor: other_visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    error =
      assert_raises(ActiveRecord::InvalidForeignKey) do
        VisitorToken.transaction(requires_new: true) do
          @token.update_column(:device_session_id, other_token.device_session_id)
        end
      end
    assert_equal "23503", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_equal "fk_visitor_tokens_on_visitor_id_and_device_session_id",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
  end

  test "deleting the current token clears only its session pointer" do
    session = @token.device_session
    session.update!(current_refresh_token: @token)

    @token.delete

    assert_nil session.reload.current_refresh_token_id
    assert_predicate session, :persisted?
  end

  test "device session cannot be destroyed while token history references it" do
    session = @token.device_session

    assert_raises(ActiveRecord::DeleteRestrictionError) { session.destroy! }

    error =
      assert_raises(ActiveRecord::InvalidForeignKey) do
        VisitorDeviceSession.transaction(requires_new: true) do
          VisitorDeviceSession.where(id: session.id).delete_all
        end
      end
    assert_equal "23503", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_includes %w(fk_visitor_tokens_on_device_session_id fk_visitor_tokens_on_visitor_id_and_device_session_id),
                    error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)

    assert VisitorDeviceSession.exists?(session.id)
    assert VisitorToken.exists?(@token.id)
  end

  test "destroying the actor removes tokens before its device sessions" do
    session_id = @token.device_session.id

    @visitor.destroy!

    assert_not VisitorToken.exists?(@token.id)
    assert_not VisitorDeviceSession.exists?(session_id)
  end

  test "does not expose legacy session_id column" do
    assert_not_includes VisitorToken.column_names, "session_id"
  end

  test "enforces maximum concurrent sessions per visitor" do
    visitor = Visitor.create!
    token_status = VisitorTokenStatus.find(VisitorTokenStatus::ACTIVE)
    token_kind = VisitorTokenKind.find(VisitorTokenKind::BROWSER_WEB)
    binding_method = VisitorTokenBindingMethod.find(VisitorTokenBindingMethod::NOTHING)
    dbsc_status = VisitorTokenDbscStatus.find(VisitorTokenDbscStatus::NOTHING)

    VisitorToken::MAX_TOTAL_SESSIONS_PER_VISITOR.times do
      VisitorToken.create!(
        visitor: visitor,
        visitor_token_status: token_status,
        visitor_token_kind: token_kind,
        visitor_token_binding_method: binding_method,
        visitor_token_dbsc_status: dbsc_status,
      )
    end

    extra_token = VisitorToken.new(
      visitor: visitor,
      visitor_token_status: token_status,
      visitor_token_kind: token_kind,
      visitor_token_binding_method: binding_method,
      visitor_token_dbsc_status: dbsc_status,
    )

    assert_not extra_token.valid?
    assert_includes(
      extra_token.errors[:base],
      "exceeds maximum concurrent sessions per visitor (#{VisitorToken::MAX_TOTAL_SESSIONS_PER_VISITOR})",
    )
  end

  test "rotate_refresh_token! generates token that authenticates" do
    raw = @token.rotate_refresh_token!

    public_id, verifier = VisitorToken.parse_refresh_token(raw)

    assert_equal @token.public_id, public_id
    assert @token.authenticate_refresh_token(verifier)
    assert_not @token.authenticate_refresh_token("wrong-value")
  end

  test "rotated replacement preserves forced logout window" do
    freeze_time do
      token = VisitorToken.create!(
        visitor: @visitor,
        visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        discard_at: 12.hours.from_now,
        purge_eligible_at: 4.days.from_now,
      )
      token.rotate_refresh_token!

      result = VisitorToken.rotate_refresh!(
        presented_refresh_digest: token.refresh_token_digest,
        now: Time.current,
      )
      replacement = result[:token]

      assert_equal :rotated, result[:status]
      assert_equal token.discard_at.to_i, replacement.discard_at.to_i
      assert_equal token.purge_eligible_at.to_i, replacement.purge_eligible_at.to_i
    end
  end
end

# DAMP local helper copy for former shared test support.
class VisitorTokenTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_private_key: SecureRandom.base64(24),
          otp_counter: "",
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers = as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local helper copy on the test class.
class VisitorTokenTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discard_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discard_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(SIGN_APP SIGN_ORG SIGN_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
