# frozen_string_literal: true

require_relative "../../../config/environment"
require "minitest/autorun"
require "minitest/mock"

class DynamicMethodContractsTest < ActiveSupport::TestCase
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
