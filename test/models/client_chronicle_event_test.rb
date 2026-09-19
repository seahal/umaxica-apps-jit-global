# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientChronicleEventTest < ActiveSupport::TestCase
  setup do
    @model_class = ClientChronicleEvent
    @valid_id = ClientChronicleEvent::LOGGED_IN
    @subject = @model_class.new(id: @valid_id)
  end

  test "accepts integer ids" do
    record = ClientChronicleEvent.new(id: 9)

    assert_predicate record, :valid?
  end

  test "constants are grouped and defined" do
    assert_equal [
      ClientChronicleEvent::ACCOUNT_RECOVERED,
      ClientChronicleEvent::ACCOUNT_WITHDRAWN,
      ClientChronicleEvent::AUTHORIZATION_FAILED,
      ClientChronicleEvent::LOGGED_IN,
      ClientChronicleEvent::LOGGED_OUT,
      ClientChronicleEvent::LOGIN_FAILED,
      ClientChronicleEvent::LOGIN_SUCCESS,
      ClientChronicleEvent::LOGOUT,
      ClientChronicleEvent::NOTHING,
      ClientChronicleEvent::NON_EXISTENT_EVENT,
      ClientChronicleEvent::PASSKEY_REGISTERED,
      ClientChronicleEvent::PASSKEY_REMOVED,
      ClientChronicleEvent::RECOVERY_CODES_GENERATED,
      ClientChronicleEvent::RECOVERY_CODE_USED,
      ClientChronicleEvent::SIGNED_UP_WITH_APPLE,
      ClientChronicleEvent::SIGNED_UP_WITH_EMAIL,
      ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE,
      ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE,
      ClientChronicleEvent::TOKEN_REFRESHED,
      ClientChronicleEvent::TOTP_DISABLED,
      ClientChronicleEvent::TOTP_ENABLED,
      ClientChronicleEvent::USER_SECRET_CREATED,
      ClientChronicleEvent::USER_SECRET_REMOVED,
      ClientChronicleEvent::USER_SECRET_UPDATED,
      ClientChronicleEvent::EMAIL_REMOVED,
      ClientChronicleEvent::TELEPHONE_REMOVED,
      ClientChronicleEvent::SOCIAL_UNLINKED,
      ClientChronicleEvent::STEP_UP_VERIFIED,
      ClientChronicleEvent::SESSION_REVOKED,
      ClientChronicleEvent::SOCIAL_LINKED,
      ClientChronicleEvent::EMAIL_REGISTERED,
      ClientChronicleEvent::TELEPHONE_REGISTERED,
      ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION,
      ClientChronicleEvent::STEP_UP_FAILED,
      ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
    ], ClientChronicleEvent::DEFAULTS.sort
  end

  test "record_timestamps is disabled" do
    assert_not ClientChronicleEvent.record_timestamps
  end

  test "DEFAULTS array contains all event IDs" do
    assert_kind_of Array, ClientChronicleEvent::DEFAULTS
    assert_equal 35, ClientChronicleEvent::DEFAULTS.size
    assert_includes ClientChronicleEvent::DEFAULTS, ClientChronicleEvent::LOGGED_IN
    assert_includes ClientChronicleEvent::DEFAULTS, ClientChronicleEvent::LOGIN_SUCCESS
    assert_includes ClientChronicleEvent::DEFAULTS, ClientChronicleEvent::TOKEN_REFRESHED
    assert_includes ClientChronicleEvent::DEFAULTS, ClientChronicleEvent::STEP_UP_FAILED
    assert_includes ClientChronicleEvent::DEFAULTS, ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED
  end

  test "ensure_defaults! creates records" do
    ClientChronicle.delete_all
    ClientChronicleEvent.delete_all
    assert_difference("ClientChronicleEvent.count", 35) do
      ClientChronicleEvent.ensure_defaults!
    end
    assert ClientChronicleEvent.exists?(id: ClientChronicleEvent::LOGGED_IN)
  end

  test "returns all default records" do
    ClientChronicleEvent.ensure_defaults!
    ids = ClientChronicleEvent.pluck(:id)

    assert_empty(ClientChronicleEvent::DEFAULTS - ids)
  end

  test "has_many association with client_chronicles" do
    association = ClientChronicleEvent.reflect_on_association(:client_chronicles)

    assert_equal :has_many, association.macro
    assert_equal :restrict_with_error, association.options[:dependent]
    assert_equal :event_id, association.options[:foreign_key]
  end
end
