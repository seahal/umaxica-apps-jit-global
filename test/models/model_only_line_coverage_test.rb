# typed: false
# frozen_string_literal: true

require "test_helper"

class ModelOnlyLineCoverageTest < ActiveSupport::TestCase
  test "actor configuration null values and dynamic access preserve value semantics" do
    null_value = Actor::Configuration::NULL_VALUE
    configuration = Actor::Configuration.new(feature: "enabled")
    same = Actor::Configuration.new(feature: "enabled")

    # rubocop:disable Minitest/AssertNil,Minitest/AssertPredicate
    assert null_value.nil?
    # rubocop:enable Minitest/AssertNil,Minitest/AssertPredicate
    assert_equal null_value, Actor::Configuration::NullValue.new
    assert_respond_to null_value, :anything
    assert_same null_value, null_value.anything.deeply.missing
    assert_equal "enabled", configuration[:feature]
    assert_equal "enabled", configuration.feature
    assert_respond_to configuration, :feature
    assert_equal configuration, same
    assert_equal configuration.hash, same.hash
  end

  test "actor preferences track explicit fields hashes and cookie input forms" do
    preference = Actor::Preference.new(explicit_fields: [:language])
    same = Actor::Preference.new(explicit_fields: ["language"])

    assert preference.explicit?(:language)
    assert_predicate preference, :language_explicit?
    assert_equal preference, same
    assert_equal preference.hash, same.hash

    cookie = Actor::Preference::Cookie.new(
      consented: true, functional: true, performant: false, targetable: false,
      consent_version: 1, consented_at: Time.zone.parse("2026-07-18 08:00:00"),
    )

    assert_same cookie, Actor::Preference.cookie_from(cookie)

    from_hash = preference.with_cookie(
      consented: true,
      functional: true,
      performant: false,
      targetable: false,
      consent_version: 1,
      consented_at: Time.zone.parse("2026-07-18 08:00:00"),
    )

    assert_predicate from_hash.cookie, :consented?
    assert_predicate from_hash.cookie, :functional?
  end

  test "privacy request defaults scopes cancellation and legal hold are executable" do
    request = ClientPrivacyRequest.new

    assert_not request.valid?
    assert_equal "erasure", request.request_kind
    assert_equal "self_service", request.request_source
    assert_equal "unknown", request.jurisdiction
    assert_equal ClientPrivacyRequest.status_id_for("RECEIVED"), request.status_id
    assert_predicate request, :received?
    assert_kind_of ActiveRecord::Relation, ClientPrivacyRequest.open_for_recovery_block
    assert_kind_of ActiveRecord::Relation, ClientPrivacyRequest.open_for_hold_block

    updates = []
    request.stub(:update!, ->(attributes) { updates << attributes }) do
      now = Time.zone.parse("2026-07-18 08:00:00")
      request.cancel_from_recovery!(now: now)
      request.block_by_legal_hold!(now: now)
    end

    assert_equal ClientPrivacyRequest.status_id_for("CANCELLED"), updates.first[:status_id]
    assert_equal ClientPrivacyRequest.status_id_for("BLOCKED_BY_LEGAL_HOLD"), updates.last[:status_id]
  end

  test "retainable discard now validates duration and clamps to persisted creation" do
    record = AppPreference.new(created_at: 1.minute.from_now)

    assert_raises(ArgumentError) { record.discard_now!(purge_after: 10) }

    updates = []
    record.stub(:update!, ->(attributes) { updates << attributes }) do
      now = Time.current
      record.discard_now!(purge_after: 1.day, now: now)
    end

    assert_equal record.created_at, updates.last[:discarded_at]
    assert_operator updates.last[:purged_at], :>, updates.last[:discarded_at]
  end

  test "preference value records apply their default option ids" do
    classes = [
      ClientPreferenceAdultContentGate, ClientPreferenceDateFormat, ClientPreferenceDensity,
      ClientPreferenceLanguage, ClientPreferenceMotion, ClientPreferencePageSize, ClientPreferenceRegion,
      ClientPreferenceTheme, ClientPreferenceTimeFormat, ClientPreferenceTimezone,
      ComPreferenceAdultContentGate, ComPreferenceCurrency, ComPreferenceDateFormat, ComPreferenceDensity,
      ComPreferenceMotion, ComPreferencePageSize, ComPreferenceTimeFormat,
      OperatorPreferenceAdultContentGate, OperatorPreferenceDateFormat, OperatorPreferenceDensity,
      OperatorPreferenceMotion, OperatorPreferencePageSize, OperatorPreferenceRegion,
      OperatorPreferenceTheme, OperatorPreferenceTimeFormat, OperatorPreferenceTimezone,
      OrgPreferenceAdultContentGate, OrgPreferenceCurrency, OrgPreferenceDateFormat, OrgPreferenceDensity,
      OrgPreferenceMotion, OrgPreferencePageSize, OrgPreferenceTimeFormat,
    ]

    classes.each do |model_class|
      record = model_class.new
      record.valid?

      assert_predicate record.option_id, :present?, "#{model_class} should assign a default option"
    end
  end

  test "preference reference records ensure their fixed defaults" do
    classes = [
      ClientPreferenceDateFormatOption, ClientPreferenceDensityOption, ClientPreferenceMotionOption,
      ClientPreferencePageSizeOption, ClientPreferenceTimeFormatOption,
      ComPreferenceDateFormatOption, ComPreferenceDensityOption, ComPreferenceLanguageOption,
      ComPreferenceMotionOption, ComPreferencePageSizeOption, ComPreferenceRegionOption,
      ComPreferenceTimeFormatOption,
      OperatorPreferenceDateFormatOption, OperatorPreferenceDensityOption, OperatorPreferenceMotionOption,
      OperatorPreferencePageSizeOption, OperatorPreferenceTimeFormatOption,
      OrgPreferenceDateFormatOption, OrgPreferenceDensityOption, OrgPreferenceMotionOption,
      OrgPreferencePageSizeOption, OrgPreferenceRegionOption, OrgPreferenceThemeOption,
      OrgPreferenceTimeFormatOption,
    ]

    classes.each do |model_class|
      model_class.ensure_defaults!

      assert_equal model_class::DEFAULTS.sort, model_class.where(id: model_class::DEFAULTS).pluck(:id).sort
    end
  end

  test "withdrawal occurrence records an allowlisted context for each supported surface" do
    created_attributes = nil
    status_class = Object.new
    status_class.define_singleton_method(:ensure_defaults!) { true }
    occurrence_class = Object.new
    occurrence_class.define_singleton_method(:create!) { |attributes| created_attributes = attributes }
    subject = Client.new(public_id: "client-occurrence")
    request = Struct.new(:request_id, :user_agent).new("request-id", "agent")

    WithdrawalOccurrenceRecording.stub(:occurrence_class_for, occurrence_class) do
      WithdrawalOccurrenceRecording.stub(:occurrence_status_class_for, status_class) do
        WithdrawalOccurrenceRecording.stub(:occurrence_status_id_for, 1) do
          WithdrawalOccurrenceRecording.record!(
            subject: subject,
            event_type: :requested,
            request: request,
            context: { reason_code: "self_service", forbidden: "discarded" },
          )
        end
      end
    end

    assert_equal 1, created_attributes[:status_id]
    assert_equal "requested", created_attributes[:event_type]
    assert_equal "app", created_attributes[:context]["surface"]
    assert_equal "self_service", created_attributes[:context]["reason_code"]
    assert_not created_attributes[:context].key?("forbidden")
    assert_equal ClientOccurrence, WithdrawalOccurrenceRecording.occurrence_class_for(subject)
    assert_equal VisitorOccurrence, WithdrawalOccurrenceRecording.occurrence_class_for(Visitor.new)
    assert_equal "com", WithdrawalOccurrenceRecording.surface_for(Visitor.new)
  end

  test "session limit transaction creates finds and completes every remaining state" do
    created_attributes = nil
    relation = Object.new
    relation.define_singleton_method(:active_at) { |_now| self }
    relation.define_singleton_method(:find_by) { |**_attributes| nil }
    created = ClientSessionLimitResolutionTransaction.new(status: "pending", expires_at: 1.minute.from_now)
    actor = Client.new(public_id: "client-session-limit")
    oidc_transaction = Struct.new(:id).new(321)

    ClientSessionLimitResolutionTransaction.stub(:open_status, relation) do
      ClientSessionLimitResolutionTransaction.stub(
        :create!,
        ->(**attributes) { created_attributes = attributes; created },
      ) do
        issuance = ClientSessionLimitResolutionTransaction.issue_for_oidc!(
          actor: actor, oidc_transaction: oidc_transaction,
        )

        assert_same created, issuance.transaction
      end
    end

    assert_equal "pending", created_attributes[:status]

    found = Object.new
    find_relation = Object.new
    find_relation.define_singleton_method(:active_at) { |_now| self }
    find_relation.define_singleton_method(:find_by) { |**_attributes| found }

    ClientSessionLimitResolutionTransaction.stub(:open_status, find_relation) do
      assert_same found, ClientSessionLimitResolutionTransaction.find_active_by_challenge("challenge")
    end

    updates = []
    created.stub(:update!, ->(attributes) { updates << attributes }) do
      now = Time.current
      created.status = "resolved"

      assert_predicate created, :resolved?
      created.status = "cancelled"

      assert_predicate created, :cancelled?
      created.mark_session_selected!(session_ref: 123, now: now)
      created.finalize!(now: now)
      created.cancel!(now: now)
    end

    assert_equal "123", updates.first[:selected_session_ref]
    assert_equal "resolved", updates.second[:status]
    assert_equal "cancelled", updates.third[:status]
  end

  test "oidc token usage scope and rotation update the refresh token family" do
    assert_kind_of ActiveRecord::Relation, ClientRpSession.currently_usable_at(Time.current)

    usage = ClientRpSession.new(public_id: "usage-public-id", refresh_token_digest: "previous")
    updates = []
    usage.stub(:with_lock, ->(&block) { block.call }) do
      usage.stub(:active?, true) do
        usage.stub(:generate_refresh_token, ["raw-token", "verifier"]) do
          usage.stub(:encoded_refresh_token_digest, "next-digest") do
            usage.stub(:update!, ->(attributes) { updates << attributes }) do
              assert_equal "raw-token", usage.rotate_refresh_token!(expires_at: 1.hour.from_now)
            end
          end
        end
      end
    end

    assert_equal "previous", updates.last[:previous_refresh_token_digest]
    assert_equal "next-digest", updates.last[:refresh_token_digest]
  end

  test "secret credential one time verification consumes its final use" do
    credential = ClientSecretCredential.new(uses_remaining: 1)

    credential.stub(:with_lock, ->(&block) { block.call }) do
      credential.stub(:reload, credential) do
        credential.stub(:authenticate, true) do
          credential.stub(:sign_in_status_allowed?, true) do
            credential.stub(:sign_in_kind_allowed?, true) do
              credential.stub(:expired_for_secret_credential_sign_in?, false) do
                credential.stub(:one_time_secret_credential?, true) do
                  credential.stub(:save!, true) do
                    assert credential.verify_for_secret_credential_sign_in!("secret")
                  end
                end
              end
            end
          end
        end
      end
    end

    assert_equal 0, credential.uses_remaining
    assert_equal ClientSecretCredential.status_id_for(:used), credential.user_secret_status_id
  end

  test "avatar group and memberships expose state and timestamp validation" do
    group = AvatarGroup.new(state: "active", archived_at: Time.current)

    assert_not group.active?
    assert_not group.archived?
    assert_not group.valid?
    assert_includes group.errors.details[:archived_at], { error: :present }

    archived = AvatarGroup.new(state: "archived", archived_at: nil)

    assert_not archived.valid?
    assert_includes archived.errors.details[:archived_at], { error: :blank }

    membership = GroupAvatarMembership.new(
      state: "removed", assigned_at: Time.current, removed_at: nil,
    )

    assert_not membership.active?
    assert_not membership.valid?
    assert_includes membership.errors.details[:removed_at], { error: :blank }

    invalid_time = GroupAvatarMembership.new(
      state: "active", assigned_at: Time.current, removed_at: 1.minute.ago,
    )

    assert_not invalid_time.valid?
    assert_includes invalid_time.errors.details[:removed_at], { error: :invalid }
    assert_includes invalid_time.errors.details[:removed_at], { error: :present }
  end

  test "retention hold and processor notification defaults and transitions are complete" do
    hold = ClientRetentionHold.new

    assert_not hold.valid?
    assert_equal "legal_hold", hold.hold_kind
    assert_equal "legal_hold", hold.reason_code
    assert_equal ClientRetentionHold.status_id_for("ACTIVE"), hold.status_id
    assert_predicate hold.applied_at, :present?
    assert_kind_of ActiveRecord::Relation, ClientRetentionHold.active_at(Time.current)

    notification = ClientProcessorErasureNotification.new(retry_count: 0)

    assert_not notification.valid?
    assert_equal ClientProcessorErasureNotification.status_id_for("PENDING"), notification.status_id
    assert_predicate notification.requested_at, :present?

    updates = []
    notification.stub(:update!, ->(attributes) { updates << attributes }) do
      notification.mark_notified!
      notification.mark_failed!(code: :temporary, message: "retry")
    end

    assert_equal ClientProcessorErasureNotification.status_id_for("NOTIFIED"), updates.first[:status_id]
    assert_equal ClientProcessorErasureNotification.status_id_for("FAILED"), updates.last[:status_id]

    notification.status_id = ClientProcessorErasureNotification.status_id_for("SKIPPED")

    assert_predicate notification, :terminal?
  end

  test "dbsc model mappings and downgrade use each model's fixed reference classes" do
    assert_equal AppPreferenceBindingMethod, AppPreference.dbsc_binding_method_class
    assert_equal AppPreferenceDbscStatus, AppPreference.dbsc_status_class
    assert_equal ClientTokenBindingMethod, ClientToken.dbsc_binding_method_classes.fetch("ClientToken")
    assert_equal ClientTokenDbscStatus, ClientToken.dbsc_status_classes.fetch("ClientToken")

    preference = AppPreference.new(dbsc_status_id: AppPreferenceDbscStatus::PENDING)
    updates = []
    preference.stub(:update!, ->(attributes) { updates << attributes }) do
      preference.downgrade_dbsc_status_to_nothing!
    end

    assert_equal({ dbsc_status_id: AppPreferenceDbscStatus::NOTHING }, updates.last)
  end

  test "mfa level compatibility reads both normalized and legacy attributes" do
    client = Client.new(mfa_level_id: ClientMfaLevel::NOTHING, mfa_level_enabled: false)

    assert_not_predicate client, :mfa_level_enabled?
    assert_not_predicate client, :mfa_level_required?

    client.mfa_level_enabled = true

    assert_predicate client, :mfa_level_enabled?
    assert_equal ClientMfaLevel::FULL, client.mfa_level_id
  end

  test "sign in flow recognizes legacy states and advances to return" do
    flow = ClientSignInFlow.new
    flow.stub(:cycle_status?, true) do
      assert_predicate flow, :sign_in_primary_pending?
      assert_predicate flow, :sign_in_dashboard_pending?
      assert_predicate flow, :sign_in_return_pending?
    end

    calls = []
    flow.stub(:transition_sign_in_to!, ->(*arguments, **options) { calls << [arguments, options] }) do
      flow.advance_sign_in_to_return!
    end

    assert_equal "RETURN_PENDING", calls.last.first.first
  end

  test "step up purge scope and connection owners cover every store" do
    now = Time.zone.parse("2026-07-18 08:00:00")

    assert_kind_of ActiveRecord::Relation, ClientStepUpCeremonyTransaction.purgeable_at(now)
    assert_equal OrgTicketRecord, OperatorStepUpCeremonyTransaction.connection_owner
    assert_equal ComTicketRecord, VisitorStepUpCeremonyTransaction.connection_owner
  end

  test "small public model APIs and reference defaults are covered by model tests" do
    VisitorTokenBindingMethod.ensure_defaults!
    ComPreferenceBindingMethod.ensure_defaults!
    AppPreferenceChronicleEvent.ensure_defaults!
    ComPreferenceChronicleEvent.ensure_defaults!
    OrgPreferenceChronicleEvent.ensure_defaults!

    assert_equal VisitorTokenBindingMethod::DEFAULTS.sort,
                 VisitorTokenBindingMethod.where(id: VisitorTokenBindingMethod::DEFAULTS).pluck(:id).sort
    assert_predicate OperatorSecretCredential.generate_raw_secret_credential, :present?
    assert_equal :operator, OperatorEmail.new.promotional_unsubscribe_scope
    assert_equal :visitor, VisitorEmail.new.promotional_unsubscribe_scope
    assert_equal "visitor-email", VisitorEmail.new(public_id: "visitor-email").to_param
    assert_equal "public", Client.new(public_id: "public").to_param
    assert_equal "nothing", AppPreference.new.adult_content_gate
    assert_equal "nothing", ClientPreference.new.adult_content_gate
    assert_predicate ClientSecretCredential.new(user_secret_kind_id: ClientSecretCredentialKind::ONE_TIME),
                     :one_time_secret_credential?
  end

  test "email lookup and ceremony candidate validation cover valid and invalid shapes" do
    assert_kind_of ActiveRecord::Relation, VisitorEmail.with_address("visitor@example.test")
    assert_kind_of ActiveRecord::Relation, VisitorEmail.with_address(nil)

    valid = IdentitySocialCeremonyCandidate.new(
      auth_hash: {
        "principal" => {
          "provider" => "google",
          "subject" => "uid",
          "issuer" => "https://accounts.google.com",
          "audience" => "client-id",
          "verified_at" => Time.current.iso8601,
          "verification_authority" => "google",
        },
      },
    )
    valid.valid?

    assert_empty valid.errors.details[:auth_hash]

    invalid = IdentitySocialCeremonyCandidate.new(auth_hash: {})

    assert_not invalid.valid?
    assert_includes invalid.errors.details[:auth_hash], { error: "is invalid" }
  end

  test "signup and acme logout no-op predicates use their configured entry states" do
    flow = ClientSignUpFlow.new(entry_method: "google")

    assert_includes ClientSignUpFlow.social_entry_methods, "google"
    assert_predicate flow, :social_entry_method?

    failed = AcmeLogoutTransaction.new(status: "failed")
    finalized = AcmeLogoutTransaction.new(status: "finalized")

    assert_same failed, failed.fail!
    assert_same finalized, finalized.fail!
  end

  test "model scopes and unlink predicate remain queryable" do
    assert_kind_of ActiveRecord::Relation, ClientWithdrawalFlow.active
    assert_kind_of ActiveRecord::Relation, ClientSignInFlow.current

    client = Client.new

    client.stub(:remaining_social_unlink_methods, [:email]) do
      assert client.social_unlink_methods_remaining?(excluding_provider: "google")
    end
  end

  test "withdrawal ceremony issue and expiration use the model boundary" do
    subject = Client.new
    created = Object.new
    attributes = nil

    ClientWithdrawalCeremony.stub(:create!, ->(**values) { attributes = values; created }) do
      assert_same created, ClientWithdrawalCeremony.issue!(subject: subject)
    end
    assert_same subject, attributes[:client]

    ceremony = ClientWithdrawalCeremony.new(
      status_id: WithdrawalCeremonyRecordable::STATUS_ACTIVE,
      expires_at: 1.minute.ago,
    )

    assert_predicate ceremony, :expired?
  end

  test "secret credential usability accepts a positive one-time counter" do
    credential = ClientSecretCredential.new(uses_remaining: 1)
    credential.stub(:sign_in_status_allowed?, true) do
      credential.stub(:sign_in_kind_allowed?, true) do
        credential.stub(:expired_for_secret_credential_sign_in?, false) do
          credential.stub(:permanent_secret_credential?, false) do
            assert_predicate credential, :usable_for_secret_credential_sign_in?
          end
        end
      end
    end
  end

  test "step up result collision is translated to the ceremony contract error" do
    now = Time.zone.parse("2026-07-18 08:00:00")
    first = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "collision-actor-1", session_ref: "collision-session-1",
      required_scope: "settings_email", required_aal: "aal2", allowed_methods: %w(totp),
      transaction_id: "collision-transaction-1", grant_jti: "collision-grant-1", now: now,
    )
    first.consume_result!(
      result_jti: "collision-result", method: "totp", aal: "aal2",
      verified_at: now, consumed_at: now,
    )
    second = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "collision-actor-2", session_ref: "collision-session-2",
      required_scope: "settings_email", required_aal: "aal2", allowed_methods: %w(totp),
      transaction_id: "collision-transaction-2", grant_jti: "collision-grant-2", now: now,
    )

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      second.consume_result!(
        result_jti: "collision-result", method: "totp", aal: "aal2",
        verified_at: now, consumed_at: now,
      )
    end
  end

  test "oidc authorization resume URL delegates to the configured Acme origin" do
    origin = Object.new
    origin.define_singleton_method(:authorization_endpoint) do |query:|
      "https://acme.example.test/authorize?login_challenge=#{query.fetch(:login_challenge)}"
    end
    transaction = ClientOidcAuthorizationTransaction.new(login_challenge: "login-challenge")

    Oidc::AcmeServiceOrigin.stub(:from, origin) do
      assert_equal "https://acme.example.test/authorize?login_challenge=login-challenge",
                   transaction.acme_resume_url
    end
  end

  test "org preference chronicle defaults its actor to its subject" do
    preference = OrgPreference.new(id: 123)
    chronicle = OrgPreferenceChronicle.new(subject_id: 123, subject_type: "OrgPreference")

    chronicle.stub(:org_preference, preference) do
      chronicle.default_actor_to_preference
    end

    assert_same preference, chronicle.actor
  end

  test "acme logout failure records the failed transition" do
    transaction = AcmeLogoutTransaction.new(status: "initiated")
    updates = []
    transaction.stub(:update!, ->(attributes) { updates << attributes }) do
      transaction.fail!(now: Time.zone.parse("2026-07-18 08:00:00"))
    end

    assert_equal "failed", updates.last[:status]
  end

  test "step up transaction exposes scopes claims and valid state transitions" do
    now = Time.zone.parse("2026-07-18 08:00:00")
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "actor-model-coverage",
      session_ref: "session-model-coverage",
      required_scope: "settings_email",
      required_aal: "aal2",
      allowed_methods: %w(totp totp passkey),
      resource_ref: "resource-model-coverage",
      return_to: "/settings/email",
      transaction_id: "model-coverage-step-up",
      grant_jti: "model-coverage-grant",
      now: now,
    )

    assert_equal %w(totp passkey), transaction.allowed_methods_array
    assert_equal "model-coverage-step-up", transaction.grant_claims(now: now)["transaction_id"]
    assert_not transaction.expired?(now: now)
    assert_includes ClientStepUpCeremonyTransaction.active_at(now), transaction
    assert_includes ClientStepUpCeremonyTransaction.pending, transaction
    assert_equal transaction,
                 ClientStepUpCeremonyTransaction.latest_pending_for(
                   actor_ref: transaction.actor_ref,
                   session_ref: transaction.session_ref,
                   required_scope: transaction.required_scope,
                   now: now,
                 )

    consumed = transaction.consume_result!(
      result_jti: "model-coverage-result",
      method: "totp",
      aal: "aal2",
      verified_at: now,
      consumed_at: now,
    )

    assert_predicate consumed, :consumed?
    assert_includes ClientStepUpCeremonyTransaction.consumed, consumed
  end

  test "step up cancellation scopes and validations reject invalid state" do
    now = Time.zone.parse("2026-07-18 08:00:00")
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "actor-model-cancel",
      session_ref: "session-model-cancel",
      required_scope: "settings_email",
      required_aal: "aal2",
      allowed_methods: %w(totp),
      transaction_id: "model-coverage-cancel",
      grant_jti: "model-coverage-cancel-grant",
      expires_at: now + 1.minute,
      now: now,
    )

    canceled = transaction.cancel!(canceled_at: now)

    assert_predicate canceled, :canceled?
    assert_includes ClientStepUpCeremonyTransaction.canceled, canceled

    invalid = ClientStepUpCeremonyTransaction.new(
      surface: "com",
      status: "consumed",
      allowed_methods: "invalid",
      expires_at: now,
    )

    assert_not invalid.valid?
    assert_includes invalid.errors.details[:surface], { error: "does not match transaction store" }
    assert_includes invalid.errors.details[:allowed_methods], { error: "contains invalid methods" }
    assert_includes invalid.errors.details[:result_jti], { error: "is required for consumed transaction" }
    assert_includes invalid.errors.details[:method], { error: "is required for consumed transaction" }
    assert_includes invalid.errors.details[:aal], { error: "is required for consumed transaction" }
    assert_includes invalid.errors.details[:verified_at], { error: "is required for consumed transaction" }
  end

  test "withdrawal ceremony defaults authenticate and state changes are deterministic" do
    Time.zone.parse("2026-07-18 08:00:00")
    subject = Struct.new(:withdrawal_in_progress?, :terminated?).new(true, false)
    ceremony = ClientWithdrawalCeremony.new(status_id: WithdrawalCeremonyRecordable::STATUS_ACTIVE)

    ceremony.stub(:subject, subject) do
      assert_not ceremony.valid?
      assert_equal "status", ceremony.purpose
      assert_operator ceremony.expires_at, :>, Time.current
      assert_predicate ceremony.plaintext_token, :present?
      assert ceremony.token_matches?(ceremony.plaintext_token)
      assert_predicate ceremony, :subject_withdrawal_restricted?
    end

    updates = []
    ceremony.stub(:update!, ->(attributes) { updates << attributes }) do
      ceremony.consume!
      ceremony.revoke!
    end

    assert_equal WithdrawalCeremonyRecordable::STATUS_CONSUMED, updates.first[:status_id]
    assert_equal WithdrawalCeremonyRecordable::STATUS_REVOKED, updates.last[:status_id]

    ClientWithdrawalCeremony.stub(:find_by, ceremony) do
      ceremony.stub(:active?, true) do
        ceremony.stub(:token_matches?, true) do
          ceremony.stub(:subject_withdrawal_restricted?, true) do
            assert_equal ceremony,
                         ClientWithdrawalCeremony.authenticate(public_id: "public", token: "token")
          end
        end
      end
    end

    assert_nil ClientWithdrawalCeremony.authenticate(public_id: nil, token: "token")
    assert_nil ClientWithdrawalCeremony.digest_optional(nil)
    assert_equal ClientWithdrawalCeremony.digest_token("ip"), ClientWithdrawalCeremony.digest_optional("ip")
  end

  test "withdrawal ceremony predicates cover expired consumed revoked and mismatched tokens" do
    now = Time.current
    ceremony = ClientWithdrawalCeremony.new(
      status_id: WithdrawalCeremonyRecordable::STATUS_EXPIRED,
      expires_at: now + 1.hour,
      token_digest: "short",
      consumed_at: now,
      revoked_at: now,
    )

    assert_predicate ceremony, :expired?
    assert_predicate ceremony, :consumed?
    assert_predicate ceremony, :revoked?
    assert_not ceremony.active?
    assert_not ceremony.token_matches?(nil)
    assert_not ceremony.token_matches?("different-length-token")
  end

  test "identity ceremony candidates reject missing consumed and expired records then consume active records" do
    now = Time.zone.parse("2026-07-18 08:00:00")
    error_class = Class.new(StandardError)
    consumed = Struct.new(:consumed_at, :expires_at).new(now, now + 1.minute)
    expired = Struct.new(:consumed_at, :expires_at).new(nil, now - 1.minute)
    active = Struct.new(:consumed_at, :expires_at).new(nil, now + 1.minute)

    IdentitySocialCeremonyCandidate.stub(:find_by, nil) do
      assert_raises(error_class) do
        IdentitySocialCeremonyCandidate.find_active_by_ref!(
          "missing", now: now, error_class: error_class,
                     not_found_message: "missing", expired_message: "expired",
        )
      end
    end
    IdentitySocialCeremonyCandidate.stub(:find_by, consumed) do
      assert_raises(error_class) do
        IdentitySocialCeremonyCandidate.find_active_by_ref!(
          "consumed", now: now, error_class: error_class,
                      not_found_message: "missing", expired_message: "expired",
        )
      end
    end
    IdentitySocialCeremonyCandidate.stub(:find_by, expired) do
      assert_raises(error_class) do
        IdentitySocialCeremonyCandidate.find_active_by_ref!(
          "expired", now: now, error_class: error_class,
                     not_found_message: "missing", expired_message: "expired",
        )
      end
    end
    IdentitySocialCeremonyCandidate.stub(:find_by, active) do
      assert_same active,
                  IdentitySocialCeremonyCandidate.find_active_by_ref!(
                    "active", now: now, error_class: error_class,
                              not_found_message: "missing", expired_message: "expired",
                  )
    end

    locked = Struct.new(:consumed_at, :expires_at) do
      attr_reader :updates

      def update!(attributes)
        @updates = attributes
        self
      end
    end.new(nil, now + 1.minute)
    lock_relation = Object.new
    lock_relation.define_singleton_method(:find_by) { |ref:| (ref == "candidate") ? locked : nil }
    candidate = IdentitySocialCeremonyCandidate.new(ref: "candidate")

    IdentitySocialCeremonyCandidate.stub(:lock, lock_relation) do
      assert_same locked,
                  candidate.consume!(
                    now: now, error_class: error_class,
                    not_found_message: "missing", expired_message: "expired",
                  )
    end
    assert_equal({ consumed_at: now }, locked.updates)
  end
end
