# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SessionLimitHardRejectTest < ActionDispatch::IntegrationTest
  fixtures :clients

  class TestController < ApplicationController
    include AuthenticationClient

    declare_authentication_mode! :open

    def create
      user = Client.find(params[:user_id])
      result = log_in(user, require_totp_check: false)

      if result[:status] == :session_limit_hard_reject
        respond_to do |format|
          format.html { render plain: result[:message], status: result[:http_status] }
          format.json {
            render json: { error: result[:message], error_code: "session_limit_hard_reject" },
                   status: result[:http_status]
          }
        end
      else
        render json: { status: "ok" }, status: :ok
      end
    end
  end

  setup do
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    @user = clients(:one)
    ClientToken.where(user_id: @user.id).delete_all
    Prosopite.pause do
      2.times do
        token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
        token.rotate_refresh_token!
      end
      restricted = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
      restricted.rotate_refresh_token!(discard_at: 15.minutes.from_now)
    end

    Rails.application.routes.draw do
      post "/test/hard_reject_login" => "session_limit_hard_reject_test/test#create"
    end
  end

  teardown do
    self.login_cooldown = @original_login_cooldown
    Rails.application.reload_routes!
  end

  test "hard reject returns 403 for html and does not create new token" do
    before_count = ClientToken.where(user_id: @user.id).count

    post "/test/hard_reject_login", params: { user_id: @user.id }

    assert_response :forbidden
    assert_equal AuthenticationBase::SESSION_LIMIT_HARD_REJECT_MESSAGE, response.body
    assert_equal before_count, ClientToken.where(user_id: @user.id).count
  end

  test "hard reject returns 403 for json and does not create new token" do
    before_count = ClientToken.where(user_id: @user.id).count

    post "/test/hard_reject_login",
         params: { user_id: @user.id },
         as: :json

    assert_response :forbidden
    assert_equal "session_limit_hard_reject", response.parsed_body["error_code"]
    assert_equal before_count, ClientToken.where(user_id: @user.id).count
  end
end
