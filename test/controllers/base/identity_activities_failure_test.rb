# typed: false
# frozen_string_literal: true

require "test_helper"

# Chronicle read failures must remain distinguishable from an empty activity history.
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
        log.define_singleton_method(:app_activities) { |_scope, client:, limit:| raise ActiveRecord::ConnectionNotEstablished, "reader down" }
        log.define_singleton_method(:activities) { |_scope| raise ActiveRecord::ConnectionNotEstablished, "reader down" }
        log
      end

      def activity_scope = ClientChronicle.none

      def current_client = Struct.new(:public_id).new("client-activity-test")

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  [Base::App::Identity::ActivitiesController, Base::Org::Identity::ActivitiesController].each do |klass|
    test "#{klass.name} reports unavailable when the store cannot be read" do
      harness = harness_for(klass)

      harness.index

      assert_equal :service_unavailable, harness.rendered.last.fetch(:status)
    end
  end
end
