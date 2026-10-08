# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::SignInBoundaryTest < ActiveSupport::TestCase
  test "sign-in controllers do not directly issue login tokens or cookies" do
    prohibited = [
      /ClientToken\.create/,
      /ClientDeviceSession\.create/,
      /create!.*ClientToken/,
      /create!.*ClientDeviceSession/,
      /cookies\[[^\]]*auth/,
      /auth_access/,
      /auth_refresh/,
      /bootstrap_actor:\s*true/,
      /establish_signed_in_session!/,
    ]

    paths = Dir.glob("app/controllers/auth/app/{sign/in,social,omniauth}/**/*_controller.rb")

    assert_operator paths.size, :>=, 10, "the sign-in controller set went missing"

    matches =
      paths.flat_map do |path|
        text = File.read(path)
        prohibited.filter_map { |pattern| "#{path}:#{pattern.source}" if text.match?(pattern) }
      end

    assert_empty matches
  end

  test "step-up controllers do not call the shared sign-in completion gate" do
    prohibited = [
      /establish_signed_in_session!/,
      /ClientToken\.create/,
      /ClientDeviceSession\.create/,
      /create!.*ClientToken/,
      /create!.*ClientDeviceSession/,
      /bootstrap_actor:\s*true/,
    ]

    paths = Dir.glob("app/controllers/auth/app/verification/**/*_controller.rb")

    assert_operator paths.size, :>=, 6, "the step-up controller set went missing"

    matches =
      paths.flat_map do |path|
        text = File.read(path)
        prohibited.filter_map { |pattern| "#{path}:#{pattern.source}" if text.match?(pattern) }
      end

    assert_empty matches
  end
end
