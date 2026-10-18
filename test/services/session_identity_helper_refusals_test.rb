# typed: false
# frozen_string_literal: true

require "test_helper"

# Small comparisons and derivations that decide whether a session is spared, an
# address is real, a proof is trusted, or a host belongs to a brand edition. Each
# has one arm that answers conservatively, and each conservative answer is the
# safe one: revoke rather than spare, refuse rather than trust, raise rather than
# guess.
class SessionIdentityHelperRefusalsTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities

  # The sign-in email state is either a real address the surface holds or a dummy
  # stood up so an unknown address is answered identically to a known one.
  test "an email authentication state without a record is a dummy" do
    real = SignAppInEmailAuthenticationState.new(id: 7, address: "person@example.com")
    dummy = SignAppInEmailAuthenticationState.new(id: nil, address: "unknown@example.com")

    assert_predicate real, :existing?
    assert_not real.dummy?
    assert_not dummy.existing?
    assert_predicate dummy, :dummy?
  end

  # A stored public key that is not usable JWK material is server-side state, not
  # a client-supplied proof, and is reported separately so operations does not
  # read data corruption as a hijack attempt.
  test "an unusable stored DBSC key is reported apart from an invalid proof" do
    record =
      Struct.new(:dbsc_session_id, :dbsc_public_key, :dbsc_challenge, :dbsc_challenge_issued_at)
        .new("session-1", %({"kty":"oct","k":"c2VjcmV0"}), "challenge", Time.current)
    validator = Object.new
    validator.define_singleton_method(:call) do
      Struct.new(:ok, :error_code, :message, :header).new(true, nil, nil, {})
    end
    service = DbscVerificationService.new(record: record, session_id: "session-1", proof: "proof")
    service.instance_variable_set(:@proof_validator, validator)

    result = service.call

    assert_not result[:ok]
    assert_equal "invalid_public_key", result[:error_code]
  end

  test "a request missing the pieces a DBSC proof needs is refused by name" do
    {
      { record: nil, session_id: "s", proof: "p" } => "record_missing",
      { record: Object.new, session_id: "", proof: "p" } => "missing_session_id",
      { record: Object.new, session_id: "s", proof: "" } => "missing_proof",
    }.each do |arguments, expected|
      result = DbscVerificationService.new(**arguments).call

      assert_not result[:ok]
      assert_equal expected, result[:error_code]
    end
  end

  test "a host with no brand edition among its labels is refused rather than guessed at" do
    helper = Object.new.extend(ApplicationHelper)
    helper.define_singleton_method(:request) { Struct.new(:host).new("example.test") }

    error = assert_raises(ArgumentError) { helper.brand_tld }

    assert_match(/Cannot derive a brand TLD/, error.message)
  end

  test "a host carrying a brand edition reports it in upper case" do
    { "www.umaxica.app" => "APP", "www.umaxica.com" => "COM", "base.dev.localhost" => "DEV" }
      .each do |host, expected|
        helper = Object.new.extend(ApplicationHelper)
        helper.define_singleton_method(:request) { Struct.new(:host).new(host) }

        assert_equal expected, helper.brand_tld, host
      end
  end
end
