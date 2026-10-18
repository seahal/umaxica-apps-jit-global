# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthRedirectTestController < ApplicationController
  include AuthenticationBase

  declare_authentication_mode! :open

  def trigger_redirect_with_notice
    session[AuthenticationBase::DEFAULT_PT_SESSION_KEY] = signed_pt_token(params[:pt]) if params[:pt].present?
    redirect_with_notice("/default_path", "This is a notice")
  end

  def trigger_redirect_with_alert
    session[AuthenticationBase::DEFAULT_PT_SESSION_KEY] = signed_pt_token(params[:pt]) if params[:pt].present?
    redirect_with_alert("/default_path", "This is an alert")
  end

  def trigger_add_rt_to_params
    session[AuthenticationBase::DEFAULT_PT_SESSION_KEY] = signed_pt_token(params[:pt]) if params[:pt].present?
    redirect_params = { action: "index" }
    add_pt_to_params!(redirect_params)
    render json: redirect_params
  end

  def trigger_safe_rt
    render plain: path_from_signed_pt(params[:pt]) || ""
  end

  def trigger_issue_bulletin
    if issue_bulletin!(kind: "test_kind", state: "test_state")
      render plain: "issued"
    else
      render plain: "not_issued"
    end
  end

  def am_i_user?
    false
  end

  def am_i_staff?
    false
  end

  def am_i_owner?
    false
  end

  def resource_type
    "Client"
  end

  def resource_class
    Client
  end

  def token_class
    ClientToken
  end

  def current_region_identifier
    "jp"
  end
end

class AuthRedirectBoosterTest < ActionDispatch::IntegrationTest
  setup do
    @routes = Rails.application.routes
    Rails.application.routes.draw do
      get "/auth_redirect/notice" => "auth_redirect_test#trigger_redirect_with_notice"
      get "/auth_redirect/alert" => "auth_redirect_test#trigger_redirect_with_alert"
      get "/auth_redirect/params" => "auth_redirect_test#trigger_add_rt_to_params"
      get "/auth_redirect/safe_rt" => "auth_redirect_test#trigger_safe_rt"
      get "/auth_redirect/bulletin" => "auth_redirect_test#trigger_issue_bulletin"
      get "/auth_redirect/index" => "auth_redirect_test#trigger_redirect_with_notice" # dummy destination
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "redirect_with_notice without pt" do
    get "/auth_redirect/notice"

    assert_redirected_to "/default_path"
    assert_empty flash
  end

  test "redirect_with_notice with pt" do
    pt = "/settings?x=1"
    get "/auth_redirect/notice", params: { pt: pt }

    assert_redirected_to "/settings?x=1"
    assert_empty flash
  end

  test "redirect_with_alert without pt" do
    get "/auth_redirect/alert"

    assert_redirected_to "/default_path"
    assert_empty flash
  end

  test "add_rt_to_params" do
    pt = "/dashboard"
    get "/auth_redirect/params", params: { pt: pt }

    assert_response :success
    assert_match(/--/, response.parsed_body["pt"])
  end

  test "path_from_signed_pt rejects raw internal path" do
    pt = "/settings?x=1"
    get "/auth_redirect/safe_rt", params: { pt: pt }

    assert_response :success
    assert_equal "", response.body
  end

  test "path_from_signed_pt rejects unencoded external URL" do
    get "/auth_redirect/safe_rt", params: { pt: "https://evil.example/path" }

    assert_response :success
    assert_equal "", response.body
  end

  test "issue_bulletin returns false when no bulletin" do
    get "/auth_redirect/bulletin"

    assert_equal "not_issued", response.body
  end
end
