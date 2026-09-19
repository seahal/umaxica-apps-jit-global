# typed: false
# frozen_string_literal: true

require "test_helper"

# The access cookie is transparently reissued mid-request so a signed-in person
# is not signed out at the TTL boundary. The reissue must not outlive the session
# it was minted from, must carry that session's own identifiers, and must leave
# the existing cookie alone if a new token could not be produced -- replacing a
# working cookie with nothing would sign the person out.
class AuthenticationReissueAccessTokenTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include ::AuthenticationJwtTokens

    attr_accessor :resource, :session_record, :cookies, :encode_calls

    def initialize
      @cookies = {}
      @encode_calls = []
    end

    def invoke(name, ...) = send(name, ...)

    def current_resource = resource

    def current_session = session_record

    def resource_type = "client"

    def auth_jwt_issuer_id = "surface:SIGN_APP"

    def request = Struct.new(:host).new("auth.umaxica.app")

    def cookie_options = { httponly: true, secure: true }

    def token_session_public_id(record) = record.public_id

    def token_record_attribute(record, name) = record.respond_to?(name) ? record.public_send(name) : nil

    def token_record_expiry_at(record) = record.discarded_at
  end

  def session_double(public_id: "session-1", discarded_at: 1.day.from_now, oidc_jti: SecureRandom.uuid,
                     authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5))
    Struct.new(:public_id, :discarded_at, :oidc_jti, :dpop_jkt, :authentication_event_at)
      .new(public_id, discarded_at, oidc_jti, "jkt-1", authentication_event_at)
  end

  def build_harness(session_record)
    harness = Harness.new
    harness.resource = Struct.new(:id).new(1)
    harness.session_record = session_record
    harness
  end

  def with_encode(token, harness, &)
    recorder =
      lambda do |_resource, **kwargs|
        harness.encode_calls << kwargs
        token
      end
    AuthenticationToken.stub(:encode, recorder, &)
  end

  test "the reissued cookie carries the session's identifiers and its own expiry" do
    session_record = session_double
    harness = build_harness(session_record)

    with_encode("new-access-token", harness) { harness.invoke(:reissue_access_token!) }

    cookie = harness.cookies.fetch(AuthenticationBase::ACCESS_COOKIE_KEY)

    assert_equal "new-access-token", cookie.fetch(:value)
    assert cookie.fetch(:httponly), "the reissue must keep the original cookie options"

    call = harness.encode_calls.sole

    assert_equal "session-1", call.fetch(:session_public_id)
    assert_equal "session-1", call.fetch(:oidc_sid)
    assert_equal session_record.oidc_jti, call.fetch(:oidc_jti)
    assert_equal "jkt-1", call.fetch(:dpop_jkt)
    assert_equal session_record.authentication_event_at, call.fetch(:auth_time)
  end

  # The session is the shorter-lived of the two, so its expiry wins; a reissue
  # that outlived its session would keep a revoked session usable.
  test "the reissue never outlives the session it was minted from" do
    ending_soon = session_double(discarded_at: 1.minute.from_now)
    harness = build_harness(ending_soon)

    with_encode("new-access-token", harness) { harness.invoke(:reissue_access_token!) }

    assert_equal ending_soon.discarded_at,
                 harness.cookies.fetch(AuthenticationBase::ACCESS_COOKIE_KEY).fetch(:expires)

    long_lived = session_double(discarded_at: 10.years.from_now)
    later = build_harness(long_lived)

    with_encode("new-access-token", later) { later.invoke(:reissue_access_token!) }

    assert_operator later.cookies.fetch(AuthenticationBase::ACCESS_COOKIE_KEY).fetch(:expires),
                    :<, long_lived.discarded_at
  end

  test "nothing is reissued without a resource or a session" do
    no_resource = build_harness(session_double)
    no_resource.resource = nil

    assert_nil no_resource.invoke(:reissue_access_token!)
    assert_empty no_resource.cookies

    no_session = build_harness(nil)

    assert_nil no_session.invoke(:reissue_access_token!)
    assert_empty no_session.cookies
  end

  test "a token that could not be minted leaves the existing cookie alone" do
    harness = build_harness(session_double)

    with_encode(nil, harness) { harness.invoke(:reissue_access_token!) }

    assert_empty harness.cookies, "replacing a working cookie with nothing would sign the person out"
  end

  test "the oidc sid falls back through the session id, the recorded sid, and the public id" do
    harness = build_harness(session_double)
    from_session = Struct.new(:public_id, :oidc_sid).new("session-1", "recorded-sid")

    assert_equal "session-1", harness.invoke(:token_record_oidc_sid, from_session)

    recorded = Struct.new(:public_id, :oidc_sid).new(nil, "recorded-sid")

    assert_equal "recorded-sid", harness.invoke(:token_record_oidc_sid, recorded)
  end
end
