# typed: false
# frozen_string_literal: true

require "test_helper"

class SelectedActorContextTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_statuses client_visibilities)

  test "selected_actor_context? requires every account collective and unit identifier" do
    token = ClientToken.new

    assert_not_predicate token, :selected_actor_context?
    token.selected_account_public_id = "account"
    token.selected_collective_public_id = "collective"

    assert_not_predicate token, :selected_actor_context?
    token.selected_collective_unit_public_id = "unit"

    assert_predicate token, :selected_actor_context?
    token.selected_collective_unit_public_id = ""

    assert_not_predicate token, :selected_actor_context?
  end

  test "clear_selected_actor_context! clears the real persisted selection and freshness" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    token = ClientToken.create!(
      user: actor, selected_account_public_id: "account", selected_collective_public_id: "collective",
      selected_collective_unit_public_id: "unit", selected_avatar_public_id: "avatar", selected_at: Time.current,
      last_step_up_at: Time.current, last_step_up_scope: "settings_birthdate",
    )

    token.clear_selected_actor_context!
    token.reload

    assert_nil token.selected_account_public_id
    assert_nil token.selected_collective_public_id
    assert_nil token.selected_collective_unit_public_id
    assert_nil token.selected_avatar_public_id
    assert_nil token.selected_at
    assert_nil token.last_step_up_at
    assert_predicate token, :currently_usable?
  end
end
