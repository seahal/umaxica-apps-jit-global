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

  test "RegionalRootRedirect skips non-GET requests and unresolved regional urls" do
    host = Object.new
    host.extend(RegionalRootRedirect)
    host.define_singleton_method(:regional_root_redirect_surface) { :app }

    non_get = Object.new
    non_get.define_singleton_method(:get?) { false }
    non_get.define_singleton_method(:head?) { false }
    host.define_singleton_method(:request) { non_get }
    host.define_singleton_method(:params) { { ri: "jp" } }

    assert_nil host.send(:redirect_to_regional_root)

    get_request = Object.new
    get_request.define_singleton_method(:get?) { true }
    get_request.define_singleton_method(:head?) { false }
    host.define_singleton_method(:request) { get_request }

    RegionalRootUrlRegistry.stub(:url_for, nil) do
      assert_nil host.send(:redirect_to_regional_root)
    end
  end

  test "RootSignInRedirect skips non-GET requests and unrecognized regions" do
    host = Object.new
    host.extend(RootSignInRedirect)
    host.define_singleton_method(:root_sign_in_redirect_path) { |_region| "/sign/in" }

    non_get = Object.new
    non_get.define_singleton_method(:get?) { false }
    non_get.define_singleton_method(:head?) { false }
    host.define_singleton_method(:request) { non_get }
    host.define_singleton_method(:params) { { ri: "jp" } }

    assert_nil host.send(:redirect_root_to_sign_in)

    get_request = Object.new
    get_request.define_singleton_method(:get?) { true }
    get_request.define_singleton_method(:head?) { false }
    host.define_singleton_method(:request) { get_request }
    host.define_singleton_method(:params) { { ri: "not-a-region" } }

    assert_nil host.send(:redirect_root_to_sign_in)
  end
end
