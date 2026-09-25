# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpAdapterTest < ActiveSupport::TestCase
  test "for returns OtpEmailAdapter with App mailer for app/email" do
    adapter = OtpAdapter.for(surface: :app, channel: :email)

    assert_instance_of OtpEmailAdapter, adapter
    assert_same Email::App::OtpMailer, adapter.instance_variable_get(:@mailer)
  end

  test "for returns OtpEmailAdapter with Com mailer for com/email" do
    adapter = OtpAdapter.for(surface: :com, channel: :email)

    assert_instance_of OtpEmailAdapter, adapter
    assert_same Email::Com::OtpMailer, adapter.instance_variable_get(:@mailer)
  end

  test "for returns OtpEmailAdapter with Org mailer for org/email" do
    adapter = OtpAdapter.for(surface: :org, channel: :email)

    assert_instance_of OtpEmailAdapter, adapter
    assert_same Email::Org::OtpMailer, adapter.instance_variable_get(:@mailer)
  end

  test "for returns OtpTelephoneAdapter for app/telephone" do
    adapter = OtpAdapter.for(surface: :app, channel: :telephone)

    assert_instance_of OtpTelephoneAdapter, adapter
  end

  test "for returns OtpTelephoneAdapter for com/telephone" do
    adapter = OtpAdapter.for(surface: :com, channel: :telephone)

    assert_instance_of OtpTelephoneAdapter, adapter
  end

  test "for returns OtpTelephoneAdapter for org/telephone" do
    adapter = OtpAdapter.for(surface: :org, channel: :telephone)

    assert_instance_of OtpTelephoneAdapter, adapter
  end

  test "for accepts string surface and channel" do
    adapter = OtpAdapter.for(surface: "app", channel: "email")

    assert_instance_of OtpEmailAdapter, adapter
  end

  test "for raises ArgumentError for unknown combination" do
    assert_raises(ArgumentError) { OtpAdapter.for(surface: :warp, channel: :email) }
  end

  test "base deliver raises NotImplementedError" do
    assert_raises(NotImplementedError) { OtpAdapter.new.deliver }
  end

  # The tests above are the proof that the rollout flag is inert by default: they
  # were written before the flag existed and still pass unchanged.
  test "for returns the notifier adapter once the surface rollout is enabled" do
    Flipper.enable(:otp_email_notifier_app)

    adapter = OtpAdapter.for(surface: :app, channel: :email)

    assert_instance_of OtpEmailNotifierAdapter, adapter
    assert_same Notify::App::OtpNotifier, adapter.instance_variable_get(:@notifier)
    assert_instance_of OtpEmailAdapter, OtpAdapter.for(surface: :com, channel: :email)
    assert_instance_of OtpEmailAdapter, OtpAdapter.for(surface: :org, channel: :email)
  ensure
    Flipper.disable(:otp_email_notifier_app)
  end

  test "for leaves telephone delivery on the telephone adapter regardless of the email rollout" do
    OtpEmailNotifierRollout::SURFACE_FEATURE_NAMES.each_value { |feature| Flipper.enable(feature) }

    %i(app com org).each do |surface|
      assert_instance_of OtpTelephoneAdapter, OtpAdapter.for(surface: surface, channel: :telephone)
    end
  ensure
    OtpEmailNotifierRollout::SURFACE_FEATURE_NAMES.each_value { |feature| Flipper.disable(feature) }
  end
end
