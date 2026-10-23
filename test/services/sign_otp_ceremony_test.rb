# typed: false
# frozen_string_literal: true

require "test_helper"

# Boolean snapshots prevent failure output from disclosing code, proof and browser facts.
class SignOtpCeremonyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_class, contact_class, owner_key, flow_class, surface, channel|
    test "#{surface} #{channel} signup failure budget survives another candidate flow and browser" do
      destination =
        (channel == :email) ? "budget-#{SecureRandom.hex(8)}@example.test" :
          "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
      issuer, verifier =
        case channel
        when :email then [EmailSignUpOtpIssuer, EmailSignUpOtpVerificationCommitter]
        when :telephone then [TelephoneSignUpOtpIssuer, TelephoneSignUpOtpVerificationCommitter]
        end
      candidates =
        2.times.map do |index|
          owner = owner_class.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
          )
          contact = contact_class.create!(
            owner_key => owner.id, :confirm_policy => "1",
            ((channel == :email) ? :address : :number) => destination,
          )
          now = flow_class.database_now
          flow = flow_class.create!(
            auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_class),
            principal_id: owner.id, status_id: flow_class::STATUS_MODEL::STARTED, step: "start",
            nonce_digest: flow_class.digest_nonce("budget-browser-#{index}"), issued_at: now,
            expires_at: now + 15.minutes, entry_method: channel.to_s,
            pending_contact_type: channel.to_s, pending_contact_id: contact.id,
          )
          source = (channel == :email) ? { email: contact } : { telephone: contact }
          issued = issuer.call(flow:, session_nonce: "budget-browser-#{index}", **source)

          assert_predicate issued, :success?
          [flow, contact, issued, source]
        end
      first_flow, first_contact, first_issue, first_source = candidates.first
      wrong_code = (first_issue.code == "000000") ? "000001" : "000000"
      original_contact = first_contact.reload.attributes
      original_flow = first_flow.reload.attributes
      original_ticket = first_issue.transaction.reload.attributes
      Umaxica::Valkey::Connection.stub(:new, ->(**) { raise Umaxica::Valkey::Unavailable, "dependency unavailable" }) do
        [first_issue.code, wrong_code].each do |submitted|
          assert_raises(Umaxica::Valkey::Unavailable) do
            verifier.call(flow: first_flow, code: submitted, session_nonce: "budget-browser-0", **first_source)
          end

          assert_withheld { original_contact == first_contact.reload.attributes }
          assert_withheld { original_flow == first_flow.reload.attributes }
          assert_withheld { original_ticket == first_issue.transaction.reload.attributes }
        end
      end
      5.times do |index|
        result = verifier.call(
          flow: first_flow, code: wrong_code, session_nonce: "budget-browser-0", **first_source,
        )

        assert_not_predicate result, :success?
        assert_equal((index == 4) ? :locked : :invalid_code, result.status)
      end

      assert_predicate first_contact.reload, :locked?
      replacement_flow, replacement_contact, replacement_issue, replacement_source = candidates.last
      retained_ticket = replacement_issue.transaction.reload.attributes
      retained_source = replacement_contact.reload.attributes
      result = verifier.call(
        flow: replacement_flow, code: replacement_issue.code, session_nonce: "budget-browser-1", **replacement_source,
      )

      assert_not_predicate result, :success?
      assert_equal :locked, result.status
      assert_withheld { retained_ticket == replacement_issue.transaction.reload.attributes }
      assert_withheld { retained_source == replacement_contact.reload.attributes }
      assert_not_predicate replacement_contact, :binding_effective?
    end
  end

  test "released signup bindings cannot issue or consume retained proof in either channel or realm" do
    [
      [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
      [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
      [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
      [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
    ].each do |owner_class, contact_class, owner_key, flow_class, surface, channel|
      owner = owner_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
      )
      contact = contact_class.create!(
        owner_key => owner.id, :confirm_policy => "1",
        ((channel == :email) ? :address : :number) =>
          ((channel == :email) ? "released-signup@example.test" : "+819012345675"),
      )
      now = flow_class.database_now
      flow = flow_class.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_class),
        principal_id: owner.id, status_id: flow_class::STATUS_MODEL::STARTED, step: "start",
        nonce_digest: flow_class.digest_nonce("sign-otp-browser"), issued_at: now,
        expires_at: now + 15.minutes, entry_method: channel.to_s,
        pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      issuer, verifier, query, source =
        case channel
        when :email
          [EmailSignUpOtpIssuer, EmailSignUpOtpVerificationCommitter, EmailSignUpOtpFormQuery, { email: contact }]
        when :telephone
          [TelephoneSignUpOtpIssuer, TelephoneSignUpOtpVerificationCommitter,
           TelephoneSignUpOtpFormQuery, { telephone: contact },]
        end
      original = issuer.call(flow:, session_nonce: "sign-otp-browser", **source)

      assert_predicate original, :success?
      contact.finalize_binding!
      contact.release_binding!
      retained_ticket = original.transaction.reload.attributes
      retained_source = contact.reload.attributes
      result = verifier.call(flow:, code: original.code, session_nonce: "sign-otp-browser", **source)

      assert_not_predicate result, :success?
      assert_equal :inactive_candidate, result.status
      assert_withheld { retained_ticket == original.transaction.reload.attributes }
      assert_predicate contact.reload, :binding_released?
      issued = issuer.call(flow:, session_nonce: "sign-otp-browser", **source)

      assert_not_predicate issued, :success?
      assert_equal :inactive_candidate, issued.status
      assert_not query.call(flow:, session_nonce: "sign-otp-browser", **source)
      assert_withheld { retained_ticket == original.transaction.reload.attributes }
      assert_withheld { retained_source == contact.reload.attributes }
    end
  end

  test "signup refuses another Identity candidate without consuming its original proof in both channels and realms" do
    [
      [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
      [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
      [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
      [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
    ].each do |owner_class, contact_class, owner_key, flow_class, surface, channel|
      owner = owner_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
      )
      foreign = owner_class.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_class))
      contact = contact_class.create!(
        owner_key => owner.id, :confirm_policy => "1",
        ((channel == :email) ? :address : :number) =>
          ((channel == :email) ? "wrong-owner@example.test" : "+819012345676"),
      )
      now = flow_class.database_now
      flow = flow_class.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_class),
        principal_id: owner.id, status_id: flow_class::STATUS_MODEL::STARTED, step: "start",
        nonce_digest: flow_class.digest_nonce("sign-otp-browser"), issued_at: now,
        expires_at: now + 15.minutes, entry_method: channel.to_s,
        pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      issuer, verifier, query, source =
        case channel
        when :email
          [EmailSignUpOtpIssuer, EmailSignUpOtpVerificationCommitter, EmailSignUpOtpFormQuery, { email: contact }]
        when :telephone
          [TelephoneSignUpOtpIssuer, TelephoneSignUpOtpVerificationCommitter,
           TelephoneSignUpOtpFormQuery, { telephone: contact },]
        end
      original = issuer.call(flow:, session_nonce: "sign-otp-browser", **source)

      assert_predicate original, :success?
      retained_ticket = original.transaction.reload.attributes
      retained_source = contact.reload.attributes
      flow.update!(principal_id: foreign.id)
      issued = issuer.call(flow:, session_nonce: "sign-otp-browser", **source)
      verified = verifier.call(flow:, code: original.code, session_nonce: "sign-otp-browser", **source)

      assert_equal :binding_mismatch, issued.status
      assert_not_predicate issued, :success?
      assert_equal :inactive_candidate, verified.status
      assert_not_predicate verified, :success?
      assert_not query.call(flow:, session_nonce: "sign-otp-browser", **source)
      assert_withheld { retained_ticket == original.transaction.reload.attributes }
      assert_withheld { retained_source == contact.reload.attributes }
      assert_equal 0, contact.otp_attempts_count
      assert_not_predicate flow.reload, :sign_up_terminal?
    end
  end

  test "terminal or expired signup cannot issue or consume proof in either Email realm" do
    [
      [Client, ClientEmail, :user_id, ClientSignUpFlow, ClientStatus::UNVERIFIED_WITH_SIGN_UP],
      [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, VisitorStatus::ACTIVE],
    ].each do |owner_class, email_class, owner_key, flow_class, owner_status|
      %i(cancelled expired).each do |condition|
        owner = owner_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: owner_status)
        email = email_class.create!(
          owner_key => owner.id, :address => "terminal-#{condition}-#{SecureRandom.hex(6)}@example.test",
          :confirm_policy => "1",
        )
        decision_time = flow_class.database_now
        flow = flow_class.create!(
          auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_class),
          principal_id: owner.id, status_id: flow_class::STATUS_MODEL::STARTED, step: "start",
          nonce_digest: flow_class.digest_nonce("sign-otp-browser"),
          issued_at: decision_time - 1.second, expires_at: decision_time + 15.minutes,
          entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
        )
        original = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

        assert_predicate original, :success?
        if condition == :cancelled
          flow.cancel_sign_up!
        else
          flow.update!(expires_at: decision_time - Rational(1, 1_000_000))
        end
        retained_ticket = original.transaction.reload.attributes
        issued = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")
        verified = EmailSignUpOtpVerificationCommitter.call(
          flow:, email:, code: original.code, session_nonce: "sign-otp-browser",
        )

        assert_equal [false, :inactive_flow, false, :inactive_flow],
                     [issued.success?, issued.status, verified.success?, verified.status]
        assert_not EmailSignUpOtpFormQuery.call(flow:, email:, session_nonce: "sign-otp-browser")
        assert_withheld { retained_ticket == original.transaction.reload.attributes }
      end
    end
  end

  test "Email and Telephone independently bound authentication and confirmation lifetimes" do
    assert_equal 10.minutes, EmailOtpPolicy::MAX_OOB_TTL
    assert_equal EmailOtpPolicy::MAX_OOB_TTL, EmailOtpPolicy::AUTHENTICATION_TTL
    assert_equal EmailOtpPolicy::MAX_OOB_TTL, EmailOtpPolicy::SIGN_UP_CONFIRMATION_TTL
    assert_equal 10.minutes, TelephoneOtpPolicy::MAX_OOB_TTL
    assert_equal TelephoneOtpPolicy::MAX_OOB_TTL, TelephoneOtpPolicy::AUTHENTICATION_TTL
    assert_equal TelephoneOtpPolicy::MAX_OOB_TTL, TelephoneOtpPolicy::SIGN_UP_CONFIRMATION_TTL
  end

  test "typed Email form refuses a signup ticket with no bound candidate" do
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP).id,
      status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"),
      issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: nil,
    )
    facts = flow.attributes

    assert_not EmailSignUpOtpFormQuery.call(flow:, email: nil, session_nonce: "sign-otp-browser")
    assert_raises(ArgumentError) do
      EmailSignUpOtpIssuer.call(flow:, email: nil, session_nonce: "sign-otp-browser")
    end
    assert_withheld { facts == flow.reload.attributes }
  end

  test "issued Email proof rejects another candidate destination then consumes once and retains nonfresh evidence" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(address: "sign-otp@example.test", confirm_policy: "1")
    foreign_email = owner.client_emails.create!(address: "other-address@example.test", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    mismatch = EmailSignUpOtpIssuer.call(flow:, email: foreign_email, session_nonce: "sign-otp-browser")

    assert_not_predicate mismatch, :success?
    assert_equal :binding_mismatch, mismatch.status
    issued = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

    assert_predicate issued, :success?
    assert_equal :issued, issued.status
    clear_enqueued_jobs
    Notify::App::OtpNotifier.issue(
      record: email, otp_code: issued.code, purpose: "sign_up", public_id: email.public_id,
      sign_up_flow_ref: flow.public_id, sign_up_email_transaction_ref: issued.transaction.transaction_id,
      sign_up_email_otp_generation: issued.transaction.otp_generation,
    )

    assert_equal 1, enqueued_jobs.length
    args = enqueued_jobs.first.fetch(:args)
    delivery = ActiveJob::Arguments.deserialize(args).last.fetch(:params).symbolize_keys

    assert_withheld { delivery.fetch(:sign_up_email_transaction_ref) == issued.transaction.transaction_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == issued.transaction.otp_generation }
    assert_withheld { OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token)) == issued.code }
    assert_not args.to_s.include?(issued.code)
    verified = EmailSignUpOtpVerificationCommitter.call(
      flow:, email:, code: issued.code, session_nonce: "sign-otp-browser",
    )

    assert_predicate verified, :success?
    assert_equal :verified, verified.status
    assert_nil issued.transaction.reload.otp_verifier
    assert_not_nil issued.transaction.otp_consumed_at
    receipt = issued.transaction.attributes
    source = email.reload.attributes
    retried = EmailSignUpOtpVerificationCommitter.call(
      flow:, email:, code: issued.code, session_nonce: "sign-otp-browser",
    )

    assert_not_predicate retried, :success?
    assert_predicate retried, :verified_evidence?
    assert_equal :already_verified, retried.status
    assert_withheld { receipt == issued.transaction.reload.attributes }
    assert_withheld { source == email.reload.attributes }
    assert EmailSignUpOtpFormQuery.call(flow:, email:, session_nonce: "sign-otp-browser")
  end

  test "Email verification refuses a different destination candidate without consuming the bound proof" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(address: "sign-otp-mismatch@example.test", confirm_policy: "1")
    foreign_email = owner.client_emails.create!(address: "someone-else@example.test", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

    assert_predicate issued, :success?
    proof = issued.transaction.reload.attributes
    source = email.reload.attributes
    foreign_facts = foreign_email.attributes
    result = EmailSignUpOtpVerificationCommitter.call(
      flow:, email: foreign_email, code: issued.code, session_nonce: "sign-otp-browser",
    )

    assert_not_predicate result, :success?
    assert_equal :inactive_candidate, result.status
    assert_not EmailSignUpOtpFormQuery.call(flow:, email: foreign_email, session_nonce: "sign-otp-browser")
    assert_withheld { proof == issued.transaction.reload.attributes }
    assert_withheld { source == email.reload.attributes }
    assert_withheld { foreign_facts == foreign_email.reload.attributes }
  end

  test "Email verification classifies code length neighbors and typed sentinels without admitting failure budgets" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(address: "sign-otp-malformed@example.test", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

    assert_predicate issued, :success?
    proof = issued.transaction.reload.attributes
    source = email.reload.attributes
    [nil, "", "12345", "1234567"].each do |code|
      result = EmailSignUpOtpVerificationCommitter.call(flow:, email:, code:, session_nonce: "sign-otp-browser")

      assert_not_predicate result, :success?
      assert_equal :invalid_code, result.status
      assert_withheld { proof == issued.transaction.reload.attributes }
      assert_withheld { source == email.reload.attributes }
    end
    verified = EmailSignUpOtpVerificationCommitter.call(
      flow:, email:, code: issued.code, session_nonce: "sign-otp-browser",
    )

    assert_equal 6, issued.code.length
    assert_predicate verified, :success?
  end

  test "reissuing signup Email preserves failures until fresh successful consumption" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(address: "sign-otp-attempts@example.test", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    first = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

    assert_predicate first, :success?
    invalid_code = (first.code == "000000") ? "000001" : "000000"
    failed = EmailSignUpOtpVerificationCommitter.call(
      flow:, email:, code: invalid_code, session_nonce: "sign-otp-browser",
    )

    assert_equal :invalid_code, failed.status
    assert_equal 1, email.reload.otp_attempts_count
    original_generation = first.transaction.otp_generation
    email.update!(otp_last_sent_at: EmailOtpPolicy::SEND_COOLDOWN.ago - 1.second)
    reissued = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

    assert_predicate reissued, :success?
    assert_equal first.transaction.id, reissued.transaction.id
    assert_not_equal original_generation, reissued.transaction.otp_generation
    assert_equal 1, email.reload.otp_attempts_count
    verified = EmailSignUpOtpVerificationCommitter.call(
      flow:, email:, code: reissued.code, session_nonce: "sign-otp-browser",
    )

    assert_predicate verified, :success?
    assert_equal 0, email.reload.otp_attempts_count
  end

  test "another signup browser cannot issue query verify or consume the original Email proof" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(address: "sign-otp-session-binding@example.test", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

    assert_predicate issued, :success?
    proof = issued.transaction.reload.attributes
    source = email.reload.attributes
    refused = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "another-flow")
    verified = EmailSignUpOtpVerificationCommitter.call(
      flow:, email:, code: issued.code, session_nonce: "another-flow",
    )

    assert_equal :session_mismatch, refused.status
    assert_equal :session_mismatch, verified.status
    assert_not_predicate verified, :success?
    assert_not EmailSignUpOtpFormQuery.call(flow:, email:, session_nonce: "another-flow")
    assert_withheld { proof == issued.transaction.reload.attributes }
    assert_withheld { source == email.reload.attributes }
  end

  test "Telephone issuance refuses an Email signup ticket without creating another channel proof" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = owner.client_telephones.create!(number: "+819012345674", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: nil,
    )
    source = telephone.attributes
    result = TelephoneSignUpOtpIssuer.call(flow:, telephone:, session_nonce: "sign-otp-browser")

    assert_not_predicate result, :success?
    assert_equal :binding_mismatch, result.status
    assert_not TelephoneSignUpOtpFormQuery.call(flow:, telephone:, session_nonce: "sign-otp-browser")
    assert_withheld { source == telephone.reload.attributes }
    assert_not ClientTelephoneCeremonyTransaction.exists?(telephone_candidate_ref: telephone.public_id)
  end

  test "persisted Email resend cooldown preserves proof and refuses delivery material" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(address: "signup-cooldown@example.test", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    first = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

    assert_predicate first, :success?
    proof = first.transaction.reload.attributes
    source = email.reload.attributes
    clear_enqueued_jobs
    result = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

    assert_not_predicate result, :success?
    assert_equal :rate_limited, result.status
    assert_nil result.transaction
    assert_nil result.code
    assert_withheld { proof == first.transaction.reload.attributes }
    assert_withheld { source == email.reload.attributes }
    assert_empty enqueued_jobs
  end

  test "Email signup random challenge stays within its five-minute lifetime and ten-minute policy ceiling" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(address: "sign-otp-expiry@example.test", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

    assert_predicate issued, :success?
    assert_match(/\A[0-9]{6}\z/, issued.code)
    assert_match(/\A[0-9a-f-]{36}\z/, issued.transaction.otp_generation)
    assert_operator issued.transaction.otp_expires_at, :<=, now + EmailCeremonyOtp::OTP_TTL + 1.second
    assert_operator issued.transaction.otp_expires_at, :<=, now + EmailOtpPolicy::SIGN_UP_CONFIRMATION_TTL
    assert_operator issued.transaction.otp_expires_at, :<=, flow.expires_at
  end

  { immediately_before: -1, at: 0, immediately_after: 1 }.each do |boundary, offset|
    test "Email signup proof #{boundary} its persisted expiry uses the nearest microsecond boundary" do
      owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
      email = owner.client_emails.create!(address: "sign-otp-expiry-#{boundary}@example.test", confirm_policy: "1")
      now = ClientSignUpFlow.database_now
      flow = ClientSignUpFlow.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
        principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
        nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
      )
      issued = EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")

      assert_predicate issued, :success?
      proof = issued.transaction.reload.attributes
      source = email.reload.attributes
      decision_time = issued.transaction.otp_expires_at + Rational(offset, 1_000_000)
      ClientEmailCeremonyTransaction.stub(:database_now, decision_time) do
        query = EmailSignUpOtpFormQuery.call(flow:, email:, session_nonce: "sign-otp-browser")

        if offset < 0
          assert query
        else
          assert_not query
        end
        result = EmailSignUpOtpVerificationCommitter.call(
          flow:, email:, code: issued.code, session_nonce: "sign-otp-browser",
        )

        assert_equal(offset < 0, result.success?)
        assert_equal((offset < 0) ? :verified : :invalid_code, result.status)
      end
      if offset >= 0
        assert_withheld { proof == issued.transaction.reload.attributes }
        assert_withheld { source == email.reload.attributes }
      end
    end
  end

  test "Email issuance uses owning Source and Ticket database clocks for sent timestamp and proof expiry" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = owner.client_emails.create!(address: "sign-otp-database-clock@example.test", confirm_policy: "1")
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::STARTED, step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-otp-browser"), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    source_now = now + 1.second
    ticket_now = now + 2.seconds
    issued =
      ClientEmail.stub(:database_now, source_now) do
        ClientEmailCeremonyTransaction.stub(:database_now, ticket_now) do
          EmailSignUpOtpIssuer.call(flow:, email:, session_nonce: "sign-otp-browser")
        end
      end

    assert_predicate issued, :success?
    assert_equal source_now.to_i, email.reload.otp_last_sent_at.to_i
    assert_equal (ticket_now + EmailCeremonyOtp::OTP_TTL).to_i, issued.transaction.otp_expires_at.to_i
    assert_equal flow.expires_at, issued.transaction.expires_at
  end
end
