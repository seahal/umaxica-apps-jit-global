# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpAdapterTest < ActiveSupport::TestCase
  test "for returns the Noticed adapter for app email" do
    adapter = OtpAdapter.for(surface: :app, channel: :email)

    assert_instance_of OtpEmailNotifierAdapter, adapter
  end

  test "for returns the Noticed adapter for com email" do
    adapter = OtpAdapter.for(surface: :com, channel: :email)

    assert_instance_of OtpEmailNotifierAdapter, adapter
  end

  test "for returns the Noticed adapter for org email" do
    adapter = OtpAdapter.for(surface: :org, channel: :email)

    assert_instance_of OtpEmailNotifierAdapter, adapter
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

    assert_instance_of OtpEmailNotifierAdapter, adapter
  end

  test "for raises ArgumentError for unknown combination" do
    assert_raises(ArgumentError) { OtpAdapter.for(surface: :warp, channel: :email) }
  end

  test "base deliver raises NotImplementedError" do
    assert_raises(NotImplementedError) { OtpAdapter.new.deliver }
  end

  test "for keeps telephone delivery on the telephone adapter" do
    %i(app com org).each do |surface|
      assert_instance_of OtpTelephoneAdapter, OtpAdapter.for(surface: surface, channel: :telephone)
    end
  end
end
