# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseStepUpIntentAuthorityTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_statuses, :client_token_kinds, :client_token_statuses,
           :operator_tokens, :operator_passkeys

  setup do
    https!
  end

  test "app Base verification GET displays a nonconsuming start and POST issues opaque admission" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-intent-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key", otp_counter: "0",
    )
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app", session_nonce: session_nonce_for(token),
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get base_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", host: host),
          headers: app_session_headers(host, token, user)
    end
    assert_response :success, response.body
    assert_equal "base/app/verifications/show", inertia_component
    form = inertia_props.fetch("form")

    assert_equal "settings_email", form.fetch("scope")
    assert_equal pt, form.fetch("pt")
    assert_equal base_app_verification_path(ri: "jp"), form.fetch("action")

    assert_difference -> { ClientStepUpCeremonyTransaction.count }, 1 do
      post base_app_verification_url(ri: "jp", host: host),
           params: { scope: form.fetch("scope"), pt: form.fetch("pt") },
           headers: app_session_headers(host, token, user)
    end
    assert_response :see_other
    query = redirect_query

    assert_predicate query["entry_ref"], :present?
    assert_nil query["step_up_ceremony_grant"]
    assert_nil query["scope"]
    assert_nil query["pt"]
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: query.fetch("entry_ref"))
    _auth_session, raw_sid = prepare_admission_binding_for_consumption!(
      binding, base_token: token, base_browser_nonce: session.fetch("auth_admission_browser_nonce"),
    )
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: query.fetch("entry_ref"), surface: "app", expected_intent: "step_up",
      binding:, raw_auth_sid: raw_sid,
    )
    transaction = ClientStepUpCeremonyTransaction.find_by!(transaction_id: payload.fetch("subject_ref"))

    assert_equal transaction.transaction_id,
                 base_step_up_marker_payload(transaction.transaction_id).fetch("transaction_ref")
    assert_equal user.public_id, transaction.actor_ref
    assert_equal token.public_id, transaction.session_ref
    assert_equal "settings_email", transaction.required_scope
    assert_equal StepUpRequirement::NO_AAL, transaction.required_aal
    assert_nil token.reload.last_step_up_at
  end

  test "app base completion consumes the opaque result and commits freshness for the admitted session" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-completion-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, otp_private_key: "otp_private_key", otp_counter: "0",
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: app_session_headers(host, token, user)

    assert_response :see_other
    transaction = latest_step_up_transaction(ClientStepUpCeremonyTransaction, actor: user, token:)
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: client_totp_credential_ref(user),
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: app_session_headers(host, token, user)

    assert_response :see_other
    assert_equal return_to, URI.parse(response.location).request_uri
    assert_equal "consumed", transaction.reload.status
    token.reload

    assert_equal transaction.verified_at, token.last_step_up_at
    assert_equal "settings_email", token.last_step_up_scope
    assert_equal "totp", token.last_step_up_method
    assert_equal "aal1", token.last_step_up_aal
    assert_predicate ceremony.reload, :completed?
  end

  test "app base completion route is post only" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

    recognized_get = Rails.application.routes.recognize_path("https://#{host}/verification/completion", method: :get)

    assert_equal "base/app/verification/completions", recognized_get[:controller]
    assert_equal "show", recognized_get[:action]

    recognized = Rails.application.routes.recognize_path("https://#{host}/verification/completion", method: :post)

    assert_equal "base/app/verification/completions", recognized[:controller]
    assert_equal "create", recognized[:action]
  end

  test "app base completion rejects missing csrf token when forgery protection is enabled" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    issuance = issue_step_up_grant!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: base_app_identity_emails_path(ri: "jp"),
    )
    transaction = issuance.transaction
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: "test-passkey",
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(transaction:, ceremony_session_ref: ceremony.id.to_s)

    with_forgery_protection do
      # Sec-Fetch-Site decides first: a same-origin request needs no token, so the
      # missing token only rejects a request another site made.
      post base_app_verification_completion_url(ri: "jp", host: host),
           params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
           headers: app_session_headers(host, token, user).merge("Sec-Fetch-Site" => "cross-site")
    end

    assert_response :unprocessable_content
    assert_nil token.reload.last_step_up_at
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "app base completion refuses an invalid stored return target before consuming the result" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-unsafe-return-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, otp_private_key: "otp_private_key", otp_counter: "0",
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: app_session_headers(host, token, user)

    assert_response :see_other
    transaction = latest_step_up_transaction(ClientStepUpCeremonyTransaction, actor: user, token:)
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: client_totp_credential_ref(user),
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )
    # Written past the model on purpose: the issuer never stores such a target. Partitions: another
    # host, a protocol-relative host, a path outside the scope, an empty value and a path carrying a
    # control character. A NUL is not reachable: the column cannot store one.
    [
      "https://evil.example/steal", "//evil.example/steal", "/dashboard", "", "/identity/emails\n/x",
    ].each do |stored_target|
      transaction.update_columns(return_to: stored_target)

      post base_app_verification_completion_url(ri: "jp", host: host),
           params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
           headers: app_session_headers(host, token, user)

      assert_response :bad_request, stored_target.inspect
      assert_nil response.headers["Location"], stored_target.inspect
      assert_equal "verified", transaction.reload.status, stored_target.inspect
      assert_nil transaction.consumed_at, stored_target.inspect
      assert_nil token.reload.last_step_up_at, stored_target.inspect
      assert_not ceremony.reload.completed?, stored_target.inspect
    end

    # The result was never consumed, so the original target still completes the ceremony.
    transaction.update_columns(return_to: return_to)
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: app_session_headers(host, token, user)

    assert_response :see_other
    assert_equal return_to, URI.parse(response.location).request_uri
    assert_equal "consumed", transaction.reload.status
  end

  test "sign completion transport posts result body only to fixed base endpoint" do
    source = Rails.root.join("app/views/auth/shared/oidc_authorization_handoff.html.erb").read

    assert_includes source, 'id="oidc-authorization-handoff-form"'
    assert_includes source, 'method="post"'
    assert_includes source, "hidden_field_tag :authenticity_token, form_authenticity_token"
    assert_not_includes source, "return_to"
    assert_not_includes source, "result"
  end

  test "base completion controllers do not skip forgery protection" do
    [
      "app/controllers/base/app/verifications_controller.rb",
      "app/controllers/base/com/verifications_controller.rb",
      "app/controllers/base/org/verifications_controller.rb",
      "app/controllers/concerns/base_step_up_completion.rb",
    ].each do |path|
      assert_not_includes Rails.root.join(path).read, "skip_forgery_protection"
    end
  end

  test "app base completion retried with the same result keeps the original freshness event" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-retry-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, otp_private_key: "otp_private_key", otp_counter: "0",
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: app_session_headers(host, token, user)

    assert_response :see_other
    transaction = latest_step_up_transaction(ClientStepUpCeremonyTransaction, actor: user, token:)
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: client_totp_credential_ref(user),
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    2.times do
      post base_app_verification_completion_url(ri: "jp", host: host),
           params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
           headers: app_session_headers(host, token, user)

      assert_response :see_other
      assert_equal return_to, URI.parse(response.location).request_uri
      assert_equal transaction.reload.verified_at, token.reload.last_step_up_at
      assert_equal "consumed", transaction.status
    end
  end

  test "app base verification returns to the protected page without a new ceremony while freshness is valid" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-fresh-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, otp_private_key: "otp_private_key", otp_counter: "0",
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: app_session_headers(host, token, user)
    transaction = latest_step_up_transaction(ClientStepUpCeremonyTransaction, actor: user, token:)
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: client_totp_credential_ref(user),
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: app_session_headers(host, token, user)

    assert_response :see_other

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get base_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", host: host),
          headers: app_session_headers(host, token, user)

      assert_response :see_other
      assert_equal return_to, URI.parse(response.location).request_uri

      post base_app_verification_url(ri: "jp", host: host),
           params: { scope: "settings_email", pt: pt }, headers: app_session_headers(host, token, user)

      assert_response :see_other
      assert_equal return_to, URI.parse(response.location).request_uri
    end
  end

  test "app base completion refuses a result that was not issued for the transaction" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-foreign-result-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, otp_private_key: "otp_private_key", otp_counter: "0",
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: app_session_headers(host, token, user)

    assert_response :see_other
    transaction = latest_step_up_transaction(ClientStepUpCeremonyTransaction, actor: user, token:)
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: client_totp_credential_ref(user),
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: "#{result.reference}x" },
         headers: app_session_headers(host, token, user)

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil token.reload.last_step_up_at
    assert_equal "verified", transaction.reload.status
  end

  test "app base cancellation closes the pending transaction and blocks a later completion" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-cancel-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, otp_private_key: "otp_private_key", otp_counter: "0",
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: app_session_headers(host, token, user)

    assert_response :see_other
    transaction = latest_step_up_transaction(ClientStepUpCeremonyTransaction, actor: user, token:)
    cancellation = issue_cancellation_handoff!(transaction)

    post base_app_verification_cancellation_url(ri: "jp", host: host),
         headers: app_session_headers(host, token, user),
         params: cancellation.merge(scope: "settings_email", return_to: return_to)

    assert_response :see_other
    assert_equal base_app_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_predicate transaction.reload, :canceled?
    assert_not_nil transaction.canceled_at
    assert_predicate session[:base_step_up_marker_locator], :present?
    assert_nil token.reload.last_step_up_at

    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: "opaque-result" },
         headers: app_session_headers(host, token, user)

    assert_response :bad_request
    assert_nil token.reload.last_step_up_at
    assert_predicate transaction.reload, :canceled?
  end

  test "app base cancellation repeated with the same handoff is idempotent" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-cancel-twice-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, otp_private_key: "otp_private_key", otp_counter: "0",
    )
    token = create_client_token!(user)
    return_to = base_app_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: session_nonce_for(token))
    post base_app_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: app_session_headers(host, token, user)

    assert_response :see_other
    transaction = latest_step_up_transaction(ClientStepUpCeremonyTransaction, actor: user, token:)
    cancellation = issue_cancellation_handoff!(transaction)

    post base_app_verification_cancellation_url(ri: "jp", host: host),
         params: cancellation, headers: app_session_headers(host, token, user)

    assert_response :see_other
    canceled_at = transaction.reload.canceled_at

    post base_app_verification_cancellation_url(ri: "jp", host: host),
         params: cancellation, headers: app_session_headers(host, token, user)

    assert_response :see_other
    assert_equal base_app_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal canceled_at, transaction.reload.canceled_at
    assert_predicate transaction, :canceled?
  end

  test "app base cancellation without any started ceremony is refused" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      post base_app_verification_cancellation_url(ri: "jp", host: host),
           headers: app_session_headers(host, token, user)
    end

    assert_response :bad_request
    assert_nil response.headers["Location"]
  end

  # The cancellation destination is Base's own entry point, resolved on the server. The posted
  # return_to (which Auth used to fill with the success continuation) is not an authority, whatever
  # it contains.
  test "app base cancellation ignores every posted return_to" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user, address: "step-up-cancel-dest-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, otp_private_key: "otp_private_key", otp_counter: "0",
    )
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app", session_nonce: session_nonce_for(token),
    )
    [
      base_app_identity_emails_path(ri: "jp"),
      "https://evil.example/steal",
      "//evil.example/steal",
      "/%2F%2Fevil.example",
      "/identity\x00/emails",
      "/\\evil.example",
      "",
    ].each do |return_to|
      post base_app_verification_url(ri: "jp", host: host),
           params: { scope: "settings_email", pt: pt }, headers: app_session_headers(host, token, user)

      assert_response :see_other
      transaction = latest_step_up_transaction(ClientStepUpCeremonyTransaction, actor: user, token:)
      cancellation = issue_cancellation_handoff!(transaction)

      post base_app_verification_cancellation_url(ri: "jp", host: host),
           headers: app_session_headers(host, token, user).merge("Referer" => "https://#{host}/identity/emails"),
           params: cancellation.merge(scope: "settings_email", return_to: return_to)

      assert_response :see_other
      assert_equal base_app_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri, return_to
      assert_equal host, URI.parse(response.location).host
    end
  end

  test "app base completion rejects wrong session result" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    other_token = create_client_token!(user)
    issuance = issue_step_up_grant!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: other_token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: base_app_identity_emails_path(ri: "jp"),
    )
    transaction = issuance.transaction
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: "test-passkey",
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(transaction:, ceremony_session_ref: ceremony.id.to_s)

    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: app_session_headers(host, token, user)

    assert_response :bad_request
    assert_nil token.reload.last_step_up_at
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "app base completion rejects a result whose payload is not a JSON object" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: "missing", result_ref: "[1]" },
         headers: app_session_headers(host, token, user)

    assert_response :bad_request
    assert_nil token.reload.last_step_up_at
  end

  test "app base completion rejects an unsigned result before consuming its transaction" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    issuance = issue_step_up_grant!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: base_app_identity_emails_path(ri: "jp"),
    )
    post base_app_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: issuance.transaction.transaction_id, result_ref: "forged-result" },
         headers: app_session_headers(host, token, user)

    assert_response :bad_request
    assert_nil token.reload.last_step_up_at
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "app base verification intent rejects arbitrary scope" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app",
                                               session_nonce: session_nonce_for(token),
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get base_app_verification_url(scope: "admin", pt: pt, ri: "jp", host: host),
          headers: app_session_headers(host, token, user)
    end

    assert_response :bad_request
  end

  test "app base verification intent rejects mismatched return target" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(
      base_app_identity_emails_path(ri: "jp"), surface: "app",
                                               session_nonce: session_nonce_for(token),
    )

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get base_app_verification_url(scope: "settings_telephone", pt: pt, ri: "jp", host: host),
          headers: app_session_headers(host, token, user)
    end

    assert_response :bad_request
  end

  test "com base cancellation ignores a posted return_to" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    visitor = create_verified_visitor_with_email(
      email_address: "visitor-cancel-dest-#{SecureRandom.hex(4)}@example.com",
    )
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    return_to = base_com_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "com", session_nonce: session_nonce_for(token))
    post base_com_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: com_session_headers(host, token, visitor)

    assert_response :see_other
    transaction = latest_step_up_transaction(VisitorStepUpCeremonyTransaction, actor: visitor, token:)
    cancellation = issue_cancellation_handoff!(transaction)

    post base_com_verification_cancellation_url(ri: "jp", host: host),
         headers: com_session_headers(host, token, visitor),
         params: cancellation.merge(scope: "settings_email", return_to: "https://evil.example/steal")

    assert_response :see_other
    assert_equal base_com_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal host, URI.parse(response.location).host
    assert_predicate transaction.reload, :canceled?
  end

  test "com base cancellation closes the pending transaction without granting freshness" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "visitor-cancel-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    return_to = base_com_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "com", session_nonce: session_nonce_for(token))
    post base_com_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: com_session_headers(host, token, visitor)

    assert_response :see_other
    transaction = latest_step_up_transaction(VisitorStepUpCeremonyTransaction, actor: visitor, token:)
    cancellation = issue_cancellation_handoff!(transaction)

    post base_com_verification_cancellation_url(ri: "jp", host: host),
         headers: com_session_headers(host, token, visitor), params: cancellation

    assert_response :see_other
    assert_predicate transaction.reload, :canceled?
    assert_predicate session[:base_step_up_marker_locator], :present?
    assert_nil token.reload.last_step_up_at
  end

  test "org base cancellation ignores a posted return_to" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    operator = operators(:one)
    token = operator_tokens(:one)
    return_to = base_org_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "org", session_nonce: session_nonce_for(token))
    post base_org_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: org_session_headers(host, token, operator)

    assert_response :see_other
    transaction = latest_step_up_transaction(OperatorStepUpCeremonyTransaction, actor: operator, token:)
    cancellation = issue_cancellation_handoff!(transaction)

    post base_org_verification_cancellation_url(ri: "jp", host: host),
         headers: org_session_headers(host, token, operator),
         params: cancellation.merge(scope: "settings_email", return_to: "https://evil.example/steal")

    assert_response :see_other
    assert_equal base_org_dashboard_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal host, URI.parse(response.location).host
    assert_predicate transaction.reload, :canceled?
  end

  test "org base cancellation closes the pending transaction without granting freshness" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    operator = operators(:one)
    token = operator_tokens(:one)
    return_to = base_org_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "org", session_nonce: session_nonce_for(token))
    post base_org_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: org_session_headers(host, token, operator)

    assert_response :see_other
    transaction = latest_step_up_transaction(OperatorStepUpCeremonyTransaction, actor: operator, token:)
    cancellation = issue_cancellation_handoff!(transaction)

    post base_org_verification_cancellation_url(ri: "jp", host: host),
         headers: org_session_headers(host, token, operator), params: cancellation

    assert_response :see_other
    assert_predicate transaction.reload, :canceled?
    assert_predicate session[:base_step_up_marker_locator], :present?
    assert_nil token.reload.last_step_up_at
  end

  test "com base verification intent creates a visitor transaction bound to the session" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "visitor-intent-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    return_to = base_com_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "com", session_nonce: session_nonce_for(token))
    post base_com_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: com_session_headers(host, token, visitor)

    assert_response :see_other
    transaction = latest_step_up_transaction(VisitorStepUpCeremonyTransaction, actor: visitor, token:)

    assert_equal visitor.public_id, transaction.actor_ref
    assert_equal token.public_id, transaction.session_ref
    assert_equal "com", transaction.surface
    assert_equal "step_up", transaction.purpose
    assert_equal return_to, transaction.return_to
    assert_predicate redirect_query["entry_ref"], :present?
    assert_nil redirect_query["step_up_ceremony_grant"]
  end

  test "com base completion consumes the opaque result and commits freshness" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "visitor-completion-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    return_to = base_com_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "com", session_nonce: session_nonce_for(token))
    post base_com_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: com_session_headers(host, token, visitor)

    assert_response :see_other
    transaction = latest_step_up_transaction(VisitorStepUpCeremonyTransaction, actor: visitor, token:)
    email = visitor.visitor_emails.first
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "email_otp", aal: "none", phishing_resistant: false, user_verified: false,
      verified_at: VisitorStepUpCeremonyTransaction.database_now, verified_credential_ref: email.public_id,
    )
    ceremony, = VisitorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    post base_com_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: com_session_headers(host, token, visitor)

    assert_response :see_other
    assert_equal return_to, URI.parse(response.location).request_uri
    assert_equal "settings_email", token.reload.last_step_up_scope
    assert_equal "consumed", transaction.reload.status
  end

  test "org base verification intent creates an operator transaction bound to the session" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    operator = operators(:one)
    token = operator_tokens(:one)
    return_to = base_org_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "org", session_nonce: session_nonce_for(token))
    post base_org_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: org_session_headers(host, token, operator)

    assert_response :see_other
    transaction = latest_step_up_transaction(OperatorStepUpCeremonyTransaction, actor: operator, token:)

    assert_equal operator.public_id, transaction.actor_ref
    assert_equal token.public_id, transaction.session_ref
    assert_equal "org", transaction.surface
    assert_equal "step_up", transaction.purpose
    assert_equal ["passkey"], transaction.allowed_methods_array
    assert_predicate redirect_query["entry_ref"], :present?
    assert_nil redirect_query["step_up_ceremony_grant"]
  end

  test "org base completion consumes the opaque result and commits freshness" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    operator = operators(:one)
    token = operator_tokens(:one)
    return_to = base_org_identity_emails_path(ri: "jp")
    pt = signed_step_up_pt_for(return_to, surface: "org", session_nonce: session_nonce_for(token))
    post base_org_verification_url(ri: "jp", host: host),
         params: { scope: "settings_email", pt: pt }, headers: org_session_headers(host, token, operator)

    assert_response :see_other
    transaction = latest_step_up_transaction(OperatorStepUpCeremonyTransaction, actor: operator, token:)
    passkey = operator.staff_passkeys.first
    # Synthetic evidence: the Auth verification itself is covered by the ceremony committer tests.
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: OperatorStepUpCeremonyTransaction.database_now, verified_credential_ref: passkey.external_id,
    )
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction,
      ceremony_session_ref: ceremony.id.to_s,
    )

    post base_org_verification_completion_url(ri: "jp", host: host),
         params: { transaction_ref: transaction.transaction_id, result_ref: result.reference },
         headers: org_session_headers(host, token, operator)

    assert_response :see_other
    assert_equal return_to, URI.parse(response.location).request_uri
    assert_equal "settings_email", token.reload.last_step_up_scope
    assert_equal "consumed", transaction.reload.status
  end

  private

  def latest_step_up_transaction(model, actor:, token:)
    model.where(actor_ref: actor.public_id, session_ref: token.public_id).order(id: :desc).first!
  end

  def base_step_up_marker_payload(transaction_ref)
    Valkey::AuthState::BaseStepUpMarkerStore.new.read(
      locator: session.fetch(:base_step_up_marker_locator), transaction_ref: transaction_ref,
    )
  end

  def issue_cancellation_handoff!(transaction)
    issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction: transaction)
    {
      cancellation_handoff: issuance.handoff,
      cancellation_ref: issuance.reference,
      transaction_ref: transaction.transaction_id,
    }
  end

  def client_totp_credential_ref(user)
    user.client_totp_credentials.find_by!(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    ).public_id
  end

  def create_client_token!(user)
    ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
  end

  def app_session_headers(host, token, user)
    install_base_browser_rp_credentials!(surface: "app", host:, actor: user, token:)
    bearer_headers(
      jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client"),
      host: host,
    )
  end

  def com_session_headers(host, token, visitor)
    install_base_browser_rp_credentials!(surface: "com", host:, actor: visitor, token:)
    bearer_headers(
      jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor"),
      host: host,
    )
  end

  def org_session_headers(host, token, operator)
    install_base_browser_rp_credentials!(surface: "org", host:, actor: operator, token:)
    bearer_headers(
      jwt_access_token_for(operator, host: host, session_public_id: token.public_id, resource_type: "operator"),
      host: host,
    )
  end

  def install_base_browser_rp_credentials!(surface:, host:, actor:, token:)
    @base_browser_rp_credentials ||= {}
    key = [surface, token.public_id]
    client_id = { "app" => "base-app-ww", "com" => "base-com-ww", "org" => "base-org-ww" }.fetch(surface)
    client = OidcClientRegistry.find!(client_id)
    resource_type = { "app" => "client", "com" => "visitor", "org" => "operator" }.fetch(surface)
    model = { "app" => ClientRpSession, "com" => VisitorRpSession, "org" => OperatorRpSession }.fetch(surface)
    token_key = { "app" => :client_token, "com" => :visitor_token, "org" => :operator_token }.fetch(surface)
    unless @base_browser_rp_credentials[key]
      token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
      now = Time.current
      rp_session = model.create!(
        token_key => token,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile",
        :oidc_jti => SecureRandom.uuid,
        :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => now,
        :refresh_token_expires_at => now + 10.minutes,
      )
      access_token = AuthenticationTokenService.encode(
        actor,
        host: host,
        resource_type: resource_type,
        session_public_id: token.public_id,
        base_session_public_id: token.public_id,
        oidc_sid: rp_session.public_id,
        oidc_jti: rp_session.oidc_jti,
        expires_at: now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(client),
        audiences: [client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
        subject: OidcSubject.for(actor, resource_type: resource_type),
        client_id: client.client_id,
      )
      @base_browser_rp_credentials[key] = [access_token, rp_session.issue_refresh_token!]
    end
    access_token, refresh_token = @base_browser_rp_credentials.fetch(key)
    transaction_model = {
      "app" => ClientStepUpCeremonyTransaction,
      "com" => VisitorStepUpCeremonyTransaction,
      "org" => OperatorStepUpCeremonyTransaction,
    }.fetch(surface)
    verified_transaction = transaction_model.where(
      session_ref: token.public_id,
      status: "verified",
    ).order(id: :desc).first
    if verified_transaction
      rp_session = model.where(token_key => token).order(id: :desc).first!
      amr = { "passkey" => ["passkey"], "totp" => ["otp"], "email_otp" => ["email_otp"] }.fetch(
        verified_transaction.method,
      )
      rp_session.update_columns(
        oidc_auth_time: verified_transaction.verified_at,
        oidc_acr: verified_transaction.aal,
        oidc_amr: JSON.generate(amr),
        updated_at: Time.current,
      )
    end
    cookies.merge( # rubocop:disable Lint/Void
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access_token)}",
      URI.parse("https://#{host}/"),
    )
    cookies.merge( # rubocop:disable Lint/Void
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh_token)}",
      URI.parse("https://#{host}/"),
    )
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

  def redirect_query
    uri = URI.parse(response.location)
    if uri.host == "jump.umaxica.net"
      payload, = JWT.decode(Rack::Utils.parse_nested_query(uri.query).fetch("rt"), nil, false)
      uri = URI.parse(payload.fetch("url"))
    end
    Rack::Utils.parse_query(uri.query)
  end

  def decode_grant(token, surface:)
    IdentityStepUpCeremonyGrant.decode(
      token,
      issuer_id: IdentityStepUpCeremonyContract.base_issuer_id(surface),
    )
  end

  def issue_step_up_grant!(surface:, actor_ref:, session_ref:, scope:, methods:, return_to:)
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      required_scope: scope,
      required_aal: StepUpRequirement::NO_AAL,
      audience: "step_up:#{surface}",
      token_binding: session_ref,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 10.minutes.from_now,
    )
  end
end

# DAMP local helper copy for former shared test support.
class BaseStepUpIntentAuthorityTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  # The Base surface shares its production origin with Acme (both resolve to
  # `https://www.umaxica.<tld>`), so the issuer namespace cannot be inferred
  # from a host substring like "base". Match against the actual configured
  # Base hosts first; only fall back to substring heuristics for surfaces
  # whose test/production hosts are texually distinct (acme/core/sign).
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      "ORG" => ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      "COM" => ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
    }
    return "surface:BASE_#{base_hosts.key(normalized)}" if base_hosts.value?(normalized)

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

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
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
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
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
          address_digest: IdentifierBlindIndex.bidx_for_email(address),
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

  # Base's Browser-RP context binds the signed `pt` to the current root token
  # public_id, which is also the durable step-up transaction session_ref.
  def session_nonce_for(token)
    token.public_id
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
                               aal: StepUpRequirement::NO_AAL)
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

  def csrf_token_value
    "test-csrf-token"
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

# DAMP local route helper aliases for former shared test support.
class BaseStepUpIntentAuthorityTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end

# DAMP local helper copy on the test class.
class BaseStepUpIntentAuthorityTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

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

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discard_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discard_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
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

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    email = VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    email.finalize_binding!
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
