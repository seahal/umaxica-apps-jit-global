# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationCurrentResourceResolverCoverageTest < ActiveSupport::TestCase
  FakeResource = Struct.new(:id)
  FakeSuspendedResource =
    Struct.new(:id) do
      def suspended? = true

      def terminated? = false

      def withdrawn? = false

      def deactivated? = true
    end

  class FakeTokenClass
    class << self
      def column_names
        %w(public_id oidc_sid oidc_jti last_used_at created_at)
      end

      def where(*)
        self
      end

      def includes(*)
        self
      end

      def or(*)
        self
      end

      def order(*)
        self
      end

      def first
        @token
      end

      def token=(value)
        @token = value
      end
    end
  end

  class FakeResourceClass
    def self.find_by(id:)
      (id == 123) ? FakeResource.new(id) : nil
    end
  end

  class FakeSuspendedResourceClass
    def self.find_by(id:)
      (id == 123) ? FakeSuspendedResource.new(id) : nil
    end
  end

  setup do
    FakeTokenClass.token = nil
  end

  test "blank access token fails fast" do
    result = AuthenticationCurrentResourceResolver.new(
      access_token: nil,
      request_host: "app.example.test",
      resource_type: "client",
      resource_class: FakeResourceClass,
      token_class: FakeTokenClass,
    ).call

    assert_equal :blank_access_token, result.failure_reason
  end

  test "dpop and actor mismatches are rejected before session lookup" do
    AuthenticationToken.stub(
      :decode,
      { "sub" => "123", "sid" => "sess-1", "scope" => "domain:operator", "cnf" => { "jkt" => "a" } },
    ) do
      AuthenticationToken.stub(:resource_type_scope_matches?, false) do
        resolver = AuthenticationCurrentResourceResolver.new(
          access_token: "token",
          request_host: "app.example.test",
          resource_type: "client",
          resource_class: FakeResourceClass,
          token_class: FakeTokenClass,
          authorization_scheme: "DPoP",
          dpop_proof: "proof",
          request_method: "GET",
          request_uri: "/user",
        )

        resolver.stub(:dpop_valid?, true) do
          result = resolver.call

          assert_equal :actor_mismatch, result.failure_reason
        end
      end
    end
  end

  test "missing session id and missing resource are rejected" do
    AuthenticationToken.stub(:decode, { "sub" => "123", "scope" => "domain:client" }) do
      AuthenticationToken.stub(:resource_type_scope_matches?, true) do
        result = AuthenticationCurrentResourceResolver.new(
          access_token: "token",
          request_host: "app.example.test",
          resource_type: "client",
          resource_class: FakeResourceClass,
          token_class: FakeTokenClass,
        ).call

        assert_equal :missing_session_id, result.failure_reason
      end
    end
  end

  test "successful resolution touches activity when the token is stale enough" do
    token =
      Struct.new(:public_id, :oidc_jti, :last_used_at, :created_at) do
        def has_attribute?(name)
          %i(public_id oidc_jti last_used_at created_at).include?(name.to_sym)
        end

        def update_columns(attrs)
          @updated_columns = attrs
          attrs.each { |key, value| self[key] = value }
          true
        end

        def updated_columns
          @updated_columns
        end
      end.new("sess-1", nil, 10.minutes.ago, 10.minutes.ago)

    FakeTokenClass.token = token

    AuthenticationToken.stub(:decode, { "sub" => "123", "sid" => "sess-1", "scope" => "domain:client" }) do
      AuthenticationToken.stub(:resource_type_scope_matches?, true) do
        AuthenticationToken.stub(:extract_session_id, "sess-1") do
          AuthenticationToken.stub(:extract_subject, "123") do
            result = AuthenticationCurrentResourceResolver.new(
              access_token: "token",
              request_host: "app.example.test",
              resource_type: "client",
              resource_class: FakeResourceClass,
              token_class: FakeTokenClass,
            ).call

            assert_equal 123, result.resource.id
            assert_not_nil token.updated_columns
          end
        end
      end
    end
  end

  test "suspended client access token fails before normal current resource is built" do
    token =
      Struct.new(:public_id, :oidc_jti, :last_used_at, :created_at) do
        def has_attribute?(name)
          %i(public_id oidc_jti last_used_at created_at).include?(name.to_sym)
        end
      end.new("sess-1", nil, 10.minutes.ago, 10.minutes.ago)

    FakeTokenClass.token = token

    AuthenticationToken.stub(:decode, { "sub" => "123", "sid" => "sess-1", "scope" => "domain:client" }) do
      AuthenticationToken.stub(:resource_type_scope_matches?, true) do
        AuthenticationToken.stub(:extract_session_id, "sess-1") do
          AuthenticationToken.stub(:extract_subject, "123") do
            result = AuthenticationCurrentResourceResolver.new(
              access_token: "token",
              request_host: "app.example.test",
              resource_type: "client",
              resource_class: FakeSuspendedResourceClass,
              token_class: FakeTokenClass,
            ).call

            assert_nil result.resource
            assert_equal :withdrawal_required, result.failure_reason
          end
        end
      end
    end
  end
end

class AuthenticationCurrentResourceResolverCoverageTest
  test "resolver rejects decoded, dpop, and binding edge cases" do
    build =
      lambda do |**options|
        AuthenticationCurrentResourceResolver.new(
          access_token: "token", request_host: "app.example.test", resource_type: "client",
          resource_class: FakeResourceClass, token_class: FakeTokenClass, **options,
        )
      end

    AuthenticationToken.stub(:decode, nil) do
      AuthenticationToken.stub(:extract_session_id_allow_expired, "expired-sid") do
        assert_equal :token_decode_failed, build.call.call.failure_reason
      end
      AuthenticationToken.stub(:extract_session_id_allow_expired, nil) do
        assert_equal :token_decode_failed, build.call.call.failure_reason
      end
    end

    resolver = build.call

    assert resolver.send(:dpop_valid?, { "cnf" => {} })
    assert_not resolver.send(:dpop_valid?, { "cnf" => { "jkt" => "jkt" } })
    dpop_resolver = build.call(
      authorization_scheme: "DPoP", dpop_proof: "proof", request_method: "GET",
      request_uri: "/",
    )

    assert_not dpop_resolver.send(:dpop_valid?, { "cnf" => {} })
    result = Struct.new(:valid?).new(false)

    DpopRequestVerifier.stub(:new, ->(**) { OpenStruct.new(call: result) }) do
      assert_not dpop_resolver.send(:dpop_valid?, { "cnf" => { "jkt" => "jkt" } })
    end

    AuthenticationToken.stub(:decode, { "sub" => "123", "sid" => "sid", "scope" => "domain:client" }) do
      AuthenticationToken.stub(:resource_type_scope_matches?, true) do
        AuthenticationToken.stub(:extract_session_id, "sid") do
          FakeTokenClass.token = nil

          assert_equal :token_session_not_found, build.call.send(:call).failure_reason
        end
      end
    end

    token = Struct.new(:oidc_jti, :dpop_jkt) do
      def has_attribute?(name) = %i(oidc_jti dpop_jkt).include?(name.to_sym)
    end.new("record-jti", "record-jkt")

    assert_not resolver.send(:token_jti_current?, token, { "jti" => "different" })
    assert_not resolver.send(:token_dpop_binding_current?, token, { "cnf" => { "jkt" => "different" } })
    assert resolver.send(:token_dpop_binding_current?, token, { "cnf" => { "jkt" => "record-jkt" } })
  end
end
