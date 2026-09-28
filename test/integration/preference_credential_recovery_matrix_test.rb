# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/invalid-browser-credential-recovery.md, Preference. A refused preference credential on an HTML
# GET or HEAD is detached with deletions that match the issued cookies, the page renders from clean
# display defaults, and nothing is persisted. The old row's settings never reach a new credential.
# JSON keeps the 401 contract. A refusal without a confirmed cause is a system failure and raises.
class PreferenceCredentialRecoveryMatrixTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: { host_env: "PUBLIC_BASE_SERVICE_URL", model: "AppPreference", theme: :base_app_preference_theme_path },
    com: { host_env: "PUBLIC_BASE_CORPORATE_URL", model: "ComPreference", theme: :base_com_preference_theme_path },
    org: { host_env: "PUBLIC_BASE_STAFF_URL", model: "OrgPreference", theme: :base_org_preference_theme_path },
  }.freeze

  ACCESS = PreferenceCookieName.access
  REFRESH = PreferenceCookieName.refresh
  DBSC = PreferenceCookieName.dbsc
  DARK = 2
  LIGHT = 1

  setup { https! }

  # --- Every surface: forged, unknown, and malformed credentials -----------------------------------

  SURFACES.each do |surface, config|
    test "#{surface}: a wrong verifier on a real public_id is detached on GET with the issued cookie identity" do
      host! ENV.fetch(config[:host_env])
      issued, preference = write_preference(config, DARK)
      before = preference.reload.attributes

      assert_no_difference -> { preference_class(config).count } do
        get "/preference?ri=jp", headers: cookie_header(
          ACCESS => "invalid.access.jwt",
          REFRESH => preference_class(config).build_refresh_token(
            preference.public_id,
            SecureRandom.urlsafe_base64(32),
          ),
        )
      end

      assert_response :success
      assert_cookie_deleted(REFRESH, issued: issued[REFRESH])
      assert_cookie_deleted(ACCESS, issued: issued[ACCESS])
      assert_equal before, preference.reload.attributes, "a forged credential must not touch the real row"
    end

    test "#{surface}: a refresh credential whose public_id does not exist is detached without a row" do
      host! ENV.fetch(config[:host_env])

      assert_no_difference -> { preference_class(config).count } do
        get "/preference?ri=jp", headers: cookie_header(REFRESH => unknown_refresh_token(config))
      end

      assert_response :success
      assert_cookie_deleted(REFRESH)
    end

    test "#{surface}: HEAD with a malformed refresh credential is detached without a row" do
      host! ENV.fetch(config[:host_env])

      assert_no_difference -> { preference_class(config).count } do
        head "/preference?ri=jp", headers: cookie_header(REFRESH => "garbage")
      end

      assert_response :success
      assert_cookie_deleted(REFRESH)
    end

    test "#{surface}: a DBSC-bound credential without its bound cookie is detached with its DBSC cookie" do
      host! ENV.fetch(config[:host_env])
      issued, preference = write_preference(config, DARK)
      bind_dbsc!(preference)

      logs =
        capture_logs do
          get(
            "/preference?ri=jp",
            headers: cookie_header(REFRESH => issued[REFRESH][:value], DBSC => "other-session"),
          )
        end

      assert_response :success
      [REFRESH, DBSC].each { |name| assert_cookie_deleted(name) }
      assert_equal %w(binding_denied credential_rejection detached),
                   recovery_events(logs).sole.values_at("failure", "category", "outcome")
    end

    test "#{surface}: a JSON read keeps the 401 contract with the same body for every refusal reason" do
      host! ENV.fetch(config[:host_env])
      _issued, preference = write_preference(config, DARK)
      bodies =
        [
          unknown_refresh_token(config),
          preference_class(config).build_refresh_token(preference.public_id, SecureRandom.urlsafe_base64(32)),
          "garbage",
        ].map do |token|
          get("/preference.json?ri=jp", headers: cookie_header(REFRESH => token))

          assert_response :unauthorized
          [response.status, response.parsed_body]
        end

      assert_equal 1, bodies.uniq.size
      assert_equal "invalid_refresh_token", bodies.first.last.fetch("error_code")
      assert_equal %w(error error_code), bodies.first.last.keys.sort
    end
  end

  # --- EP/BVA on the refresh credential value (app) ------------------------------------------------

  {
    "a lone separator" => ".",
    "a missing verifier" => "publicid.",
    "a missing public_id" => ".verifier",
    "an extra component" => "a.b.c",
    "a percent-encoded NUL" => "abc%00def",
    "invalid UTF-8 bytes" => "%FF%FE.%C3%28",
    "an oversized value" => "a" * 4000,
    "a truncated token" => :truncated,
    "an unknown token version" => "v9$#{SecureRandom.urlsafe_base64(32)}",
  }.each do |label, value|
    test "app: a refresh credential with #{label} is detached on GET without a row" do
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      if value == :truncated
        issued, = write_preference(SURFACES[:app], DARK)
        value = issued[REFRESH][:value][0...-6]
      end

      assert_no_difference -> { AppPreference.count } do
        get "/preference?ri=jp", headers: cookie_header(REFRESH => value)
      end

      assert_response :success
      assert_cookie_deleted(REFRESH)
    end
  end

  # Rack strips surrounding whitespace from cookie values, so a whitespace-only credential reaches
  # the application as the empty value: the same partition as no credential at all.
  { "absent" => nil, "empty" => "", "whitespace-only" => "  " }.each do |label, value|
    test "app: an #{label} refresh credential renders defaults, deletes nothing, and creates no row" do
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      headers = value.nil? ? {} : cookie_header(REFRESH => value)

      assert_no_difference -> { AppPreference.count } do
        get "/preference?ri=jp", headers: headers
      end

      assert_response :success
      assert_no_set_cookie(REFRESH)
    end
  end

  test "app: the last valid instant before discard is read, the discard instant is detached" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, preference = write_preference(SURFACES[:app], DARK)
    token = issued[REFRESH][:value]
    now = Time.current.change(usec: 0)

    travel_to(now) do
      preference.update_columns(discard_at: now + 1.second)
      get "/preference?ri=jp", headers: cookie_header(REFRESH => token)

      assert_response :success
      assert_no_set_cookie(REFRESH)

      preference.update_columns(discard_at: now)
      logs = capture_logs { get("/preference?ri=jp", headers: cookie_header(REFRESH => token)) }

      assert_response :success
      assert_cookie_deleted(REFRESH)
      assert_equal %w(expired_or_revoked lifecycle), recovery_events(logs).sole.values_at("failure", "category")
    end
  end

  test "app: an ordinarily deleted preference is detached as a lifecycle end" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, preference = write_preference(SURFACES[:app], DARK)
    preference.update_columns(status_id: AppPreferenceStatus::DELETED)

    logs = capture_logs { get("/preference?ri=jp", headers: cookie_header(REFRESH => issued[REFRESH][:value])) }

    assert_response :success
    assert_cookie_deleted(REFRESH)
    assert_equal %w(ordinarily_deleted lifecycle), recovery_events(logs).sole.values_at("failure", "category")
  end

  # --- Non-persistence ---------------------------------------------------------------------------

  test "an invalid credential GET inserts no preference, child, or audit row and rotates nothing" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, preference = write_preference(SURFACES[:app], DARK)
    forged = AppPreference.build_refresh_token(preference.public_id, SecureRandom.urlsafe_base64(32))
    counts = -> { [AppPreference.count, AppPreferenceTheme.count, AppPreferenceRegion.count] }
    before = counts.call

    get "/preference?ri=jp", headers: cookie_header(REFRESH => forged)
    head "/preference?ri=jp", headers: cookie_header(REFRESH => forged)
    get "/edge/v0/cookie", headers: cookie_header(REFRESH => forged).merge("Accept" => "application/json")

    assert_equal before, counts.call
    assert_nil preference.reload.used_at
    assert_equal issued[REFRESH][:value].split(".").first, preference.public_id
    assert_no_set_cookie(PreferenceIoKeys::Cookies::THEME)
  end

  # --- Old-state laundering ----------------------------------------------------------------------

  test "recovery never copies the refused row's region, language, or theme into the next preference" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    patch base_app_preference_region_path(ri: "us"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }
    patch base_app_preference_theme_path(ri: "us"), params: { preference_theme: { option_id: DARK } }
    old = AppPreference.find_by!(public_id: cookies[REFRESH].to_s.split(".").first)

    assert_equal [AppPreferenceRegionOption::US, DARK],
                 [old.app_preference_region.option_id, old.app_preference_theme.option_id]
    forged = AppPreference.build_refresh_token(old.public_id, SecureRandom.urlsafe_base64(32))
    reset!
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get "/preference?ri=jp", headers: cookie_header(REFRESH => forged)

    assert_response :success
    assert_cookie_deleted(REFRESH)
    assert_not_includes response.body, %("theme":"dark")

    # The next explicit write sets only the theme. Region comes from the request (ri=jp), which
    # differs from the old row's US, so an equal value could only have been copied.
    assert_difference -> { AppPreference.count }, 1 do
      patch base_app_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: LIGHT } }
    end
    fresh = AppPreference.order(:created_at).last

    assert_not_equal old.id, fresh.id
    assert_not_equal old.public_id, fresh.public_id
    assert_equal LIGHT, fresh.app_preference_theme.option_id
    assert_not_equal AppPreferenceRegionOption::US, fresh.app_preference_region&.option_id
    assert_equal [AppPreferenceRegionOption::US, DARK],
                 [old.reload.app_preference_region.option_id, old.app_preference_theme.option_id]
  end

  # --- Concurrency: same generation, response inversion, rotation boundary --------------------------

  test "two reads of the same generation both succeed without rotation, replay, or deletion" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, preference = write_preference(SURFACES[:app], DARK)
    token = issued[REFRESH][:value]

    2.times do
      get "/preference?ri=jp", headers: cookie_header(REFRESH => token)

      assert_response :success
      assert_no_set_cookie(REFRESH)
    end
    assert_nil preference.reload.used_at
    assert_predicate preference.discard_at, :future?
  end

  test "a read that raced a rotating write never deletes the newer generation in either response order" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, old = write_preference(SURFACES[:app], DARK)
    generation_n = issued[REFRESH][:value]

    # A: a write presenting N without an access token rotates N -> N+1.
    patch base_app_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: LIGHT } },
                                                    headers: cookie_header(REFRESH => generation_n)

    assert_response :redirect
    response_a = set_cookie_entries(REFRESH)
    generation_n1 = assert_cookie_issued(REFRESH)[:value]

    assert_not_equal generation_n, generation_n1

    # B: a read that left the browser with N before A's response arrived.
    logs = capture_logs { get("/preference?ri=jp", headers: cookie_header(REFRESH => generation_n)) }

    assert_response :success
    response_b = set_cookie_entries(REFRESH)

    assert_empty response_b, "a stale read must not write the refresh cookie"
    assert_no_set_cookie(ACCESS)
    assert_equal %w(superseded_generation lifecycle detached_stale_generation),
                 recovery_events(logs).sole.values_at("failure", "category", "outcome")

    # Whichever response the browser applies last, the stored credential is N+1.
    [[response_a, response_b], [response_b, response_a]].each do |order|
      final = order.flatten.last&.fetch(:value) || generation_n

      assert_equal generation_n1, final
    end

    successor = AppPreference.find_by!(public_id: generation_n1.split(".").first)

    assert_predicate successor.discard_at, :future?, "the stale read must not revoke the newer generation"
    assert_predicate old.reload.discard_at, :future?, "an ordinary rotation is not a compromise"

    get "/preference?ri=jp", headers: cookie_header(REFRESH => generation_n1)

    assert_response :success
    assert_no_set_cookie(REFRESH)
  end

  test "a superseded generation past the concurrency window is detached so recovery ends" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, = write_preference(SURFACES[:app], DARK)
    generation_n = issued[REFRESH][:value]
    patch base_app_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: LIGHT } },
                                                    headers: cookie_header(REFRESH => generation_n)

    assert_response :redirect

    travel(PreferenceTransport::PREFERENCE_STALE_GENERATION_WINDOW + 1.second) do
      logs = capture_logs { get("/preference?ri=jp", headers: cookie_header(REFRESH => generation_n)) }

      assert_response :success
      assert_cookie_deleted(REFRESH)
      assert_equal "replay_detected", recovery_events(logs).sole.fetch("failure")

      get "/preference?ri=jp"

      assert_response :success
      assert_no_set_cookie(REFRESH)
    end
  end

  test "a stale write is refused under the serialized write contract without revoking the newer generation" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, = write_preference(SURFACES[:app], DARK)
    generation_n = issued[REFRESH][:value]
    patch base_app_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: LIGHT } },
                                                    headers: cookie_header(REFRESH => generation_n)
    generation_n1 = assert_cookie_issued(REFRESH)[:value]

    patch base_app_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: DARK } },
                                                    headers: cookie_header(REFRESH => generation_n)

    assert_response :unauthorized
    successor = AppPreference.find_by!(public_id: generation_n1.split(".").first)

    assert_predicate successor.discard_at, :future?
    assert_nil successor.used_at

    get "/preference?ri=jp", headers: cookie_header(REFRESH => generation_n1)

    assert_response :success
    assert_no_set_cookie(REFRESH)
  end

  # --- Observability -----------------------------------------------------------------------------

  test "the recovery event names surface, kind, reason, and request without credential material" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    _issued, preference = write_preference(SURFACES[:app], DARK)
    verifier = SecureRandom.urlsafe_base64(32)
    forged = AppPreference.build_refresh_token(preference.public_id, verifier)

    logs = capture_logs { get("/preference?ri=jp", headers: cookie_header(REFRESH => forged)) }
    event = recovery_events(logs).sole

    assert_equal %w(digest_mismatch credential_rejection read_only_lookup detached app),
                 event.values_at("failure", "category", "stage", "outcome", "surface")
    assert_predicate event.fetch("request_id"), :present?
    assert_not_includes logs, verifier
    assert_not_includes logs, forged
    assert_not_includes logs, Base64.strict_encode64(AppPreference.digest_refresh_token(verifier))
  end

  # --- System failures -----------------------------------------------------------------------------

  test "a database failure during the preference lookup propagates instead of detaching" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, = write_preference(SURFACES[:app], DARK)

    AppPreference.stub(:includes, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        get "/preference?ri=jp", headers: cookie_header(REFRESH => issued[REFRESH][:value])
      end
    end
  end

  test "a rotation that finds its still-valid row unconsumable raises instead of refusing the credential" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, preference = write_preference(SURFACES[:app], DARK)

    AppPreference.stub(:rotate!, nil) do
      assert_raises(PreferenceBase::ResolutionError) do
        patch base_app_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: LIGHT } },
                                                        headers: cookie_header(REFRESH => issued[REFRESH][:value])
      end
    end
    assert_nil preference.reload.used_at
  end

  test "a rotation that loses its row to a concurrent revocation names the lifecycle state" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    issued, preference = write_preference(SURFACES[:app], DARK)
    revoke_then_fail =
      lambda do |**|
        preference.update_columns(discard_at: Time.current)
        nil
      end

    logs =
      AppPreference.stub(:rotate!, revoke_then_fail) do
        capture_logs do
          patch(
            base_app_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: LIGHT } },
                                                      headers: cookie_header(REFRESH => issued[REFRESH][:value]),
          )
        end
      end

    assert_response :unauthorized
    assert_equal %w(expired_or_revoked rotation rejected),
                 recovery_events(logs).sole.values_at("failure", "stage", "outcome")
  end

  private

  def preference_class(config)
    config[:model].constantize
  end

  def unknown_refresh_token(config)
    preference_class(config).generate_refresh_token(public_id: SecureRandom.alphanumeric(21)).first
  end

  # Creates a preference through the real write boundary. Returns the issued cookie entries and row.
  def write_preference(config, theme)
    patch(public_send(config[:theme], ri: "jp"), params: { preference_theme: { option_id: theme } })

    assert_response :redirect
    issued = { REFRESH => assert_cookie_issued(REFRESH), ACCESS => assert_cookie_issued(ACCESS) }
    public_id = issued[REFRESH][:value].split(".").first
    [issued, preference_class(config).find_by!(public_id: public_id)]
  end

  def bind_dbsc!(preference)
    klass = preference.class
    prefix = klass.name
    preference.update_columns(
      binding_method_id: "#{prefix}BindingMethod".constantize::DBSC,
      dbsc_status_id: "#{prefix}DbscStatus".constantize::ACTIVE,
      dbsc_session_id: "bound-#{SecureRandom.hex(8)}",
    )
  end

  def cookie_header(values)
    { "Cookie" => values.map { |name, value| "#{name}=#{value}" }.join("; ") }
  end

  def capture_logs
    buffer = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(buffer)
    yield
    buffer.string
  ensure
    Rails.logger = previous
  end

  def recovery_events(logs)
    logs.each_line.filter_map do |line|
      json = line[/\{.*\}/]
      next unless json

      parsed = JSON.parse(json)
      data = parsed["data"]
      data if parsed["event"] == "preference.credential.recovery" && data["stage"]
    rescue JSON::ParserError
      nil
    end
  end
end
