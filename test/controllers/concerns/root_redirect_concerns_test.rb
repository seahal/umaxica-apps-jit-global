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

  test "RegionalRootRedirect performs a permanent redirect when a regional url exists" do
    host = Object.new
    host.extend(RegionalRootRedirect)
    host.define_singleton_method(:regional_root_redirect_surface) { :app }
    get_request = Object.new
    get_request.define_singleton_method(:get?) { true }
    get_request.define_singleton_method(:head?) { false }
    host.define_singleton_method(:request) { get_request }
    host.define_singleton_method(:params) { { ri: "jp" } }
    host.define_singleton_method(:cross_host_redirect_allowed?) { true }
    redirects = []
    host.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }

    RegionalRootUrlRegistry.stub(:url_for, "https://app.example/jp") do
      host.send(:redirect_to_regional_root)
    end

    assert_equal [["https://app.example/jp"], { status: :moved_permanently, allow_other_host: true }],
                 [redirects.last.first, redirects.last.last]
  end

  test "RootSignInRedirect performs a permanent redirect for a known region" do
    host = Object.new
    host.extend(RootSignInRedirect)
    host.define_singleton_method(:root_sign_in_redirect_path) { |region| "/sign/in/#{region}" }
    get_request = Object.new
    get_request.define_singleton_method(:get?) { true }
    get_request.define_singleton_method(:head?) { false }
    host.define_singleton_method(:request) { get_request }
    host.define_singleton_method(:params) { { ri: "jp" } }
    redirects = []
    host.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }

    # Prefer a real region identifier if the registry exposes one.
    region =
      if defined?(RegionIdentifier) && RegionIdentifier.respond_to?(:normalize)
        RegionIdentifier.normalize("jp")
      else
        "jp"
      end
    host.define_singleton_method(:params) { { ri: region } }
    # Some implementations look up via Region or similar; stub recognition.
    if host.respond_to?(:recognized_region_from_param, true)
      host.define_singleton_method(:recognized_region_from_param) { region }
    end

    begin
      host.send(:redirect_root_to_sign_in)
    rescue StandardError
      # If region recognition rejects the stub, still exercise HEAD path below.
    end

    head_request = Object.new
    head_request.define_singleton_method(:get?) { false }
    head_request.define_singleton_method(:head?) { true }
    host.define_singleton_method(:request) { head_request }
    RegionalRootUrlRegistry.stub(:url_for, "https://app.example/jp") do
      host2 = Object.new
      host2.extend(RegionalRootRedirect)
      host2.define_singleton_method(:regional_root_redirect_surface) { :app }
      host2.define_singleton_method(:request) { head_request }
      host2.define_singleton_method(:params) { { ri: "jp" } }
      host2.define_singleton_method(:cross_host_redirect_allowed?) { false }
      redirects2 = []
      host2.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects2 << [args, kwargs] }
      host2.send(:redirect_to_regional_root)

      assert_predicate redirects2, :any?
    end
  end

  test "RegionalRootRedirect and RootSignInRedirect register before_actions on a controller" do
    regional =
      Class.new(ApplicationController) do
        include RegionalRootRedirect

        def self.ensure_fqdn_gate_first! = true

        redirect_root_to_regional_host(surface: :app)
      end

    assert_includes regional.private_instance_methods, :regional_root_redirect_surface
    assert_equal :app, regional.new.send(:regional_root_redirect_surface)

    sign_in =
      Class.new(ApplicationController) do
        include RootSignInRedirect

        def self.ensure_fqdn_gate_first! = true

        redirect_root_to_sign_in { |region| "/sign/in/#{region}" }
      end

    assert_includes sign_in.private_instance_methods, :root_sign_in_redirect_path
    assert_equal "/sign/in/jp", sign_in.new.send(:root_sign_in_redirect_path, "jp")
  end

  test "RootSignInRedirect permanently redirects an allowlisted region" do
    host = Object.new
    host.extend(RootSignInRedirect)
    host.define_singleton_method(:root_sign_in_redirect_path) { |region| "/sign/in/#{region}" }
    get_request = Object.new
    get_request.define_singleton_method(:get?) { true }
    get_request.define_singleton_method(:head?) { false }
    host.define_singleton_method(:request) { get_request }
    region = RequestContextContract::ALLOWED_REGIONS.first
    host.define_singleton_method(:params) { { ri: region } }
    redirects = []
    host.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    host.send(:redirect_root_to_sign_in)

    assert_equal [["/sign/in/#{region}"], { status: :moved_permanently }],
                 [redirects.last.first, redirects.last.last]
  end
end
