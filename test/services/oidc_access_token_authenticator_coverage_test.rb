# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcAccessTokenAuthenticatorCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class TokenRecordFake
    attr_reader :oidc_client_id, :oidc_jti

    def initialize(oidc_client_id:, oidc_jti:, has_attribute: true)
      @oidc_client_id = oidc_client_id
      @oidc_jti = oidc_jti
      @has_attribute = has_attribute
    end

    def has_attribute?(name)
      @has_attribute && name == :oidc_jti
    end
  end

  class StaleLockedResource
    def active? = true

    def admin_locked? = false

    def access_token_stale_for_administrative_lock?(_payload) = true
  end

  test "returns invalid token when access token is blank" do
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: nil,
      resource_type: "client",
      host: "app.example.test",
    )

    result = authenticator.call

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects non dpop proof for cnf bound token" do
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
      authorization_scheme: "Bearer",
      dpop_proof: nil,
      request_method: "GET",
      request_uri: "/",
    )

    authenticator.stub(:find_token, nil) do
      AuthenticationTokenService.stub(:decode, { "cnf" => { "jkt" => "thumbprint" } }) do
        result = authenticator.call

        assert_not result.success?
        assert_equal "invalid_token", result.error
      end
    end
  end

  test "rejects tokens without openid scope" do
    resource = Client.create!(status_id: ClientStatus::ACTIVE)
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scope" => "" }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, true) do
            authenticator.stub(:token_jti_matches?, true) do
              authenticator.stub(:token_scope_allows_userinfo?, false) do
                result = authenticator.call

                assert_not result.success?
                assert_equal "insufficient_scope", result.error
              end
            end
          end
        end
      end
    end
  end

  test "returns success for a valid token and resource match" do
    resource = Client.create!(status_id: ClientStatus::ACTIVE)
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scope" => "openid" }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, true) do
            authenticator.stub(:token_jti_matches?, true) do
              authenticator.stub(:token_scope_allows_userinfo?, true) do
                authenticator.stub(:token_resource, resource) do
                  authenticator.stub(:token_subject_matches?, true) do
                    result = authenticator.call

                    assert_predicate result, :success?
                    assert_equal resource, result.resource
                    assert_equal token, result.token
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test "rejects admin locked resource" do
    resource = Client.create!(
      status_id: ClientStatus::ACTIVE,
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: 1,
      admin_locked_reason_code: "security_incident",
    )
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scope" => "openid", "iat" => Time.current.to_i }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, true) do
            authenticator.stub(:token_jti_matches?, true) do
              authenticator.stub(:token_scope_allows_userinfo?, true) do
                result = authenticator.call

                assert_not result.success?
                assert_equal "invalid_token", result.error
              end
            end
          end
        end
      end
    end
  end

  test "rejects resource with stale administrative lock" do
    resource = StaleLockedResource.new
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scope" => "openid", "iat" => Time.current.to_i }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, true) do
            authenticator.stub(:token_jti_matches?, true) do
              authenticator.stub(:token_scope_allows_userinfo?, true) do
                result = authenticator.call

                assert_not result.success?
                assert_equal "invalid_token", result.error
              end
            end
          end
        end
      end
    end
  end

  test "returns invalid token when decode fails" do
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )

    AuthenticationTokenService.stub(:decode, nil) do
      result = authenticator.call

      assert_not result.success?
      assert_equal "invalid_token", result.error
    end
  end

  test "returns invalid token when token is inactive" do
    resource = Client.create!(status_id: ClientStatus::ACTIVE)
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(false, resource)

    AuthenticationTokenService.stub(:decode, { "scope" => "openid" }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          result = authenticator.call

          assert_not result.success?
          assert_equal "invalid_token", result.error
        end
      end
    end
  end

  test "returns invalid token when token audience does not match" do
    resource = Client.create!(status_id: ClientStatus::ACTIVE)
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scope" => "openid" }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, false) do
            result = authenticator.call

            assert_not result.success?
            assert_equal "invalid_token", result.error
          end
        end
      end
    end
  end

  test "returns invalid token when token jti does not match" do
    resource = Client.create!(status_id: ClientStatus::ACTIVE)
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scope" => "openid" }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, true) do
            authenticator.stub(:token_jti_matches?, false) do
              result = authenticator.call

              assert_not result.success?
              assert_equal "invalid_token", result.error
            end
          end
        end
      end
    end
  end

  test "returns invalid token when resource is inactive" do
    resource = Struct.new(:active?).new(false)
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scope" => "openid" }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, true) do
            authenticator.stub(:token_jti_matches?, true) do
              authenticator.stub(:token_scope_allows_userinfo?, true) do
                result = authenticator.call

                assert_not result.success?
                assert_equal "invalid_token", result.error
              end
            end
          end
        end
      end
    end
  end

  test "returns invalid token when token subject does not match" do
    resource = Client.create!(status_id: ClientStatus::ACTIVE)
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scope" => "openid" }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, true) do
            authenticator.stub(:token_jti_matches?, true) do
              authenticator.stub(:token_scope_allows_userinfo?, true) do
                authenticator.stub(:token_subject_matches?, false) do
                  result = authenticator.call

                  assert_not result.success?
                  assert_equal "invalid_token", result.error
                end
              end
            end
          end
        end
      end
    end
  end

  test "private helpers cover dpop, audience, jti, resource, and context routing" do
    assert OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
      authorization_scheme: "Bearer",
    ).send(:dpop_valid?, {})

    client = Struct.new(:aud).new("aud-1")
    token = TokenRecordFake.new(oidc_client_id: "client-1", oidc_jti: "jti-1")

    OidcClientRegistry.stub(:find, client) do
      OidcIssuer.stub(:resource_type_for_client, "client") do
        authenticator =
          OidcAccessTokenAuthenticator.new(
            access_token: "token",
            resource_type: "client",
            host: "app.example.test",
          )

        assert authenticator.send(:token_belongs_to_audience?, token, { "aud" => ["aud-1"] })
        assert_not authenticator.send(:token_belongs_to_audience?, token, { "aud" => ["other"] })
        assert authenticator.send(
          :token_jti_matches?, TokenRecordFake.new(oidc_client_id: "client-1", oidc_jti: nil),
          {},
        )
        assert authenticator.send(
          :token_jti_matches?,
          TokenRecordFake.new(oidc_client_id: "client-1", oidc_jti: "jti-1"), { "jti" => "jti-1" },
        )
        assert_not authenticator.send(:token_jti_matches?, token, { "jti" => "jti-2" })
      end
    end

    client_authenticator =
      OidcAccessTokenAuthenticator.new(
        access_token: "token",
        resource_type: "client",
        host: "app.example.test",
      )
    operator_authenticator =
      OidcAccessTokenAuthenticator.new(
        access_token: "token",
        resource_type: "operator",
        host: "app.example.test",
      )
    visitor_authenticator =
      OidcAccessTokenAuthenticator.new(
        access_token: "token",
        resource_type: "visitor",
        host: "app.example.test",
      )

    token_resource = Struct.new(:staff, :visitor, :user).new(:staff_value, :visitor_value, :user_value)

    assert_equal :staff_value, operator_authenticator.send(:token_resource, token_resource)
    assert_equal :visitor_value, visitor_authenticator.send(:token_resource, token_resource)
    assert_equal :user_value, client_authenticator.send(:token_resource, token_resource)
    assert_equal OperatorToken, operator_authenticator.send(:token_class_for_resource_type)
    assert_equal OrgTicketRecord, operator_authenticator.send(:token_context)
    assert_equal VisitorToken, visitor_authenticator.send(:token_class_for_resource_type)
    assert_equal ComTicketRecord, visitor_authenticator.send(:token_context)
    assert_equal ClientToken, client_authenticator.send(:token_class_for_resource_type)
    assert_equal AppTicketRecord, client_authenticator.send(:token_context)
    assert_equal OperatorTokenUsage, operator_authenticator.send(:usage_class_for_resource_type)
    assert_equal VisitorTokenUsage, visitor_authenticator.send(:usage_class_for_resource_type)
    assert_equal ClientTokenUsage, client_authenticator.send(:usage_class_for_resource_type)

    failure = client_authenticator.send(:failure, "invalid_token")

    assert_not failure.success?
    assert_equal "invalid_token", failure.error
  end

  test "private helpers cover DPoP edge cases, token lookup, and subject and scope checks" do
    authenticator =
      OidcAccessTokenAuthenticator.new(
        access_token: "token",
        resource_type: "client",
        host: "app.example.test",
        authorization_scheme: "DPoP",
        dpop_proof: "proof",
        request_method: "POST",
        request_uri: "/oauth/token",
      )

    assert_not authenticator.send(:dpop_valid?, { "cnf" => {} })

    verifier = Object.new
    verifier.define_singleton_method(:call) do |*|
      Struct.new(:valid?).new(true)
    end

    original_new = DpopRequestVerifier.method(:new)
    DpopRequestVerifier.define_singleton_method(:new) { |*_args, **_kwargs| verifier }
    begin
      assert authenticator.send(:dpop_valid?, { "cnf" => { "jkt" => "thumbprint" } })
    ensure
      DpopRequestVerifier.define_singleton_method(:new, original_new)
    end

    context = Object.new
    context.define_singleton_method(:connected_to) do |*_args, _role: nil, **_options, &block|
      block.call
    end
    token_class =
      Class.new do
        def self.find_by(oidc_sid:)
          (oidc_sid == "sid-1") ? :token : nil
        end
      end

    authenticator.stub(:token_context, context) do
      authenticator.stub(:token_class_for_resource_type, token_class) do
        assert_nil authenticator.send(:find_token, {})
        assert_equal :token, authenticator.send(:find_token, { "sid" => "sid-1" })
      end
    end

    resource = Client.create!(status_id: ClientStatus::ACTIVE)

    assert_not authenticator.send(:token_scope_allows_userinfo?, { "scope" => "" })
    assert authenticator.send(:token_scope_allows_userinfo?, { "scope" => "openid" })
    assert_not authenticator.send(:token_subject_matches?, resource, { "sub" => "wrong" })
    assert authenticator.send(
      :token_subject_matches?, resource,
      { "sub" => OidcSubject.for(resource, resource_type: "client") },
    )
  end

  test "a token that cannot name an OIDC client never belongs to an audience" do
    authenticator = build_authenticator
    tokenless_client = Object.new

    assert_not authenticator.send(:token_belongs_to_audience?, tokenless_client, { "aud" => ["anything"] })
  end

  test "a token naming an unregistered client never belongs to an audience" do
    authenticator = build_authenticator
    token = Struct.new(:oidc_client_id).new("client-that-is-not-registered")

    assert_nil OidcClientRegistry.find(token.oidc_client_id)
    assert_not authenticator.send(:token_belongs_to_audience?, token, { "aud" => ["anything"] })
  end

  test "a token without a recorded jti accepts any payload jti" do
    authenticator = build_authenticator
    token = Object.new

    assert authenticator.send(:token_jti_matches?, token, { "jti" => "whatever" })
  end

  test "a jti of a different length is rejected before the constant time compare" do
    authenticator = build_authenticator
    token = Struct.new(:oidc_jti).new("jti-value")

    assert_not authenticator.send(:token_jti_matches?, token, { "jti" => "jti-value-that-is-longer" })
    assert_not authenticator.send(:token_jti_matches?, token, { "jti" => "short" })
    assert authenticator.send(:token_jti_matches?, token, { "jti" => "jti-value" })
  end

  private

  def build_authenticator
    OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
  end
end
