# typed: false
# frozen_string_literal: true

require "test_helper"

# The welcome hand-off page is surface-specific and must offer its own next step.
class WelcomeAndActivitySeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, &definition)
    Class.new(controller_class) do
      attr_accessor :params_hash, :rendered

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  [Base::Com::WelcomesController, Base::Org::WelcomesController].each do |klass|
    test "#{klass.name} offers its own next step on the welcome hand-off" do
      harness = harness_for(klass)
      harness.instance_variable_set(:@welcome_next_path, "/dashboard")

      harness.show

      props = harness.rendered.last.fetch(:props)

      assert_predicate props.fetch(:next_link).fetch(:href), :present?
    end
  end


end
