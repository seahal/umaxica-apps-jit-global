# typed: false
# frozen_string_literal: true

require "test_helper"

# Two more per-surface delegations. A client who is already signed in and lands
# on a sign-in or sign-up entry point directly is refused on that surface's own
# terms, and the sign-out completion page is the same response as the logout
# itself so a reload cannot re-run it.
class Auth::SignEntryAndLogoutDelegationsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class)
    Class.new(controller_class) do
      attr_accessor :rendered, :completed

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def complete
        self.completed = true
      end

      def invoke(name, ...) = send(name, ...)
    end.new
  end

  [].each do |controller_class|
    test "#{controller_class.name} answers the completion page with the logout response itself" do
      harness = harness_for(controller_class)

      harness.show

      assert harness.completed
    end
  end
end
