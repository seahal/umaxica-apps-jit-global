# frozen_string_literal: true

require "test_helper"

class AuthEmailOtpChallengeTest < ActiveSupport::TestCase
  setup do
    ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
    VisitorSignInFlowState::DEFAULTS.each { |id| VisitorSignInFlowState.find_or_create_by!(id: id) }
  end

  %w(app com).each do |surface|
    test "#{surface} resending one admitted email challenge preserves another flow's code and proof" do
      address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      first, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      second, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      original = contact.reload.attributes
      first_code = first.issue_email_otp!(contact: contact, destination: contact.address)
      second.issue_email_otp!(contact: contact, destination: contact.address)
      second_code = second.issue_email_otp!(contact: contact, destination: contact.address)
      # Equal raw six-digit codes are representable across independent generations.
      # This partition tests distinct codes, not an unsupported global uniqueness promise.
      10.times do
        break if second_code != first_code

        second_code = second.issue_email_otp!(contact: contact, destination: contact.address)
      end

      assert_not_equal first_code, second_code
      first_challenge = first.reload.email_otp_context.deep_dup

      assert_equal original, contact.reload.attributes
      refusal = second.verify_email_otp!(code: first_code)

      assert_not refusal.success?
      assert_equal first_challenge, first.reload.email_otp_context
      result = first.verify_email_otp!(code: first_code)

      assert_predicate result, :success?
      assert_equal contact, result.contact
      assert_nil second.reload.email_otp_context.fetch("verified_at")
      verified_at = first.reload.email_otp_context.fetch("verified_at")
      retry_result = first.verify_email_otp!(code: first_code)

      assert_not retry_result.success?, "a retained verification receipt is not a second OTP consumption"
      assert_equal :already_verified, retry_result.status
      assert_equal verified_at, first.reload.email_otp_context.fetch("verified_at")
      assert_raises(AuthCeremonySession::InvalidTransition) do
        first.issue_email_otp!(contact: contact, destination: contact.address)
      end
      assert_equal verified_at, first.reload.email_otp_context.fetch("verified_at")
    end

    test "#{surface} released binding proof cannot authorize a successor owner" do
      address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      ceremony, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      code = ceremony.issue_email_otp!(contact: contact, destination: contact.address)
      original = ceremony.reload.email_otp_context.deep_dup
      contact.release_binding!
      address = contact.address
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        successor = owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        successor = owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      unchanged = successor.reload.attributes
      result = ceremony.verify_email_otp!(code: code)

      assert_not result.success?
      assert_equal original, ceremony.reload.email_otp_context
      assert_equal unchanged, successor.reload.attributes
    end

    test "#{surface} an unadmitted continuity cannot issue email evidence" do
      address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      ceremony, = model.issue!
      assert_raises(AuthCeremonySession::InvalidTransition) do
        ceremony.issue_email_otp!(contact: contact, destination: contact.address)
      end

      assert_nil ceremony.reload.email_otp_context
    end

    test "#{surface} database refuses malformed OTP context versions" do
      address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      ceremony, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      ceremony.issue_email_otp!(contact: contact, destination: contact.address)
      original = ceremony.reload.email_otp_context

      assert_raises(ActiveRecord::StatementInvalid) do
        ceremony.class.transaction(requires_new: true) do
          ceremony.update_columns(email_otp_context: original.merge("version" => 2))
        end
      end
      assert_equal original, ceremony.reload.email_otp_context
    end

    test "#{surface} OTP and committed result deadlines cannot outlive their parent" do
      address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      ceremony, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      parent = issuance.transaction
      parent.update!(login_challenge_expires_at: parent.class.database_now + 20.seconds)
      code = ceremony.issue_email_otp!(contact: contact, destination: contact.address)

      assert_equal parent.reload.login_challenge_expires_at,
                   Time.iso8601(ceremony.reload.email_otp_context.fetch("expires_at"))
      assert_predicate ceremony.verify_email_otp!(code: code), :success?
      assert_equal parent.login_challenge_expires_at,
                   Time.iso8601(ceremony.reload.email_otp_context.fetch("result_expires_at"))
    end

    test "#{surface} database preserves committed OTP proof against clearing or replacement" do
      address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      ceremony, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      code = ceremony.issue_email_otp!(contact: contact, destination: contact.address)

      assert_predicate ceremony.verify_email_otp!(code: code), :success?
      original = ceremony.reload.email_otp_context
      [nil, original.merge("verified_at" => nil, "result_expires_at" => nil)].each do |replacement|
        assert_raises(ActiveRecord::StatementInvalid) do
          ceremony.class.transaction(requires_new: true) do
            ceremony.update_columns(email_otp_context: replacement)
          end
        end
        assert_equal original, ceremony.reload.email_otp_context
      end
    end

    test "#{surface} dummy verification never succeeds and uses the shared destination budget" do
      destination = "dummy-challenge-#{SecureRandom.hex(8)}@example.test"
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      ceremony, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )

      assert_nil ceremony.issue_email_otp!(contact: nil, destination: destination)
      [nil, "", 0, false, [], {}, "12345", "1234567", "abcdef", "123\0\x00\x00",
       "１２３４５６", "\xFF".dup.force_encoding(Encoding::UTF_8),].each do |input|
        assert_not ceremony.verify_email_otp!(code: input).success?
      end
      assert_equal :verified, EmailOtpVerificationFailureBudget.new.verify!(
        surface: surface.to_sym, purpose: :authentication, channel: :email,
        destination_digest: IdentifierBlindIndex.bidx_for_email(destination, realm: surface.to_sym), valid: true,
      )
      assert_no_difference ["Client.count", "Visitor.count", "ClientEmail.count", "VisitorEmail.count"] do
        5.times { assert_not ceremony.verify_email_otp!(code: "000000").success? }
      end

      assert_equal :locked, EmailOtpVerificationFailureBudget.new.verify!(
        surface: surface.to_sym, purpose: :authentication, channel: :email,
        destination_digest: IdentifierBlindIndex.bidx_for_email(destination, realm: surface.to_sym), valid: true,
      )
      assert_nil ceremony.reload.email_otp_context.fetch("verified_at")
    end

    [-1, 0, 1].each do |microseconds|
      test "#{surface} OTP expiry boundary #{microseconds} microseconds is checked with the locked Ticket clock" do
        address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
        if surface == "app"
          owner = Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
          )
          contact = owner.client_emails.create!(
            address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
        else
          owner = Visitor.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
          )
          contact = owner.visitor_emails.create!(
            address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
        end
        issuance = OidcTestEntry.issue!(
          surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
        ceremony, = model.rotate_and_admit!(
          admission_purpose: "authentication_handoff",
          authorization_transaction_ref: issuance.transaction.transaction_id,
        )
        # The OTP and its result deadlines are measured inside a parent that outlives both.
        issuance.transaction.update!(
          expires_at: issuance.transaction.expires_at + 1.hour,
          login_challenge_expires_at: issuance.transaction.expires_at + 1.hour,
        )
        code = ceremony.issue_email_otp!(contact: contact, destination: contact.address)
        context = ceremony.reload.email_otp_context.deep_dup
        expiry = Time.iso8601(context.fetch("expires_at"))
        result = nil
        ceremony.class.stub(:database_now, expiry + Rational(microseconds, 1_000_000)) do
          result = ceremony.verify_email_otp!(code: code)
        end

        assert_equal microseconds.negative?, result.success?
        assert_equal context, ceremony.reload.email_otp_context unless microseconds.negative?
      end
    end

    test "#{surface} committed result has a separate deadline and survives the original OTP deadline" do
      address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      ceremony, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      # The OTP and its result deadlines are measured inside a parent that outlives both.
      issuance.transaction.update!(
        expires_at: issuance.transaction.expires_at + 1.hour,
        login_challenge_expires_at: issuance.transaction.expires_at + 1.hour,
      )
      code = ceremony.issue_email_otp!(contact: contact, destination: contact.address)
      expiry = Time.iso8601(ceremony.reload.email_otp_context.fetch("expires_at"))

      ceremony.class.stub(:database_now, expiry - Rational(1, 1_000_000)) do
        assert_predicate ceremony.verify_email_otp!(code: code), :success?
      end
      context = ceremony.reload.email_otp_context.deep_dup
      result_expiry = Time.iso8601(context.fetch("result_expires_at"))

      assert_operator result_expiry, :>, expiry
      [-1, 0, 1].each do |microseconds|
        ceremony.class.stub(:database_now, result_expiry + Rational(microseconds, 1_000_000)) do
          result = ceremony.verify_email_otp!(code: code)

          assert_not result.success?, "an already consumed code cannot succeed again before or after receipt expiry"
          assert_equal microseconds.negative?, result.verified_evidence?
          assert_equal context, ceremony.reload.email_otp_context
        end
      end
    end

    test "#{surface} a correctly digested challenge with a different parent cannot authorize this flow" do
      address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      ceremony, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      issuance = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      other, = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      code = ceremony.issue_email_otp!(contact: contact, destination: contact.address)
      substituted = ceremony.reload.email_otp_context.merge("parent_ref" => other.authorization_transaction_ref)
      substituted["code_digest"] = AuthEmailOtpCodeDigest.for(context: substituted, code: code)
      ceremony.update!(email_otp_context: substituted)
      unchanged = ceremony.reload.attributes
      result = ceremony.verify_email_otp!(code: code)

      assert_not result.success?
      assert_equal unchanged, ceremony.reload.attributes
      assert_equal :verified, EmailOtpVerificationFailureBudget.new.verify!(
        surface: surface.to_sym, purpose: :authentication, channel: :email,
        destination_digest: contact.address_digest, valid: true,
      )
    end

    {
      "surface" => "org",
      "purpose" => "credential_registration",
      "sid_digest" => "f" * 64,
      "parent_kind" => "local_sign_in",
    }.each do |field, foreign_value|
      test "#{surface} correctly digested foreign #{field} refuses before comparison" do
        address = "flow-otp-#{SecureRandom.hex(8)}@example.test"
        if surface == "app"
          owner = Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
          )
          contact = owner.client_emails.create!(
            address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
        else
          owner = Visitor.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
          )
          contact = owner.visitor_emails.create!(
            address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
        end
        issuance = OidcTestEntry.issue!(
          surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
        ceremony, = model.rotate_and_admit!(
          admission_purpose: "authentication_handoff",
          authorization_transaction_ref: issuance.transaction.transaction_id,
        )
        code = ceremony.issue_email_otp!(contact: contact, destination: contact.address)
        context = ceremony.reload.email_otp_context.merge(field => foreign_value)
        context["code_digest"] = AuthEmailOtpCodeDigest.for(context: context, code: code)
        ceremony.update!(email_otp_context: context)
        unchanged = ceremony.reload.attributes
        contact_unchanged = contact.reload.attributes

        assert_not ceremony.verify_email_otp!(code: code).success?
        assert_equal unchanged, ceremony.reload.attributes
        assert_equal contact_unchanged, contact.reload.attributes
      end
    end
  end
end
