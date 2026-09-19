# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseIdentityActivityLogPresenterTest < ActiveSupport::TestCase
  ActivityRecord = Struct.new(:event_id, :context, :ip_address, :occurred_at, :created_at, keyword_init: true)

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
    assert_raises(ArgumentError) { Base::Identity::ActivityLogPresenter.new(surface: :side) }
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
end
