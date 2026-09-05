# frozen_string_literal: true

require "test_helper"

class PublishingContentMatrixTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CELLS = [
    ["app", "info", Info::App::Api::V0::EntriesController],
    ["com", "info", Info::Com::Api::V0::EntriesController],
    ["org", "info", Info::Org::Api::V0::EntriesController],
    ["app", "docs", Docs::App::Api::V0::EntriesController],
    ["com", "docs", Docs::Com::Api::V0::EntriesController],
    ["org", "docs", Docs::Org::Api::V0::EntriesController],
    ["app", "news", News::App::Api::V0::EntriesController],
    ["com", "news", News::Com::Api::V0::EntriesController],
    ["org", "news", News::Org::Api::V0::EntriesController],
    ["app", "help", Help::App::Api::V0::EntriesController],
    ["com", "help", Help::Com::Api::V0::EntriesController],
    ["org", "help", Help::Org::Api::V0::EntriesController],
  ].freeze

  test "all twelve CMS entry controllers declare audience and surface and share rendering" do
    CELLS.each do |audience, surface, controller|
      assert_includes controller.ancestors, PublishingContentRendering, controller.name
      assert_equal audience, controller.publishing_audience, controller.name
      assert_equal surface, controller.publishing_surface, controller.name
      assert_includes controller.public_instance_methods(false), :index, controller.name
      assert_includes controller.public_instance_methods(false), :show, controller.name
      assert_equal %i(index show), controller.public_instance_methods(false).sort, controller.name
    end
  end

  test "PublishingContentRendering does not install callbacks of its own" do
    callbacks = PublishingContentRendering.instance_methods(false).grep(/before_action|after_action|around_action/)

    assert_empty callbacks
    source = Rails.root.join("app/controllers/concerns/publishing_content_rendering.rb").read

    assert_no_match(/included do/, source)
  end

  test "including PublishingContentRendering without audience constants fails the contract" do
    klass = Class.new(ApplicationController) { include PublishingContentRendering }

    error = assert_raises(NameError) { klass.publishing_audience }

    assert_includes error.message, "PUBLISHING_AUDIENCE"
  end
end
