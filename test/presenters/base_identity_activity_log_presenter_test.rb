# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseIdentityActivityLogPresenterTest < ActiveSupport::TestCase
  ActivityRecord = Struct.new(:event_id, :context, :ip_address, :occurred_at, :created_at, keyword_init: true)
  CommonActivityRecord = Struct.new(:action, :metadata, :event_uuid, :occurred_at, :created_at, :id, keyword_init: true)

  test "normalizes a provider sign-in without exposing audit fields or a private source address" do
    activity = ActivityRecord.new(
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      context: {
        "provider" => "google",
        "auth_method" => "social",
        "oidc_client_id" => "private-client",
        "sign-rp" => "internal-rp",
        "social_session_limitation" => "internal-policy",
        "user_agent" => "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/128.0",
      },
      ip_address: "10.2.3.4",
      occurred_at: Time.utc(2026, 9, 13, 9, 8),
    )
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)

    row = I18n.with_locale(:ja) { presenter.present(activity) }

    assert_equal %i(occurred_at activity device source risk risk_rank), row.keys
    assert_equal "Googleでサインイン", row.fetch(:activity)
    assert_equal "Firefox / Linux", row.fetch(:device)
    assert_equal "場所を確認できません", row.fetch(:source)
    assert_equal "低", row.fetch(:risk)
    assert_not_includes row.values.join(" "), "10.2.3.4"
    assert_not_includes row.values.join(" "), "private-client"
    assert_not_includes row.values.join(" "), "social"
  end

  test "keeps provider account creation distinct from a sign-in" do
    activity = ActivityRecord.new(
      event_id: ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE,
      context: {},
      occurred_at: Time.utc(2026, 9, 13, 9, 8),
    )
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)

    row = I18n.with_locale(:en) { presenter.present(activity) }

    assert_equal "Account created with Google", row.fetch(:activity)
  end

  test "does not use persistence metadata as the activity occurrence time" do
    activity = ActivityRecord.new(
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      context: {},
      occurred_at: nil,
      created_at: Time.utc(2026, 9, 13, 9, 8),
    )
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)

    row = I18n.with_locale(:en) { presenter.present(activity) }

    assert_nil row.fetch(:occurred_at)
  end

  test "risk ordering is explicit and refresh success stays internal independently of risk" do
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)
    refresh = ActivityRecord.new(
      event_id: ClientChronicleEvent::TOKEN_REFRESHED, context: {},
      occurred_at: Time.current,
    )

    assert_operator presenter.risk_rank("none"), :<, presenter.risk_rank("low")
    assert_operator presenter.risk_rank("low"), :<, presenter.risk_rank("medium")
    assert_operator presenter.risk_rank("medium"), :<, presenter.risk_rank("high")
    assert_operator presenter.risk_rank("high"), :<, presenter.risk_rank("critical")
    assert_nil presenter.present(refresh)
    assert_includes presenter.visible_event_ids, ClientChronicleEvent::LOGIN_SUCCESS
    assert_not_includes presenter.visible_event_ids, ClientChronicleEvent::TOKEN_REFRESHED
  end

  test "attention events remain user visible with their independent risk labels" do
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)
    step_up_failure = ActivityRecord.new(
      event_id: ClientChronicleEvent::STEP_UP_FAILED,
      context: { "auth_method" => "email_otp", "otp" => "123456" },
      occurred_at: Time.current,
    )
    reuse = ActivityRecord.new(
      event_id: ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
      context: { "token_family_id" => "family-internal" },
      occurred_at: Time.current,
    )

    failed_row = I18n.with_locale(:ja) { presenter.present(step_up_failure) }
    reuse_row = I18n.with_locale(:en) { presenter.present(reuse) }

    assert_equal "追加認証に失敗", failed_row.fetch(:activity)
    assert_equal "中", failed_row.fetch(:risk)
    assert_equal "High", reuse_row.fetch(:risk)
    assert_includes presenter.visible_event_ids, ClientChronicleEvent::STEP_UP_FAILED
    assert_includes presenter.visible_event_ids, ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED
    assert_not_includes failed_row.values.join(" "), "email_otp"
    assert_not_includes failed_row.values.join(" "), "123456"
    assert_not_includes reuse_row.values.join(" "), "family-internal"
  end

  test "rejects an unsupported surface" do
    assert_raises(ArgumentError) { Base::Identity::ActivityLogPresenter.new(surface: :warp) }
  end

  test "merges persisted legacy and common passkey history under owner scope before limiting" do
    client = fresh_client
    other = fresh_client
    policy =
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |record|
        record.name = "Security"
        record.duration_days = 365
        record.permanent = false
      end
    occurred_at = Time.utc(2026, 10, 1, 12)
    legacy = ClientChronicle.create!(
      actor: client, subject_type: "Client", subject_id: client.id,
      event_id: ClientChronicleEvent::PASSKEY_REGISTERED, context: {},
      occurred_at: occurred_at, discard_at: occurred_at + 365.days, purge_eligible_at: occurred_at + 365.days,
    )
    common = Chronicle.create!(
      event_uuid: SecureRandom.uuid, action: "passkey.removed", result: "succeeded",
      occurred_at: occurred_at + 1.minute, changeset: {},
      metadata: { surface: "app", actor_ref: client.public_id, external_id: SecureRandom.uuid },
      chronicle_retention_policy: policy,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: occurred_at + 1.minute),
    )
    Chronicle.create!(
      event_uuid: SecureRandom.uuid, action: "passkey.removed", result: "succeeded",
      occurred_at: occurred_at + 2.minutes, changeset: {},
      metadata: { surface: "app", actor_ref: other.public_id, external_id: SecureRandom.uuid },
      chronicle_retention_policy: policy,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: occurred_at + 2.minutes),
    )
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)
    scope = ClientChronicle.where(subject_type: "Client", subject_id: client.id)

    assert_equal [common, legacy], presenter.app_activities(scope, client: client, limit: 3)
    assert_equal [common, legacy], presenter.app_activities(scope, client: client, limit: 2)
    assert_equal [common], presenter.app_activities(scope, client: client, limit: 1)
    assert_raises(ArgumentError) { presenter.app_activities(scope, client: client, limit: 0) }
    assert_equal "Passkey registered", I18n.with_locale(:en) { presenter.present(legacy).fetch(:activity) }
  end

  test "an owner without history yields no activity and the limit must be a positive integer" do
    client = fresh_client
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)
    scope = ClientChronicle.where(subject_type: "Client", subject_id: client.id)

    assert_equal [], presenter.app_activities(scope, client: client, limit: 1)
    [0, -1, nil, "1", 1.0].each do |invalid|
      assert_raises(ArgumentError, "limit #{invalid.inspect}") do
        presenter.app_activities(scope, client: client, limit: invalid)
      end
    end
  end

  test "equal occurrence times across legacy and common history order by creation time" do
    client = fresh_client
    policy =
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |record|
        record.name = "Security"
        record.duration_days = 365
        record.permanent = false
      end
    occurred_at = Time.utc(2026, 10, 1, 12)
    common = Chronicle.create!(
      event_uuid: SecureRandom.uuid, action: "passkey.removed", result: "succeeded",
      occurred_at: occurred_at, changeset: {},
      metadata: { surface: "app", actor_ref: client.public_id, external_id: SecureRandom.uuid },
      chronicle_retention_policy: policy,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: occurred_at),
    )
    legacy = ClientChronicle.create!(
      actor: client, subject_type: "Client", subject_id: client.id,
      event_id: ClientChronicleEvent::PASSKEY_REGISTERED, context: {},
      occurred_at: occurred_at, discard_at: occurred_at + 365.days, purge_eligible_at: occurred_at + 365.days,
    )
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)
    scope = ClientChronicle.where(subject_type: "Client", subject_id: client.id)

    assert_operator legacy.created_at, :>, common.created_at
    assert_equal [legacy, common], presenter.app_activities(scope, client: client, limit: 2)
    assert_equal [legacy], presenter.app_activities(scope, client: client, limit: 1)
  end

  test "legacy history inserted out of occurrence order still returns the latest occurrence first" do
    client = fresh_client
    occurred_at = Time.utc(2026, 10, 1, 12)
    later = ClientChronicle.create!(
      actor: client, subject_type: "Client", subject_id: client.id,
      event_id: ClientChronicleEvent::PASSKEY_REGISTERED, context: {},
      occurred_at: occurred_at + 1.hour, discard_at: occurred_at + 365.days, purge_eligible_at: occurred_at + 365.days,
    )
    earlier = ClientChronicle.create!(
      actor: client, subject_type: "Client", subject_id: client.id,
      event_id: ClientChronicleEvent::PASSKEY_REMOVED, context: {},
      occurred_at: occurred_at, discard_at: occurred_at + 365.days, purge_eligible_at: occurred_at + 365.days,
    )
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)
    scope = ClientChronicle.where(subject_type: "Client", subject_id: client.id)

    assert_equal [later, earlier], presenter.app_activities(scope, client: client, limit: 2)
    assert_equal [later], presenter.app_activities(scope, client: client, limit: 1)
  end

  test "presents common Chronicle passkey events without exposing metadata" do
    activity = CommonActivityRecord.new(
      action: "passkey.description_changed",
      metadata: { "surface" => "app", "actor_ref" => "client-1", "external_id" => SecureRandom.uuid },
      event_uuid: SecureRandom.uuid,
      occurred_at: Time.utc(2026, 9, 13, 9, 8),
      created_at: Time.utc(2026, 9, 13, 9, 8),
      id: 1,
    )
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)

    row = I18n.with_locale(:en) { presenter.present(activity) }

    assert_equal "Passkey name changed", row.fetch(:activity)
    assert_equal "Unknown device", row.fetch(:device)
    assert_not_includes row.values.join(" "), "client-1"
    assert_not_includes row.values.join(" "), activity.metadata.fetch("external_id")
  end

  test "deduplicates legacy and common passkey facts only with matching stable references" do
    client = fresh_client
    external_id = SecureRandom.uuid
    operation_ref = SecureRandom.uuid
    occurred_at = Time.utc(2026, 10, 1, 12)
    policy =
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |record|
        record.name = "Security"
        record.duration_days = 365
        record.permanent = false
      end
    legacy = ClientChronicle.create!(
      actor: client, subject_type: "Client", subject_id: client.id,
      event_id: ClientChronicleEvent::PASSKEY_REGISTERED,
      context: { external_id: external_id, operation_ref: operation_ref },
      occurred_at: occurred_at, discard_at: occurred_at + 365.days, purge_eligible_at: occurred_at + 365.days,
    )
    common = Chronicle.create!(
      event_uuid: SecureRandom.uuid, action: "passkey.registered.settings", result: "succeeded",
      occurred_at: occurred_at, request_id: operation_ref, changeset: {},
      metadata: { surface: "app", actor_ref: client.public_id, external_id: external_id },
      chronicle_retention_policy: policy,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: occurred_at),
    )
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)
    scope = ClientChronicle.where(subject_type: "Client", subject_id: client.id)

    assert_equal 1, presenter.app_activities(scope, client: client).size
    legacy.update!(context: {})

    assert_equal [common, legacy], presenter.app_activities(scope, client: client)
  end

  test "does not present common Chronicle passkey events on another surface" do
    activity = CommonActivityRecord.new(
      action: "passkey.removed",
      metadata: { "surface" => "app", "actor_ref" => "client-1" },
      event_uuid: SecureRandom.uuid,
      occurred_at: Time.current,
      created_at: Time.current,
      id: 1,
    )

    assert_nil Base::Identity::ActivityLogPresenter.new(surface: :com).present(activity)
  end

  test "labels an Apple provider sign-in and common device agents" do
    presenter = Base::Identity::ActivityLogPresenter.new(surface: :app)

    apple = ActivityRecord.new(
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      context: {
        "provider" => "apple",
        "user_agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Safari/604.1",
      },
      occurred_at: Time.utc(2026, 9, 13, 9, 8),
    )
    edge = ActivityRecord.new(
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      context: {
        "provider" => "password",
        "user_agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Edg/120.0.0.0",
      },
      occurred_at: Time.utc(2026, 9, 13, 9, 8),
    )
    chrome_android = ActivityRecord.new(
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      context: {
        "user_agent" => "Mozilla/5.0 (Linux; Android 14) Chrome/120.0.0.0 Mobile Safari/537.36",
      },
      occurred_at: Time.utc(2026, 9, 13, 9, 8),
    )
    safari_mac = ActivityRecord.new(
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      context: {
        "user_agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) Version/17.0 Safari/605.1.15",
      },
      occurred_at: Time.utc(2026, 9, 13, 9, 8),
    )
    unknown = ActivityRecord.new(
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      context: { "user_agent" => "CustomAgent/1.0" },
      occurred_at: Time.utc(2026, 9, 13, 9, 8),
    )
    non_hash = ActivityRecord.new(
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      context: "not-a-hash",
      occurred_at: Time.utc(2026, 9, 13, 9, 8),
    )

    apple_row = I18n.with_locale(:en) { presenter.present(apple) }
    edge_row = I18n.with_locale(:en) { presenter.present(edge) }
    chrome_row = I18n.with_locale(:en) { presenter.present(chrome_android) }
    safari_row = I18n.with_locale(:en) { presenter.present(safari_mac) }
    unknown_row = I18n.with_locale(:en) { presenter.present(unknown) }
    non_hash_row = I18n.with_locale(:en) { presenter.present(non_hash) }

    assert_equal "Signed in with Apple", apple_row.fetch(:activity)
    assert_equal "Safari / iOS", apple_row.fetch(:device)
    assert_equal "Edge / Windows", edge_row.fetch(:device)
    assert_equal "Chrome / Android", chrome_row.fetch(:device)
    assert_equal "Safari / macOS", safari_row.fetch(:device)
    assert_match(/unknown|不明/i, unknown_row.fetch(:device))
    assert_match(/unknown|不明/i, non_hash_row.fetch(:device))
  end

  private

  # Fixture loading resets the clients id sequence, so a new Client can reuse an id that a
  # non-transactional test already wrote committed chronicle rows for. Those rows are not this
  # client's history; the test transaction restores them afterwards.
  def fresh_client
    Client.create!.tap { |client| ClientChronicle.where(subject_type: "Client", subject_id: client.id).delete_all }
  end
end
