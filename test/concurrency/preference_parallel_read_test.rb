# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/invalid-browser-credential-recovery.md, Preference: GET never rotates, so reads presenting the
# same refresh generation at the same moment cannot produce a false replay, a deletion, or a new
# row. Transactional tests would share one connection, so this test commits one preference row,
# runs the reads on separate threads and connections, and removes its row afterwards. Rotating
# writes are not run here because they append chronicle audit rows that cannot be removed; their
# interleavings are covered by PreferenceCredentialRecoveryMatrixTest.
class PreferenceParallelReadTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  READERS = 4

  setup do
    now = Time.current
    @preference = AppPreference.create!(
      discard_at: 400.days.from_now, jti: JitSecurityJwtJtiGenerator.generate,
      binding_method_id: AppPreferenceBindingMethod::LEGACY, dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
      created_at: now, updated_at: now,
    )
    @token, verifier = AppPreference.generate_refresh_token(public_id: @preference.public_id)
    @preference.update!(token_digest: AppPreference.digest_refresh_token(verifier))
  end

  teardown do
    AppPreference.where(id: @preference.id).delete_all
  end

  test "parallel reads of one generation all succeed without replay, deletion, rotation, or insert" do
    count_before = AppPreference.count
    start = Queue.new
    results = Queue.new
    threads =
      Array.new(READERS) do
        Thread.new do # rubocop:disable ThreadSafety/NewThread -- parallel connections are the point of this test
          session = open_session
          session.https!
          session.host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
          start.pop
          session.get("/preference?ri=jp", headers: { "Cookie" => "#{PreferenceCookieName.refresh}=#{@token}" })
          set_cookie = Array(session.response.headers["set-cookie"]).join("\n")
          results << [session.response.status, set_cookie.include?("#{PreferenceCookieName.refresh}=")]
        end
      end
    READERS.times { start << true }
    threads.each(&:join)

    outcomes = Array.new(READERS) { results.pop }

    assert_equal [[200, false]] * READERS, outcomes
    @preference.reload

    assert_nil @preference.used_at
    assert_predicate @preference.discard_at, :future?
    assert_equal count_before, AppPreference.count
  end
end
