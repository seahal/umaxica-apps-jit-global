# frozen_string_literal: true

require "minitest/autorun"
require "rails"
require "action_controller"
require "active_support/all"
require "active_support/testing/assertions"
require "stringio"
require_relative "../../lib/jit_log_event"
require_relative "../../app/values/dbsc_header_parser"
require_relative "../../app/services/application_service"
require_relative "../../app/services/dbsc_record_adapter"
require_relative "../../app/lib/dbsc_proof_verifier"
require_relative "../../app/services/dbsc_verification_service"
require_relative "../../app/serializers/dbsc_header_serializer"
require_relative "../../app/controllers/concerns/auth_io_keys"
require_relative "../../app/controllers/concerns/preference_io_keys"
require_relative "../../app/controllers/concerns/dbsc_request_logging"
require_relative "../../app/controllers/concerns/dbsc_canonical_url"
require_relative "../../app/controllers/concerns/sign_dbsc_registration_endpoint"
require_relative "../../app/controllers/concerns/preference_dbsc_registration_endpoint"

class DbscHeaderBoundaryTest < Minitest::Test
  include ActiveSupport::Testing::Assertions

  Record = Struct.new(:dbsc_session_id, :dbsc_challenge, :dbsc_public_key, :dbsc_challenge_issued_at)

  # These hosts supply only persistence/identity dependencies; the public Rails
  # dispatch, input parsing, response generation and logging use production code.
  class SignController < ActionController::API
    include SignDbscRegistrationEndpoint

    def initialize(record)
      super()
      @record = record
    end

    private

    def dbsc_url = "https://example.com/dbsc"

    def dbsc_token_record = @record

    def issue_dbsc_challenge_for!(record)
      record.dbsc_challenge = "private-challenge"
    end
  end

  class PreferenceController < ActionController::API
    include PreferenceDbscRegistrationEndpoint

    def initialize(record)
      super()
      @record = record
    end

    private

    def dbsc_url = "https://example.com/dbsc"

    def current_preference_record = @record

    def issue_preference_dbsc_challenge_for!(record)
      record.dbsc_challenge = "private-challenge"
    end
  end

  def setup
    @previous_logger = Rails.logger
    @logs = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@logs)
  end

  def teardown
    Rails.logger = @previous_logger
  end

  def test_issues_challenge_only_for_the_registered_identifier_without_logging_secrets
    [SignController, PreferenceController].each do |controller_class|
      record = Record.new("private-session", "old-challenge")
      request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/dbsc", method: "POST"))
      request.set_header("HTTP_SEC_SECURE_SESSION_ID", '"private-session";ignored="value"')
      response = ActionDispatch::Response.new

      controller_class.new(record).dispatch(:create, request, response)

      assert_equal 403, response.status
      assert_equal '"private-challenge";id="private-session"', response.get_header("Secure-Session-Challenge")
      assert_equal "private-challenge", record.dbsc_challenge
      assert_equal "no-store", response.get_header("Cache-Control")
    end
    assert_includes @logs.string, "dbsc.challenge.issued"
    assert_empty @logs.string.scan(/private-challenge|private-session/)
  end

  def test_rejects_malformed_fields_before_changing_a_challenge
    [SignController, PreferenceController].each do |controller_class|
      ["session", 's";extra="v', '"session"junk', '"session", "other"', '"bad\\n"',
       '""', "\"session\r\nInjected: value\"",].each do |input|
        record = Record.new("session", "old-challenge")
        request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/dbsc", method: "POST"))
        request.set_header("HTTP_SEC_SECURE_SESSION_ID", input)
        response = ActionDispatch::Response.new

        controller_class.new(record).dispatch(:create, request, response)

        assert_equal 400, response.status, input.inspect
        assert_nil response.get_header("Secure-Session-Challenge")
        assert_equal "old-challenge", record.dbsc_challenge
        assert_nil response.get_header("Set-Cookie")
      end
    end

    assert_empty @logs.string.scan(/old-challenge|Injected/)
  end

  def test_rejects_unknown_or_unregistered_identifiers_before_changing_a_challenge
    [SignController, PreferenceController].each do |controller_class|
      [nil, "", "different-session"].each do |registered|
        record = Record.new(registered, "old-challenge")
        request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/dbsc", method: "POST"))
        request.set_header("HTTP_SEC_SECURE_SESSION_ID", '"session"')
        response = ActionDispatch::Response.new

        controller_class.new(record).dispatch(:create, request, response)

        assert_equal 403, response.status
        assert_nil response.get_header("Secure-Session-Challenge")
        assert_equal "old-challenge", record.dbsc_challenge
      end
    end
  end

  def test_refuses_a_request_without_the_corresponding_record
    [SignController, PreferenceController].each do |controller_class|
      request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/dbsc", method: "POST"))
      request.set_header("HTTP_SEC_SECURE_SESSION_ID", '"session"')
      response = ActionDispatch::Response.new

      controller_class.new(nil).dispatch(:create, request, response)

      assert_equal 401, response.status
      assert_nil response.get_header("Secure-Session-Challenge")
    end
  end

  def test_decodes_proofs_once_and_rejects_wrong_audiences_and_signatures_without_mutation
    Time.use_zone("UTC") do
      key = OpenSSL::PKey::EC.generate("prime256v1")
      other_key = OpenSSL::PKey::EC.generate("prime256v1")
      now = Time.current
      [SignController, PreferenceController].each do |controller_class|
        { "https://other.example/dbsc" => "audience_mismatch",
          "https://example.com/dbsc" => "invalid_proof", }.each do |audience, error|
          record = Record.new("private-session", "old-challenge", JWT::JWK.new(key).export, now)
          proof = JWT.encode(
            { jti: "old-challenge", aud: audience, iat: now.to_i },
            other_key, "ES256", { typ: "dbsc+jwt" },
          )
          request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/dbsc", method: "POST"))
          request.set_header("HTTP_SEC_SECURE_SESSION_ID", '"private-session"')
          request.set_header("HTTP_SECURE_SESSION_RESPONSE", DbscHeaderSerializer.string(proof))
          response = ActionDispatch::Response.new

          controller_class.new(record).dispatch(:create, request, response)

          assert_equal 422, response.status
          assert_equal error, JSON.parse(response.body).fetch("error_code")
          assert_equal "old-challenge", record.dbsc_challenge
          assert_nil response.get_header("Set-Cookie")
        end
      end

      assert_empty @logs.string.scan(/old-challenge|private-session|eyJ/)
    end
  end
end
