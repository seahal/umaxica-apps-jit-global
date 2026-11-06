# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../../support/rp_cell_session_helper"

class Base::App::Identity::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  include RpCellSessionHelper

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    https!
    @actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @token = ClientToken.create!(
      authentication_epoch: 0,
      user: @actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    sign_in_rp_cell("base-app-ww", actor: @actor, root_token: @token)
  end

  test "APP local contact registration refuses every write and continuation with no side effects" do
    before = [
      ClientEmail.count,
      ClientEmailCeremonyTransaction.count,
      enqueued_jobs.size,
    ]

    get new_base_app_identity_emails_registration_path(ri: "jp")

    assert_response :service_unavailable

    get edit_base_app_identity_emails_registration_path(ri: "jp")

    assert_response :service_unavailable

    post base_app_identity_emails_registration_path(ri: "jp"),
         params: { user_email: { raw_address: "new-contact@example.test" } }

    assert_response :service_unavailable

    patch base_app_identity_emails_registration_path(ri: "jp"),
          params: { user_email: { pass_code: "123456" } }

    assert_response :service_unavailable

    post base_app_identity_emails_registration_redelivery_path(ri: "jp")

    assert_response :service_unavailable

    assert_equal before, [ClientEmail.count, ClientEmailCeremonyTransaction.count, enqueued_jobs.size]
  end
end
