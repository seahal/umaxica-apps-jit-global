# typed: false
# frozen_string_literal: true

# Snapshot diffs would expose OTP material and token state on assertion failure.

require "test_helper"
# require "helpers/global_test_support"

class Auth::Com::Sign::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveSupport::Testing::TimeHelpers

  setup do
    VisitorSignInFlowState::DEFAULTS.each { |id| VisitorSignInFlowState.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    cookies["csrf_token"] = csrf_token_value
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    https!
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "com", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = VisitorAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    get(auth_com_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })

    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    admission_headers = { "Origin" => "https://#{request.host}", "Sec-Fetch-Site" => "same-origin" }
    post(
      "/ceremony_bindings", params: { entry_ref: issuance.reference, ri: "jp", authenticity_token: csrf },
                            headers: admission_headers,
    )

    assert_response :see_other
    # Public confirmation isolates this leaf's setup; separate HTTP tests exercise the Base receiver.
    binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get(auth_com_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })

    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      auth_com_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf },
                                       headers: admission_headers,
    )

    assert_response :see_other
    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP)
      VisitorTokenDbscStatus.ensure_defaults!
      VisitorTokenStatus::DEFAULTS.each do |id|
        VisitorTokenStatus.find_or_create_by!(id: id)
      end
    end
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "should get new" do
    get new_auth_com_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_equal "auth/com/sign/up/emails/new", inertia_component
    assert_equal "render", inertia_props.fetch("turnstile").fetch("mode")
    assert_equal I18n.t("sign.com.registration.email.new.page_title"), inertia_props.fetch("title")
    assert_equal "visitor_email", inertia_props.fetch("scope")
    assert_equal "", inertia_props.fetch("field").fetch("value")
    checkbox_names = inertia_props.fetch("checkboxes").map { |checkbox| checkbox.fetch("name") }

    assert_includes checkbox_names, "notifiable"
    assert_not_includes checkbox_names, "promotional"
    assert_no_match(/UMAXICA \(sign, app\)/, response.body)
  end

  test "edit renders authentication code copy" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "com-code-copy-#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "HTTPS" => "on" }

    assert_response :redirect
    target = URI.parse(response.location)

    assert_equal "/sign/up/check/email/otp", target.path
    assert_predicate Rack::Utils.parse_query(target.query).fetch("fb"), :present?
    get target.request_uri

    assert_response :success
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
    props = page.fetch("props")

    assert_equal "auth/com/sign/up/emails/edit", page.fetch("component")
    assert_equal I18n.t("sign.app.authentication.email.edit.page_title"), props.fetch("title")
    assert_equal I18n.t("sign.app.authentication.email.edit.code_label"), props.fetch("code_label")
    assert_equal I18n.t("sign.app.authentication.email.edit.code_placeholder"),
                 props.fetch("code_placeholder")
    assert_equal "visitor_email", props.fetch("scope")
    assert_equal I18n.t("sign.app.authentication.email.edit.submit"), props.fetch("submit_label")
    assert_includes response.body, "メールアドレス"
    assert_equal I18n.t("sign.app.authentication.email.edit.delivery_help"),
                 props.fetch("delivery_help")
  end

  test "new keeps an admitted ceremony independent of a presented root token" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    original_token_facts = token.attributes
    credential = AuthenticationToken.encode(
      visitor, host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
               session_public_id: token.public_id, resource_type: "visitor",
    )
    headers = { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
                "HTTPS" => "on",
                "Authorization" => "Bearer #{credential}", }

    assert_no_difference(["VisitorToken.count", "VisitorEmail.count"]) do
      get new_auth_com_sign_up_email_url(ri: "jp"), headers: headers
    end

    assert_response :success
    assert_withheld("protected record facts remain unchanged") { original_token_facts == token.reload.attributes }
  end

  test "create keeps an admitted ceremony independent of a presented root token" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    original_token_facts = token.attributes
    credential = AuthenticationToken.encode(
      visitor, host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
               session_public_id: token.public_id, resource_type: "visitor",
    )
    headers = { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
                "HTTPS" => "on",
                "Authorization" => "Bearer #{credential}", }

    assert_difference("VisitorEmail.count", 1) do
      assert_no_difference("VisitorToken.count") do
        post auth_com_sign_up_email_url(ri: "jp"),
             params: { visitor_email: { raw_address: "logged-in-com@example.com", confirm_policy: "1" },
                       "cf-turnstile-response": "test", }, headers: headers
      end
    end

    assert_response :redirect
    target = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), target.host
    assert_equal URI.parse(auth_com_sign_up_check_email_otp_path(ri: "jp")).path, target.path
    flow = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))
    candidate = VisitorEmail.find(flow.pending_contact_id)

    assert_not_equal visitor.id, candidate.visitor_id
    assert_nil candidate.binding_finalized_at
    assert_equal flow.public_id,
                 SignFlowBindingCodec.decode(Rack::Utils.parse_query(target.query).fetch("fb")).flow_public_id
    assert_withheld("protected record facts remain unchanged") { original_token_facts == token.reload.attributes }
  end

  test "collection get is not routed" do
    get auth_com_sign_up_email_url(ri: "jp", hotwire_spark: true, reload: "123"), headers: default_headers

    assert_response :not_found
  end

  test "includes navigation link back to sign in" do
    get new_auth_com_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    link_hrefs = inertia_props.fetch("links").map { |link| link.fetch("href") }

    assert_equal [auth_com_sign_up_path(ri: "jp"), auth_com_sign_in_path(ri: "jp")], link_hrefs
  end

  test "create redirects to edit and allows edit page" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "com-flow-step@example.com",
             confirm_policy: "1",
             notifiable: "0",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect
    public_id = VisitorEmail.order(:created_at).last.public_id

    assert_not VisitorEmail.find_by!(public_id: public_id).notifiable

    follow_redirect!

    assert_response :success
    assert_equal "/sign/up/check/email/otp", path
  end

  test "create renders unprocessable when visitor_email param missing" do
    assert_no_difference("VisitorEmail.count") do
      post auth_com_sign_up_email_url(ri: "jp"),
           params: { "cf-turnstile-response": "test" },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("errors").join(" "),
                    I18n.t("sign.com.registration.email.create.address_required")
  end

  test "create renders unprocessable when turnstile fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_no_difference("VisitorEmail.count") do
      post auth_com_sign_up_email_url(ri: "jp"),
           params: {
             visitor_email: {
               raw_address: "turnstile-failure@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("errors").join(" "),
                    I18n.t("sign.com.registration.email.create.turnstile_validation_failed")
  end

  test "create beside an effective email owns an independent candidate without altering the binding" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    existing_email = VisitorEmail.create!(
      visitor: visitor,
      address: "com-existing-signup@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      binding_finalized_at: VisitorEmail.database_now,
    )
    original_facts = existing_email.reload.attributes
    original_owner_facts = visitor.reload.attributes

    assert_difference("Visitor.count", 1) do
      assert_difference("VisitorEmail.count", 1) do
        assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
          post auth_com_sign_up_email_url(ri: "jp"),
               params: {
                 visitor_email: {
                   raw_address: existing_email.address,
                   confirm_policy: "1",
                 },
                 "cf-turnstile-response": "test",
               },
               headers: { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "HTTPS" => "on" }
        end
      end
    end

    assert_response :redirect
    assert_includes response.location, "/sign/up/check/email/otp"
    flow = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))
    candidate = VisitorEmail.find(flow.pending_contact_id)
    target = URI.parse(response.location)

    assert_equal flow.public_id,
                 SignFlowBindingCodec.decode(Rack::Utils.parse_query(target.query).fetch("fb")).flow_public_id
    assert_not_equal existing_email.id, candidate.id
    assert_not_equal existing_email.visitor_id, candidate.visitor_id
    assert_equal existing_email.address_digest, candidate.address_digest
    assert_nil candidate.binding_finalized_at
    assert_withheld("protected record facts remain unchanged") { original_facts == existing_email.reload.attributes }
    assert_withheld("protected record facts remain unchanged") { original_owner_facts == visitor.reload.attributes }
  end

  test "replacement email signup retains the halted candidate and Identity until retention purge" do
    destination = "com-replacement-#{SecureRandom.hex(8)}@example.test"
    submission = {
      visitor_email: { raw_address: destination, confirm_policy: "1" }, "cf-turnstile-response": "test",
    }
    post auth_com_sign_up_email_url(ri: "jp"), params: submission, headers: default_headers

    assert_response :redirect
    first = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))
    candidate = VisitorEmail.find(first.pending_contact_id)
    owner_id = candidate.visitor_id

    travel EmailOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      assert_difference("VisitorEmail.count", 1) do
        assert_difference("Visitor.count", 1) do
          post auth_com_sign_up_email_url(ri: "jp"), params: submission, headers: default_headers
        end
      end
    end

    assert_response :redirect
    assert VisitorEmail.exists?(candidate.id)
    assert Visitor.exists?(owner_id)
    assert_predicate first.reload, :sign_up_halted?
    assert_predicate first, :cleanup_completed?
    assert_operator candidate.reload.purge_eligible_at, :>, candidate.discard_at
    assert_empty VisitorEmailHistory.where(visitor_id: owner_id)
  end

  test "fresh sessions cannot distinguish pending and registered email sign-up" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    existing = VisitorEmail.create!(
      visitor: visitor, raw_address: "com-fresh-session-registered-signup@example.com", confirm_policy: true,
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      binding_finalized_at: VisitorEmail.database_now,
    )
    existing_facts = existing.reload.attributes
    existing_owner_facts = visitor.reload.attributes
    responses = []
    candidates = []
    browsers = []
    targets = []

    [existing.address, "com-fresh-session-pending-signup@example.com"].each do |destination|
      2.times do
        browser = open_session
        browser.host!(ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"))
        browser.https!
        issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "com", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
        binding = VisitorAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
        browser.get(auth_com_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        headers = { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")}", "Sec-Fetch-Site" => "same-origin" }
        browser.post(
          "/ceremony_bindings",
          params: { entry_ref: issuance.reference, ri: "jp", authenticity_token: csrf }, headers: headers,
        )

        assert_equal 303, browser.response.status
        binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        browser.get(auth_com_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        browser.post(
          auth_com_sign_up_path(ri: "jp"),
          params: { entry_ref: issuance.reference, authenticity_token: csrf }, headers: headers,
        )

        assert_equal 303, browser.response.status
        assert_difference("VisitorEmail.count", 1) do
          browser.post(
            auth_com_sign_up_email_url(ri: "jp"),
            params: { visitor_email: { raw_address: destination, confirm_policy: "1" },
                      "cf-turnstile-response": "test", }, headers: headers,
          )
        end

        assert_equal 302, browser.response.status
        target = URI.parse(browser.response.location)
        query = Rack::Utils.parse_query(target.query)

        assert_equal %w(fb ri), query.keys.sort
        assert_equal "jp", query.fetch("ri")
        responses << [browser.response.status, target.scheme, target.host, target.path, query.keys.sort]
        candidate = VisitorEmail.order(:created_at, :id).last
        candidates << candidate
        browsers << browser
        targets << target

        assert_equal destination, candidate.address
        assert_nil candidate.binding_finalized_at
      end
    end

    assert_equal 1, responses.uniq.length
    assert_equal 4, candidates.map(&:id).uniq.length
    assert_equal 4, candidates.map(&:visitor_id).uniq.length
    assert_withheld("protected record facts remain unchanged") { existing_facts == existing.reload.attributes }
    assert_withheld("protected record facts remain unchanged") { existing_owner_facts == visitor.reload.attributes }
    own_candidate_facts = candidates.last.attributes
    foreign_candidate_facts = candidates.first.attributes
    browsers.last.get(targets.first.request_uri)

    assert_equal 409, browsers.last.response.status
    assert_withheld("protected record facts remain unchanged") {
      own_candidate_facts == candidates.last.reload.attributes
    }
    assert_withheld("protected record facts remain unchanged") {
      foreign_candidate_facts == candidates.first.reload.attributes
    }
    foreign_delivery =
      (enqueued_jobs + performed_jobs).find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == candidates.first.public_id
      end
    foreign_notification = ActiveJob::Arguments.deserialize(foreign_delivery.fetch(:args)).last
    foreign_code = OutboundSensitivePayload.decrypt_email_otp(
      foreign_notification.fetch(:params).fetch(:encrypted_hotp_token),
    )
    assert_no_difference("VisitorToken.count") do
      browsers.last.patch(
        targets.first.request_uri,
        params: { visitor_email: { pass_code: foreign_code }, "cf-turnstile-response": "test" },
        headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 409, browsers.last.response.status
    assert_withheld("foreign proof cannot affect this candidate") {
      own_candidate_facts == candidates.last.reload.attributes
    }
    assert_withheld("foreign proof cannot consume its candidate") {
      foreign_candidate_facts == candidates.first.reload.attributes
    }
    browsers.last.get(targets.last.request_uri)

    assert_equal 200, browsers.last.response.status
  end

  test "an OTP page without a flow locator refuses without allocating a flow or contact" do
    assert_no_difference(["VisitorSignUpFlow.count", "VisitorEmail.count", "VisitorToken.count"]) do
      get auth_com_sign_up_check_email_otp_url(ri: "jp"), headers: default_headers
    end

    assert_response :conflict
    assert_nil response.headers["Location"]
  end

  test "edit with expired session renders form error without clearing requirements" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "expired-session@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "HTTPS" => "on" }

    assert_response :redirect
    target = URI.parse(response.location)
    cycle = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))
    email = VisitorEmail.find(cycle.pending_contact_id)
    transaction = VisitorEmailCeremonyTransaction.where(operation: "sign_up", email_candidate_ref: email.public_id).sole
    transaction.update!(otp_expires_at: VisitorEmailCeremonyTransaction.database_now - 1.minute)
    completed_requirements = cycle.completed_requirements.deep_dup
    flow_count = VisitorSignUpFlow.count

    get target.request_uri

    assert_response :unprocessable_content
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_includes props.fetch("errors").join(" "),
                    I18n.t("sign.app.registration.email.edit.session_expired")
    assert_equal completed_requirements, cycle.reload.completed_requirements
    assert_equal flow_count, VisitorSignUpFlow.count
  end

  test "create with invalid email fails" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "invalid-email",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
    assert_equal "invalid-email", inertia_props.fetch("field").fetch("value")
    assert_not_includes inertia_props.fetch("errors").join(" "), "Visitorを入力してください"
  end

  test "create with unconfirmed policy fails" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "com-flow-step-2@example.com",
             confirm_policy: "0",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
    assert_equal "com-flow-step-2@example.com", inertia_props.fetch("field").fetch("value")
  end

  test "create with turnstile failure returns unprocessable content" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: { raw_address: "turnstile@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
    assert_equal "turnstile@example.com", inertia_props.fetch("field").fetch("value")
  end

  test "create keeps re-registration inside overwrite window non-disclosing" do
    email_address = "cooldown-up@example.com"
    headers = { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "HTTPS" => "on" }

    post auth_com_sign_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: headers

    assert_response :redirect
    first_target = URI.parse(response.location)
    first_flow = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))

    first_candidate = VisitorEmail.find(first_flow.pending_contact_id)
    original_candidate_facts = first_candidate.reload.attributes.slice(
      "visitor_id", "address_digest",
      "binding_finalized_at", "binding_released_at",
    )
    original_owner = first_candidate.visitor.reload
    # A new entry starts its own flow; the previous screen must never act on that replacement.
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: headers

    assert_response :redirect
    second_target = URI.parse(response.location)
    second_flow = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))

    assert_equal [ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "/sign/up/check/email/otp"],
                 [second_target.host, second_target.path]
    assert_equal %w(fb ri), Rack::Utils.parse_query(second_target.query).keys.sort
    assert_not_equal first_flow.public_id, second_flow.public_id
    assert_predicate first_flow.reload, :sign_up_halted?
    assert_not_predicate second_flow, :sign_up_terminal?
    second_candidate = VisitorEmail.find(second_flow.pending_contact_id)

    assert_not_equal first_candidate.id, second_candidate.id
    assert_not_equal first_candidate.visitor_id, second_candidate.visitor_id
    assert_equal first_candidate.address_digest, second_candidate.address_digest
    assert_withheld("owned supersession preserves binding facts") {
      original_candidate_facts == first_candidate.reload.attributes.slice(
        "visitor_id", "address_digest",
        "binding_finalized_at", "binding_released_at",
      )
    }
    assert_predicate first_flow, :cleanup_completed?
    assert_operator first_candidate.discard_at, :<=, first_flow.cleanup_completed_at
    assert_operator original_owner.reload.discard_at, :<=, first_flow.cleanup_completed_at
    assert_operator original_owner.purge_eligible_at, :>, original_owner.discard_at
    replacement_facts = second_flow.attributes
    get first_target.request_uri

    assert_response :conflict
    assert_withheld("protected record facts remain unchanged") { replacement_facts == second_flow.reload.attributes }
  end

  test "a new email registration after the old window preserves the original candidate and owner" do
    destination = "overwrite-window-com@example.com"
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: destination, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "HTTPS" => "on" }

    assert_response :redirect
    first_flow = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))
    first_candidate = VisitorEmail.find(first_flow.pending_contact_id)
    first_facts = first_candidate.reload.attributes.slice(
      "visitor_id", "address_digest", "binding_finalized_at",
      "binding_released_at",
    )
    first_owner = first_candidate.visitor.reload

    travel EmailOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      assert_difference("VisitorEmail.count", 1) do
        assert_difference("Visitor.count", 1) do
          post auth_com_sign_up_email_url(ri: "jp"),
               params: { visitor_email: { raw_address: destination, confirm_policy: "1" },
                         "cf-turnstile-response": "test", },
               headers: { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "HTTPS" => "on" }
        end
      end
    end

    assert_response :redirect
    current = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))
    replacement = VisitorEmail.find(current.pending_contact_id)

    assert_not_equal first_candidate.id, replacement.id
    assert_not_equal first_candidate.visitor_id, replacement.visitor_id
    assert_equal first_candidate.address_digest, replacement.address_digest
    assert_withheld("owned supersession preserves binding facts") {
      first_facts == first_candidate.reload.attributes.slice(
        "visitor_id", "address_digest", "binding_finalized_at",
        "binding_released_at",
      )
    }
    assert_predicate first_flow.reload, :sign_up_halted?
    assert_predicate first_flow, :cleanup_completed?
    assert_operator first_candidate.discard_at, :<=, first_flow.cleanup_completed_at
    assert_operator first_owner.reload.discard_at, :<=, first_flow.cleanup_completed_at
    assert_operator first_owner.purge_eligible_at, :>, first_owner.discard_at
    assert_nil replacement.binding_finalized_at
  end

  test "create rejects signup for an email blocked by an in-force registration_blocked Identifier Effect, " \
       "sending no OTP" do
    operator = operators(:one)
    the_case = ComEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: "some_prior_visitor_public_id",
      applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "com", value: "com_enforcement_blocked@example.com")
    the_case.identifier_effects.build(**digest, registration_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_enqueued_jobs 0, only: OtpNotifierEmailDeliveryJob do
      post auth_com_sign_up_email_url(ri: "jp"),
           params: {
             visitor_email: {
               raw_address: "Com_Enforcement_Blocked@Example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("errors").join(" "),
                    I18n.t("sign.com.registration.email.create.address_required")
  end

  def default_headers
    { "Host" => host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end
  test "the otp page for an existing verified email is indistinguishable from a new registration" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    existing_email = VisitorEmail.create!(
      visitor: visitor,
      address: "com-existing-otp-page@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      binding_finalized_at: VisitorEmail.database_now,
    )
    original_binding = [existing_email.visitor_id,
                        existing_email.binding_finalized_at, existing_email.binding_released_at,]
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: { raw_address: existing_email.address, confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "HTTPS" => "on" }

    assert_response :redirect

    target = URI.parse(response.location)

    assert_equal "/sign/up/check/email/otp", target.path
    assert_predicate Rack::Utils.parse_query(target.query).fetch("fb"), :present?
    get target.request_uri

    assert_response :success
    assert_not_includes response.body, I18n.t("errors.messages.taken")
    assert_equal original_binding,
                 [existing_email.reload.visitor_id,
                  existing_email.binding_finalized_at, existing_email.binding_released_at,]
  end

  test "a code submitted against an existing verified email never verifies it" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    existing_email = VisitorEmail.create!(
      visitor: visitor,
      address: "com-existing-otp-submit@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      binding_finalized_at: VisitorEmail.database_now,
    )
    original_binding = [existing_email.visitor_id,
                        existing_email.binding_finalized_at, existing_email.binding_released_at,]
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: { raw_address: existing_email.address, confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: { "Host" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "HTTPS" => "on" }

    assert_response :redirect
    target = URI.parse(response.location)

    assert_equal "/sign/up/check/email/otp", target.path
    assert_predicate Rack::Utils.parse_query(target.query).fetch("fb"), :present?
    get target.request_uri

    assert_response :success

    assert_no_difference("Visitor.count") do
      patch target.request_uri,
            params: { visitor_email: { pass_code: "123456" }, "cf-turnstile-response": "test" }
    end

    assert_response :unprocessable_content
    assert_equal VisitorEmailStatus::VERIFIED, existing_email.reload.visitor_email_status_id
    assert_equal original_binding,
                 [existing_email.visitor_id, existing_email.binding_finalized_at, existing_email.binding_released_at]
  end

  private
end

# DAMP auth header helpers for this test class.
class Auth::Com::Sign::Up::EmailsControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::Com::Sign::Up::EmailsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_private_key: SecureRandom.base64(24),
          otp_counter: "",
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers = as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local helper copy on the test class.
class Auth::Com::Sign::Up::EmailsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
