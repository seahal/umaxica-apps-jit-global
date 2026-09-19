# typed: false
# frozen_string_literal: true

require "test_helper"

class EditPublishingExplicitRoutesTest < ActiveSupport::TestCase
  test "edit publishing routes are declared without generation loops" do
    source = Rails.root.join("config/routes/edit.rb").read

    assert_no_match(/\.each\b/, source)
    assert_includes source, "Twelve explicit surface/audience cells"

    %w(info docs news help).each do |surface|
      %w(app com org).each do |audience|
        assert_match(
          /resource :#{surface}, only: \[\], module: :#{surface}/,
          source,
        )
        assert_match(
          /resource :#{audience}, only: \[\], module: :#{audience}/,
          source,
        )
      end
    end
  end
end
