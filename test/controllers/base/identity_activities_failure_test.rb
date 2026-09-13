# typed: false
# frozen_string_literal: true

require "test_helper"

# The activity list is read from the chronicle store, which may be unavailable
# independently of the surface. The page still renders, with an empty list,
# rather than answering a 500 for a read-only screen.
class BaseIdentityActivitiesFailureTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class)
    Class.new(controller_class) do
      attr_accessor :params_hash, :rendered

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def activity_log
        log = Object.new
        log.define_singleton_method(:activities) { |_scope| raise ActiveRecord::ConnectionNotEstablished, "reader down" }
        log
      end

      def activity_scope = ClientChronicle.none

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  [Base::App::Identity::ActivitiesController, Base::Com::Identity::ActivitiesController, Base::Org::Identity::ActivitiesController].each do |klass|
    test "#{klass.name} still renders the page with an empty list when the store is unavailable" do
      harness = harness_for(klass)

      harness.index

      assert_predicate harness.rendered.last.fetch(:inertia), :present?
      assert_empty harness.rendered.last.fetch(:props).fetch(:activities)
    end
  end
end
