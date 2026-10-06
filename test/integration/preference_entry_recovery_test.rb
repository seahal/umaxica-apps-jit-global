# typed: false
# frozen_string_literal: true

require "test_helper"

# An unusable preference credential left in the browser must not stop the sign-in and sign-up
# entry on the first operation. The Auth entry and the Base "start" POST detach the credential for
# the rest of the request and continue with display defaults; they never adopt, rotate, or re-create
# a preference from it, and every non-preference gate (admission, CSRF, logged-in refusal) still runs.
# Preference endpoints and JSON callers keep the existing 401 refusal.
class PreferenceEntryRecoveryTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: { auth_env: "PUBLIC_AUTH_SERVICE_URL",
           base_env: "PUBLIC_BASE_SERVICE_URL",
           preference: "AppPreference",
           sign_in: :auth_app_sign_in_url,
           sign_in_path: :auth_app_sign_in_path,
           base_sign: :base_app_sign_show_path, },
    com: { auth_env: "PUBLIC_AUTH_CORPORATE_URL",
           base_env: "PUBLIC_BASE_CORPORATE_URL",
           preference: "ComPreference",
           sign_in: :auth_com_sign_in_url,
           sign_in_path: :auth_com_sign_in_path,
           base_sign: :base_com_sign_show_path, },
    org: { auth_env: "PUBLIC_AUTH_STAFF_URL",
           base_env: "PUBLIC_BASE_STAFF_URL",
           preference: "OrgPreference",
           sign_in: :auth_org_sign_in_url,
           sign_in_path: :auth_org_sign_in_path,
           base_sign: :base_org_sign_show_path, },
  }.freeze

  SURFACES.each do |surface, config|
    test "#{surface}: a refresh cookie whose record does not exist reaches the sign-in ceremony on the first try" do
      host! ENV.fetch(config[:auth_env])
      plant_refresh_cookie(surface, stale_refresh_token(config))
      reference = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: surface.to_s, intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
      ).reference
      preference_class = config[:preference].constantize

      logs =
        capture_logs do
          assert_no_difference -> { preference_class.count } do
            get(public_send(config[:sign_in], ri: "jp", entry_ref: reference))
          end
        end

      assert_response :success
      assert_includes logs, "preference.credential.recovery"
      assert_includes logs, "record_not_found"
      assert_includes logs, %q("outcome":"detached")

      post public_send(config[:sign_in_path], ri: "jp"), params: {
        entry_ref: reference,
        authenticity_token: authenticity_token_from_body,
      }

      assert_response :see_other
      assert_equal "/sign/in", URI.parse(response.location).path
      assert_predicate ClientAuthCeremonySession.order(created_at: :desc).first, :admitted? if surface == :app
    end

    test "#{surface}: HEAD on the sign-in entry with a stale refresh cookie is not an empty 401" do
      host! ENV.fetch(config[:auth_env])
      plant_refresh_cookie(surface, stale_refresh_token(config))

      head public_send(config[:sign_in], ri: "jp")

      assert_not_equal 401, response.status
      assert_empty response.body
    end

    test "#{surface}: the Base neutral sign POST proceeds with a stale refresh cookie and creates no preference" do
      host! ENV.fetch(config[:base_env])
      plant_refresh_cookie(surface, stale_refresh_token(config))
      preference_class = config[:preference].constantize

      assert_no_difference -> { preference_class.count } do
        post public_send(config[:base_sign], ri: "jp")
      end

      assert_response :see_other
      assert_predicate refresh_cookie(surface).to_s, :empty?,
                       "the POST boundary retires the unusable credential it was presented"
    end

    test "#{surface}: JSON callers keep the 401 refusal for a stale refresh cookie" do
      host! ENV.fetch(config[:base_env])
      plant_refresh_cookie(surface, stale_refresh_token(config))

      post public_send(config[:base_sign], ri: "jp", format: :json)

      assert_response :unauthorized
      assert_equal "invalid_refresh_token", response.parsed_body["error_code"]
    end
  end

  test "the Auth entry still refuses a direct entry without admission when the credential is detached" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    plant_refresh_cookie(:app, stale_refresh_token(SURFACES[:app]))

    get auth_app_sign_in_url(ri: "jp")

    assert_response :bad_request
    assert_nil response.location
  end

  test "the org sign-up guide still renders with a stale refresh cookie" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    plant_refresh_cookie(:org, stale_refresh_token(SURFACES[:org]))

    get auth_org_sign_up_url(ri: "jp")

    assert_not_equal 401, response.status
  end

  # Expiry boundary, entry GET: one second before expiry the credential is still usable and is read
  # without rotation; at and after the expiry instant it is detached. The response is a success in
  # every case, and the record is never written on GET.
  test "expiry boundary: a refresh credential just before, at, and just after expiry" do
    token, preference = persisted_app_preference_credential
    now = Time.current.change(usec: 0)

    { "one second before expiry" => [now + 1.second, false],
      "at the expiry instant" => [now, true],
      "one second after expiry" => [now - 1.second, true], }.each do |label, (expires_at, detached)|
      preference.update_columns(expires_at: expires_at)
      before = preference.reload.attributes

      travel_to(now) do
        open_session do |browser|
          browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
          browser.cookies[PreferenceCookieName.refresh(surface: :app)] = token
          reference = BaseAuthAdmissionCoordinator.issue_local_entry!(
            surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
          ).reference

          logs = capture_logs { browser.get(auth_app_sign_in_path(ri: "jp", entry_ref: reference)) }

          assert_equal 200, browser.response.status, label
          assert_equal detached, logs.include?(%q("outcome":"detached")), label
          assert_includes logs, "expired_or_revoked", label if detached
        end
      end

      assert_equal before, preference.reload.attributes, "#{label}: GET must not write the preference"
    end
  end

  test "a digest mismatch on a real preference is detached without touching the record" do
    token, preference = persisted_app_preference_credential
    forged = AppPreference.build_refresh_token(preference.public_id, SecureRandom.urlsafe_base64(32))
    before = preference.reload.attributes
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    plant_refresh_cookie(:app, forged)
    reference = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    ).reference

    logs = capture_logs { get(auth_app_sign_in_path(ri: "jp", entry_ref: reference)) }

    assert_response :success
    assert_includes logs, "digest_mismatch"
    assert_equal before, preference.reload.attributes
    assert_predicate token, :present?
  end

  test "a revoked preference is detached on the entry GET and is not revived" do
    token, preference = persisted_app_preference_credential
    preference.update_columns(discard_at: 1.minute.ago)
    before = preference.reload.attributes
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    plant_refresh_cookie(:app, token)
    reference = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    ).reference

    logs = capture_logs { get(auth_app_sign_in_path(ri: "jp", entry_ref: reference)) }

    assert_response :success
    assert_includes logs, "expired_or_revoked"
    assert_equal before, preference.reload.attributes
  end

  test "an access JWT naming a missing record is not re-read after detachment" do
    token, preference = persisted_app_preference_credential
    access = cookies[PreferenceCookieName.access(surface: :app)]
    preference.update_columns(discard_at: 1.minute.ago)
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    plant_refresh_cookie(:app, token)
    cookies[PreferenceCookieName.access(surface: :app)] = access
    reference = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    ).reference

    get auth_app_sign_in_path(ri: "jp", entry_ref: reference)

    assert_response :success
    assert_nil response.headers["Set-Cookie"].to_s[/#{Regexp.escape(PreferenceIoKeys::Cookies::THEME)}=/o],
               "a detached GET must not write public option cookies"
  end

  test "a preference endpoint clears a stale refresh credential and renders clean defaults" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    plant_refresh_cookie(:app, stale_refresh_token(SURFACES[:app]))

    get "/preference?ri=jp"

    assert_response :success
    assert_predicate refresh_cookie(:app).to_s, :empty?
  end

  test "a replayed refresh credential on the Auth POST is still marked, detached, and never re-issued" do
    first_refresh, preference = persisted_app_preference_credential
    cookies.delete(PreferenceCookieName.access(surface: :app))
    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::LIGHT } }

    assert_response :redirect
    assert_predicate preference.reload.used_at, :present?, "the second write rotates the first credential"

    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    reference = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    ).reference
    get auth_app_sign_in_path(ri: "jp", entry_ref: reference)

    assert_response :success
    token = authenticity_token_from_body
    plant_refresh_cookie(:app, first_refresh)

    logs =
      capture_logs do
        assert_no_difference -> { AppPreference.count } do
          post(auth_app_sign_in_path(ri: "jp"), params: { entry_ref: reference, authenticity_token: token })
        end
      end

    assert_response :see_other
    assert_includes logs, "replay_detected"
    assert_operator preference.reload.discard_at, :<=, Time.current, "replay handling still revokes the row"
    assert_predicate refresh_cookie(:app).to_s, :empty?
  end

  test "a detached credential does not bypass CSRF on the Auth POST" do
    ActionController::Base.allow_forgery_protection = true
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    plant_refresh_cookie(:app, stale_refresh_token(SURFACES[:app]))
    reference = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
    ).reference

    post(
      auth_app_sign_in_path(ri: "jp"), params: { entry_ref: reference, authenticity_token: "stale-page-token" },
                                       headers: { "Sec-Fetch-Site" => "cross-site" },
    )

    assert_not_equal 303, response.status
    assert_nil ClientAuthCeremonySession.order(created_at: :desc).first&.then { |r| r.admitted? || nil }
  ensure
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  private

  def stale_refresh_token(config)
    config[:preference].constantize.generate_refresh_token(public_id: SecureRandom.alphanumeric(21)).first
  end

  def plant_refresh_cookie(surface, token)
    cookies[PreferenceCookieName.refresh(surface: surface)] = token
  end

  def refresh_cookie(surface)
    cookies[PreferenceCookieName.refresh(surface: surface)]
  end

  # Creates a preference through the real write boundary and returns its refresh token.
  def persisted_app_preference_credential
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    patch(
      base_app_preference_theme_path(ri: "jp"),
      params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK } },
    )

    assert_response :redirect
    token = cookies[PreferenceCookieName.refresh(surface: :app)]
    public_id, = AppPreference.parse_refresh_token(token)
    [token, AppPreference.find_by!(public_id: public_id)]
  end

  def authenticity_token_from_body
    response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1]
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
end
