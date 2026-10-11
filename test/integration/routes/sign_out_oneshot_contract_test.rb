# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOutOneshotContractTest < ActionDispatch::IntegrationTest
  test "/sign/out/complete is unroutable and completions controllers are gone" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/sign/out/complete", method: :get)
    end

    %w(Auth Core Side).each do |surface|
      %w(App Com Org).each do |face|
        assert_not Object.const_defined?("#{surface}::#{face}::Sign::Outs::CompletionsController")
      end
    end

    assert_equal 5.minutes, Valkey::AuthState::SignOutNoticeStore::TTL
  end
end
