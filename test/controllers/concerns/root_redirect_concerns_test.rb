# frozen_string_literal: true

require "test_helper"

class RootRedirectConcernsTest < ActiveSupport::TestCase
  test "RegionalRootRedirect rejects an unknown surface" do
    klass =
      Class.new(ApplicationController) do
        include RegionalRootRedirect
      end

    assert_raises(ArgumentError) { klass.redirect_root_to_regional_host(surface: :nope) }
  end

  test "RootSignInRedirect requires a path builder block" do
    klass =
      Class.new(ApplicationController) do
        include RootSignInRedirect
      end

    assert_raises(ArgumentError) { klass.redirect_root_to_sign_in }
  end
end
