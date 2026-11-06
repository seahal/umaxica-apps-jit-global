# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWua3InitialAttachRaceTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  REALMS = [
    { surface: "app",
      host_env: "PUBLIC_AUTH_SERVICE_URL",
      binding: ClientAuthAdmissionBinding,
      ceremony: ClientAuthCeremonySession,
      sign_in_path: "/sign/in", },
    { surface: "org",
      host_env: "PUBLIC_AUTH_STAFF_URL",
      binding: OperatorAuthAdmissionBinding,
      ceremony: OperatorAuthCeremonySession,
      sign_in_path: "/sign/in", },
  ].freeze

  setup do
    @previous_sign_in_flags =
      REALMS.to_h do |realm|
        surface = realm.fetch(:surface)
        feature = FeatureFlags::REGISTRY.fetch(:"sign_in_available_#{surface}").name
        [feature, Flipper.enabled?(feature)]
      end
  end

  teardown do
    @previous_sign_in_flags.each do |feature, enabled|
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "AC-53: either initial auth_sid arrival order leaves only its last target usable" do
    REALMS.each do |realm|
      [[0, 1], [1, 0]].each do |delivery_order|
        losing_index = delivery_order.first
        winning_index = delivery_order.last
        host = ENV.fetch(realm.fetch(:host_env))
        nonce = SecureRandom.urlsafe_base64(32)
        issuances =
          2.times.map do
            OidcTestEntry.issue!(
              surface: realm.fetch(:surface), intent: "sign_in", base_browser_nonce: nonce,
              base_token: nil,
            )
          end
        browsers =
          issuances.map do
            browser = open_session
            browser.host!(host)
            browser.https!
            browser
          end
        bindings =
          issuances.zip(browsers).map do |issuance, browser|
            binding = attach_auth_ceremony_entry!(
              realm.fetch(:sign_in_path),
              reference: issuance.reference,
              params: { ri: "jp" },
              browser:,
            )

            assert_equal 303, browser.response.status
            assert_predicate binding.reload, :attached?
            assert_equal AuthAdmissionBinding::ATTACHED_STATUS_ID, binding.status_id
            binding
          end
        cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        auth_sids = browsers.map { |browser| browser.cookies[cookie_name] }

        assert auth_sids.all?(&:present?)
        assert_not_equal auth_sids.first, auth_sids.last

        shared_browser = open_session
        shared_browser.host!(host)
        shared_browser.https!
        delivery_order.each do |index|
          store_raw_cookies(
            shared_browser.cookies,
            "#{cookie_name}=#{Rack::Utils.escape(auth_sids.fetch(index))}",
            URI.parse("https://#{host}/"),
          )
        end
        losing_binding = bindings.fetch(losing_index)
        losing_parent = issuances.fetch(losing_index).transaction
        losing_session = realm.fetch(:ceremony).find(losing_binding.auth_ceremony_session_id)
        before = [losing_binding.reload.attributes, losing_parent.reload.attributes,
                  losing_session.reload.attributes, realm.fetch(:ceremony).count,]

        shared_browser.get(
          realm.fetch(:sign_in_path),
          params: { entry_ref: issuances.fetch(losing_index).reference, ri: "jp" },
          headers: NAVIGATION_HEADERS,
        )

        assert_equal 409, shared_browser.response.status
        assert_nil shared_browser.response.location
        assert_equal I18n.t("errors.messages.phase_violation_refused"), shared_browser.response.body
        assert_equal "private, no-store", shared_browser.response.headers["Cache-Control"]
        assert_equal "no-referrer", shared_browser.response.headers["Referrer-Policy"]
        assert_no_authentication_cookie(shared_browser.response.headers["Set-Cookie"])
        response_header_names = shared_browser.response.headers.to_h.keys.map(&:downcase)

        assert_empty AuthPhaseRefusalResponseBoundary::DBSC_HEADERS & response_header_names
        assert_equal before, [losing_binding.reload.attributes, losing_parent.reload.attributes,
                              losing_session.reload.attributes, realm.fetch(:ceremony).count,]

        shared_browser.get(
          "/ceremony_bindings",
          params: { entry_ref: issuances.fetch(losing_index).reference, ri: "jp" },
          headers: NAVIGATION_HEADERS,
        )

        assert_equal 409, shared_browser.response.status
        assert_nil shared_browser.response.location
        assert_no_authentication_cookie(shared_browser.response.headers["Set-Cookie"])
        response_header_names = shared_browser.response.headers.to_h.keys.map(&:downcase)

        assert_empty AuthPhaseRefusalResponseBoundary::DBSC_HEADERS & response_header_names
        assert_equal before, [losing_binding.reload.attributes, losing_parent.reload.attributes,
                              losing_session.reload.attributes, realm.fetch(:ceremony).count,]

        winning_binding = bindings.fetch(winning_index)
        winning_parent = issuances.fetch(winning_index).transaction
        winning_binding.confirm_base!(base_token: nil, browser_digest: winning_binding.base_browser_digest)
        shared_browser.get(
          realm.fetch(:sign_in_path),
          params: { entry_ref: issuances.fetch(winning_index).reference, ri: "jp" },
          headers: NAVIGATION_HEADERS,
        )

        assert_equal 303, shared_browser.response.status
        assert_predicate winning_binding.reload, :redeemed?
        assert_equal AuthAdmissionBinding::REDEEMED_STATUS_ID, winning_binding.status_id
        admitted = realm.fetch(:ceremony).find(winning_binding.admitted_auth_ceremony_session_id)

        assert_equal AuthCeremonySession::STATUS_ADMITTED, admitted.status_id
        assert_equal "pending", winning_parent.reload.status_name
        assert_equal AuthAdmissionBinding::ATTACHED_STATUS_ID, losing_binding.reload.status_id
        assert_predicate losing_session.reload, :active?
        assert_not_predicate losing_session, :admitted?

        purge_time = losing_parent.expires_at + 31.days
        cutoff = purge_time - 30.days

        realm.fetch(:binding).stub(:database_now, cutoff - 1.second) do
          assert AuthAdmissionBindingPurger.purge_for_parent!(
            parent: losing_parent, now: purge_time, retention_period: 30.days,
          )
        end
        assert_not realm.fetch(:binding).exists?(id: losing_binding.id)
        assert_not realm.fetch(:ceremony).exists?(id: losing_session.id)
      end
    end
  end

  test "AC-53: the current auth_sid makes the other admitted first target unreachable" do
    REALMS.each do |realm|
      surface = realm.fetch(:surface)
      feature = FeatureFlags::REGISTRY.fetch(:"sign_in_available_#{surface}").name
      Flipper.enable(feature)

      [[0, 1], [1, 0]].each do |delivery_order|
        host = ENV.fetch(realm.fetch(:host_env))
        issuances =
          2.times.map do
            OidcTestEntry.issue!(
              surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
            )
          end
        browsers =
          issuances.map do
            browser = open_session
            browser.host!(host)
            browser.https!
            browser
          end
        bindings =
          issuances.zip(browsers).map do |issuance, browser|
            browser.get(
              "/ceremony_bindings",
              params: { entry_ref: issuance.reference, ri: "jp" },
              headers: NAVIGATION_HEADERS,
            )

            assert_equal 303, browser.response.status
            binding = realm.fetch(:binding).find_by!(entry_ref: issuance.reference)
            binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
            browser.get(
              realm.fetch(:sign_in_path),
              params: { entry_ref: issuance.reference, ri: "jp" },
              headers: NAVIGATION_HEADERS,
            )

            assert_equal 303, browser.response.status
            assert_predicate binding.reload, :redeemed?
            ceremony = realm.fetch(:ceremony).find(binding.admitted_auth_ceremony_session_id)

            assert_predicate ceremony, :admitted?
            binding
          end

        cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        auth_sids = browsers.map { |browser| browser.cookies[cookie_name] }

        assert auth_sids.all?(&:present?)
        assert_not_equal auth_sids.first, auth_sids.last
        shared_browser = open_session
        shared_browser.host!(host)
        shared_browser.https!
        delivery_order.each do |index|
          store_raw_cookies(
            shared_browser.cookies,
            "#{cookie_name}=#{Rack::Utils.escape(auth_sids.fetch(index))}",
            URI.parse("https://#{host}/"),
          )
        end

        losing_index = delivery_order.first
        winning_index = delivery_order.last
        losing_binding = bindings.fetch(losing_index)
        winning_binding = bindings.fetch(winning_index)
        losing_session = realm.fetch(:ceremony).find(losing_binding.admitted_auth_ceremony_session_id)
        winning_session = realm.fetch(:ceremony).find(winning_binding.admitted_auth_ceremony_session_id)
        before = [
          losing_binding.reload.attributes,
          issuances.fetch(losing_index).transaction.reload.attributes,
          losing_session.reload.attributes,
          winning_binding.reload.attributes,
          issuances.fetch(winning_index).transaction.reload.attributes,
          winning_session.reload.attributes,
          shared_browser.cookies.to_hash,
        ]

        shared_browser.get(
          realm.fetch(:sign_in_path),
          params: { entry_ref: issuances.fetch(losing_index).reference, ri: "jp" },
          headers: NAVIGATION_HEADERS,
        )

        assert_equal 409, shared_browser.response.status, "#{surface} losing initial admitted target"
        assert_equal "private, no-store", shared_browser.response.headers["Cache-Control"]
        assert_equal "no-referrer", shared_browser.response.headers["Referrer-Policy"]
        assert_no_authentication_cookie(shared_browser.response.headers["Set-Cookie"])
        response_header_names = shared_browser.response.headers.to_h.keys.map(&:downcase)

        assert_empty AuthPhaseRefusalResponseBoundary::DBSC_HEADERS & response_header_names
        after = [
          losing_binding.reload.attributes,
          issuances.fetch(losing_index).transaction.reload.attributes,
          losing_session.reload.attributes,
          winning_binding.reload.attributes,
          issuances.fetch(winning_index).transaction.reload.attributes,
          winning_session.reload.attributes,
          shared_browser.cookies.to_hash,
        ]

        assert_equal before, after, "#{surface} losing target changed either admitted attempt"
        assert_equal winning_session.id, realm.fetch(:ceremony).find_active_by_raw_sid(
          shared_browser.cookies[cookie_name],
        )&.id

        shared_browser.get(realm.fetch(:sign_in_path), params: { ri: "jp" }, headers: NAVIGATION_HEADERS)

        assert_equal 200, shared_browser.response.status
        assert_equal winning_session.id, realm.fetch(:ceremony).find_active_by_raw_sid(
          shared_browser.cookies[cookie_name],
        )&.id
      end
    end
  end

  private

  def assert_no_authentication_cookie(value)
    cookie_lines = value.is_a?(Array) ? value : value.to_s.split("\n")
    authentication_cookies = AuthPhaseRefusalResponseBoundary::COOKIE_NAMES
    unexpected_cookies =
      cookie_lines.filter_map do |line|
        cookie_name = line.split("=", 2).first
        cookie_name if authentication_cookies.include?(cookie_name)
      end

    assert_empty unexpected_cookies
  end
end
