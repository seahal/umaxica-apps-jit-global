# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceDbscRegistrationEndpointTestController < ApplicationController
  class PreferenceRecord
    attr_accessor :dbsc_session_id, :dbsc_challenge, :dbsc_challenge_issued_at

    def update!(attrs)
      attrs.each { |key, value| public_send("#{key}=", value) }
    end
  end

  def self.dbsc_test_preference_record
    @dbsc_test_preference_record
  end

  def self.dbsc_test_preference_record=(value)
    @dbsc_test_preference_record = value
  end

  include PreferenceDbscRegistrationEndpoint

  private

  def current_preference_record
    self.class.dbsc_test_preference_record
  end

  def dbsc_url
    "http://www.example.com/test/dbsc"
  end

  def set_preference_dbsc_cookie!(*)
  end

  def preference_dbsc_cookie_expires_at(_preference)
    15.minutes.from_now
  end

  def issue_preference_dbsc_challenge_for!(preference)
    preference.dbsc_challenge = "challenge-token"
    preference.dbsc_challenge_issued_at = Time.current
    preference.dbsc_challenge
  end
end

class PreferenceDbscRegistrationEndpointTest < ActionDispatch::IntegrationTest
  setup do
    PreferenceDbscRegistrationEndpointTestController.dbsc_test_preference_record = nil

    Rails.application.routes.draw do
      post "/test/preference_dbsc" => "preference_dbsc_registration_endpoint_test#create"
    end
  end

  teardown do
    PreferenceDbscRegistrationEndpointTestController.dbsc_test_preference_record = nil
    Rails.application.reload_routes!
  end

  test "create handles registration success" do
    preference = PreferenceDbscRegistrationEndpointTestController::PreferenceRecord.new
    PreferenceDbscRegistrationEndpointTestController.dbsc_test_preference_record = preference

    result = {
      ok: true,
      record: preference,
      session_id: "session-123",
      error_code: nil,
    }

    DbscRegistrationService.stub(:call, result) do
      post "/test/preference_dbsc", headers: { PreferenceIoKeys::Headers::DBSC_RESPONSE => %q("proof") }
    end

    assert_response :created
    assert_equal "no-store", response.headers["Cache-Control"]

    json = response.parsed_body

    assert_equal "session-123", json["session_identifier"]
    assert_equal "http://www.example.com/test/dbsc", json["refresh_url"]
    assert_equal "http://www.example.com", json["scope"]["origin"]
    assert_not json["scope"]["include_site"]
    assert_equal PreferenceCookieName.dbsc, json["credentials"].first["name"]
  end

  test "create handles registration failure" do
    preference = PreferenceDbscRegistrationEndpointTestController::PreferenceRecord.new
    PreferenceDbscRegistrationEndpointTestController.dbsc_test_preference_record = preference

    result = {
      ok: false,
      error_code: "bad_proof",
    }

    DbscRegistrationService.stub(:call, result) do
      post "/test/preference_dbsc", headers: { PreferenceIoKeys::Headers::DBSC_RESPONSE => %q("proof") }
    end

    assert_response :unprocessable_content
    assert_equal "DBSC registration failed", response.parsed_body["error"]
    assert_equal "bad_proof", response.parsed_body["error_code"]
  end

  test "create rejects bound cookie refresh when preference record is missing" do
    post "/test/preference_dbsc",
         headers: { PreferenceIoKeys::Headers::DBSC_SESSION_ID => %q("session-123") }

    assert_response :unauthorized
  end

  test "create issues a challenge when bound cookie refresh has no proof" do
    preference = PreferenceDbscRegistrationEndpointTestController::PreferenceRecord.new
    preference.dbsc_session_id = "session-123"
    PreferenceDbscRegistrationEndpointTestController.dbsc_test_preference_record = preference

    post "/test/preference_dbsc",
         headers: { PreferenceIoKeys::Headers::DBSC_SESSION_ID => %q("session-123") }

    assert_response :forbidden
    assert_equal "\"challenge-token\";id=\"session-123\"",
                 response.headers[PreferenceIoKeys::Headers::DBSC_CHALLENGE]
  end

  test "create returns error when bound cookie verification fails" do
    preference = PreferenceDbscRegistrationEndpointTestController::PreferenceRecord.new
    preference.dbsc_session_id = "session-123"
    preference.dbsc_challenge = "challenge-token"
    preference.dbsc_challenge_issued_at = Time.current
    PreferenceDbscRegistrationEndpointTestController.dbsc_test_preference_record = preference

    result = {
      ok: false,
      error_code: "verification_failed",
    }

    DbscVerificationService.stub(:call, result) do
      post "/test/preference_dbsc",
           headers: {
             PreferenceIoKeys::Headers::DBSC_SESSION_ID => %q("session-123"),
             PreferenceIoKeys::Headers::DBSC_RESPONSE => %q("proof"),
           }
    end

    assert_response :unprocessable_content
    assert_equal "DBSC verification failed", response.parsed_body["error"]
    assert_equal "verification_failed", response.parsed_body["error_code"]
  end

  test "create clears challenge and returns no content when bound cookie verification succeeds" do
    preference = PreferenceDbscRegistrationEndpointTestController::PreferenceRecord.new
    preference.dbsc_session_id = "session-123"
    preference.dbsc_challenge = "challenge-token"
    preference.dbsc_challenge_issued_at = Time.current
    PreferenceDbscRegistrationEndpointTestController.dbsc_test_preference_record = preference

    result = {
      ok: true,
      error_code: nil,
    }

    DbscVerificationService.stub(:call, result) do
      post "/test/preference_dbsc",
           headers: {
             PreferenceIoKeys::Headers::DBSC_SESSION_ID => %q("session-123"),
             PreferenceIoKeys::Headers::DBSC_RESPONSE => %q("proof"),
           }
    end

    assert_response :no_content
    assert_nil preference.dbsc_challenge
    assert_nil preference.dbsc_challenge_issued_at
  end
end
