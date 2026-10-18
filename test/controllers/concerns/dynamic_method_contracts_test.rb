# frozen_string_literal: true

require_relative "../../../config/environment"
require "minitest/autorun"
require "minitest/mock"

class DynamicMethodContractsTest < ActiveSupport::TestCase
  module Target
    def sign_com_characterization_path(*args, **kwargs, &block)
      [args, kwargs, block&.call(:forwarded)]
    end
  end

  def test_route_aliases_forward_arguments_keywords_and_blocks_for_include_and_extend
    helpers = Rails.application.routes.url_helpers
    names = %i(sign_app_characterization_path sign_com_characterization_path)
    helpers.stub(:public_instance_methods, names) do
      helpers.stub(:public_method_defined?, ->(name) { names.include?(name) }) do
        included =
          Class.new {
            include Target
            include SignComRouteAliasHelper
          }
        extended = Module.new { include Target }
        extended.extend(SignComRouteAliasHelper)
        consumer = Class.new { include extended }
        object = Object.new.extend(Target).extend(SignComRouteAliasHelper)

        [included.new, Class.new(included).new, consumer.new, object].each do |receiver|
          assert_respond_to receiver, :sign_app_characterization_path
          assert_includes receiver.public_methods, :sign_app_characterization_path
          assert_equal [[42], { ri: "jp" }, :forwarded],
                       receiver.sign_app_characterization_path(42, ri: "jp") { |value| value }
          assert_equal [[:rest, :args], [:keyrest, :kwargs], [:block, :block]],
                       receiver.method(:sign_app_characterization_path).parameters
        end
        assert_not extended.respond_to?(:sign_app_characterization_path)
      end
    end
  end

  def test_missing_target_at_inclusion_does_not_define_an_alias_and_later_routes_do_not_backfill_it
    helpers = Rails.application.routes.url_helpers
    consumer = nil
    helpers.stub(:public_instance_methods, [:acme_app_characterization_url]) do
      helpers.stub(:public_method_defined?, false) do
        consumer = Class.new { include SignComRouteAliasHelper }
      end
    end

    assert_not consumer.new.respond_to?(:acme_app_characterization_url, true)
    assert_raises(NameError) { consumer.new.method(:acme_app_characterization_url) }
  end

  def test_existing_alias_with_no_receiver_target_raises_no_method_error
    helpers = Rails.application.routes.url_helpers
    names = %i(sign_app_characterization_path sign_com_characterization_path)
    helpers.stub(:public_instance_methods, names) do
      helpers.stub(:public_method_defined?, ->(name) { names.include?(name) }) do
        receiver = Object.new.extend(SignComRouteAliasHelper)

        assert_respond_to receiver, :sign_app_characterization_path
        assert_raises(NoMethodError) { receiver.sign_app_characterization_path }
      end
    end
  end

  def test_sign_out_prefix_is_private_and_captured_on_the_including_class
    parent =
      Class.new(ApplicationController) do
        def self.controller_path = "characterization/sign/outs"
        include SignOutInertiaPages
      end
    child =
      Class.new(parent) do
        def self.controller_path = "characterization/sign/out/completions"
      end

    [parent, child].each do |controller|
      receiver = controller.new

      assert_equal [false, true],
                   [receiver.respond_to?(:sign_out_page_prefix), receiver.respond_to?(:sign_out_page_prefix, true)]
      assert_equal parent, receiver.method(:sign_out_page_prefix).owner
      assert_empty receiver.method(:sign_out_page_prefix).parameters
      # The requested include-time capture contract is private; inspect it directly without widening production visibility.
      assert_equal "characterization/sign/outs", receiver.method(:sign_out_page_prefix).call
    end
  end
end
