# frozen_string_literal: true

require "test_helper"

class AuthEntryIntentResolverTest < ActiveSupport::TestCase
  test "persisted prompt selects exactly one ordinary intent" do
    { nil => "sign_in",
      "" => "sign_in",
      "login" => "sign_in",
      "none" => "sign_in",
      "create" => "sign_up", }.each do |prompt, intent|
      assert_equal intent, AuthEntryIntentResolver.call(prompt: prompt, entry_intent: nil)
    end
  end

  test "a persisted Switch selection takes precedence over the original prompt" do
    %w(sign_in sign_up).each do |intent|
      [nil, "login", "none", "create"].each do |prompt|
        assert_equal intent, AuthEntryIntentResolver.call(prompt: prompt, entry_intent: intent)
      end
    end
  end

  test "an invalid persisted intent fails rather than inferring a replacement" do
    ["", "not_applicable", "invitation", "authentication"].each do |intent|
      assert_raises(ArgumentError) { AuthEntryIntentResolver.call(prompt: "create", entry_intent: intent) }
    end
  end

  test "an unsupported prompt without a Switch intent fails explicitly" do
    %w(consent select_account unsupported).each do |prompt|
      assert_raises(ArgumentError) { AuthEntryIntentResolver.call(prompt: prompt, entry_intent: nil) }
    end
    assert_raises(ArgumentError) { AuthEntryIntentResolver.call(prompt: "login create", entry_intent: nil) }
  end
end
