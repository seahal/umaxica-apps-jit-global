# typed: false
# frozen_string_literal: true

require "test_helper"

# The OP's public name resolves to this container in local environments, where nothing listens on
# 443, so its JWKS is fetched like the other first-party server-to-server calls.
class OidcOpJwksClientTransportTest < ActiveSupport::TestCase
  Response =
    Data.define(:body) do
      def success? = false
    end

  class LeaseLimiter
    public

    def acquire(_issuer_key)
      OidcJwksRefetchLimiter::Decision.new(kind: :lease, outcome: nil, kids: [])
    end

    def record(_issuer_key, outcome:, kids:)
    end
  end

  class RecordingConnection
    def initialize(captured)
      @captured = captured
    end

    public

    def get(url)
      @captured[:got] = url
      Response.new(body: "")
    end
  end

  test "a first-party OP JWKS is fetched over the local back channel in a local environment" do
    host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host

    request = requested_transport("https://#{host}/.well-known/jwks.json")

    assert_equal "http://#{host}:#{OutboundHttp::LocalBackChannel.local_port}/.well-known/jwks.json",
                 request.fetch(:got)
    assert_not request.fetch(:require_https)
  end

  test "a first-party OP JWKS keeps its public HTTPS URL in production" do
    host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host
    public_url = "https://#{host}/.well-known/jwks.json"

    request =
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        requested_transport(public_url)
      end

    assert_equal public_url, request.fetch(:got)
    assert request.fetch(:require_https)
  end

  test "a JWKS on any other host keeps its public HTTPS URL in a local environment" do
    public_url = "https://op.example.test/.well-known/jwks.json"

    request = requested_transport(public_url)

    assert_equal public_url, request.fetch(:got)
    assert request.fetch(:require_https)
  end

  private

  def requested_transport(jwks_uri)
    captured = {}
    connection = RecordingConnection.new(captured)
    build =
      lambda do |url:, require_https:, **|
        captured[:require_https] = require_https

        assert_equal url, OutboundHttp::LocalBackChannel.url(jwks_uri)
        connection
      end

    OutboundHttp::Connection.stub(:build, build) do
      lookup = OidcOpJwksClient.new(jwks_uri:, limiter: LeaseLimiter.new).lookup("kid")

      assert_predicate lookup, :unavailable?
    end
    captured
  end
end
