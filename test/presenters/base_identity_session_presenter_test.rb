# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseIdentitySessionPresenterTest < ActiveSupport::TestCase
  test "session presentation omits token internals and uses discarded_at as expiry" do
    session = Struct.new(
      :last_used_at, :created_at, :discarded_at, :public_id, :refresh_token_family_id,
      :authentication_context_value, keyword_init: true,
    ).new(
      last_used_at: Time.utc(2026, 9, 13, 9, 0),
      created_at: Time.utc(2026, 9, 13, 8, 0),
      discarded_at: Time.utc(2026, 9, 14, 8, 0),
      public_id: "tok_internal_public",
      refresh_token_family_id: "family-secret",
      authentication_context_value: Struct.new(:emergency?, :normal?).new(false, true),
    )
    row = Base::Identity::SessionPresenter.new.present(session, current: true, surface: :app)

    assert_equal %i(device last_activity created expires_at status), row.keys
    assert_not_includes row.values.join(" "), "tok_internal_public"
    assert_not_includes row.values.join(" "), "family-secret"
    assert_equal I18n.t("base.shared.identity.sessions.current_session"), row.fetch(:status)
  end

  test "org presentation takes emergency from authentication context not DBSC" do
    session = Struct.new(
      :last_used_at, :created_at, :discarded_at, :authentication_context_value, keyword_init: true,
    ).new(
      last_used_at: Time.utc(2026, 9, 13, 9, 0),
      created_at: Time.utc(2026, 9, 13, 8, 0),
      discarded_at: Time.utc(2026, 9, 14, 8, 0),
      authentication_context_value: Struct.new(:emergency?, :normal?).new(true, false),
    )
    row = Base::Identity::SessionPresenter.new.present(session, current: false, surface: :org)

    assert_equal I18n.t("base.shared.identity.sessions.emergency"), row.fetch(:mode)
  end
end
