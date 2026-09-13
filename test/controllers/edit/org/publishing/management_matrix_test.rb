# frozen_string_literal: true

require "test_helper"

class Edit::Org::Publishing::ManagementMatrixTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CELLS = [
    ["app", "info", Edit::Org::Publishing::Info::App::EntriesController],
    ["com", "info", Edit::Org::Publishing::Info::Com::EntriesController],
    ["org", "info", Edit::Org::Publishing::Info::Org::EntriesController],
    ["app", "docs", Edit::Org::Publishing::Docs::App::EntriesController],
    ["com", "docs", Edit::Org::Publishing::Docs::Com::EntriesController],
    ["org", "docs", Edit::Org::Publishing::Docs::Org::EntriesController],
    ["app", "news", Edit::Org::Publishing::News::App::EntriesController],
    ["com", "news", Edit::Org::Publishing::News::Com::EntriesController],
    ["org", "news", Edit::Org::Publishing::News::Org::EntriesController],
    ["app", "help", Edit::Org::Publishing::Help::App::EntriesController],
    ["com", "help", Edit::Org::Publishing::Help::Com::EntriesController],
    ["org", "help", Edit::Org::Publishing::Help::Org::EntriesController],
  ].freeze

  test "all twelve management controllers declare identity and share actions" do
    CELLS.each do |audience, surface, controller|
      assert_includes controller.ancestors, PublishingManagementEntriesActions, controller.name
      assert_equal audience, controller.publishing_audience, controller.name
      assert_equal surface, controller.publishing_surface, controller.name
      assert_equal Publishing::ContentFamilies.entry_class(surface:, audience:), controller::ENTRY_CLASS,
                   controller.name
      assert_operator controller, :<, Edit::Org::ApplicationController
      assert_equal :private, controller::AUTHENTICATION_MODE
      assert_equal :private, controller.authentication_mode_for(:update)
    end
  end

  # Publishing and archiving are nested resources of the entry, so each cell has three
  # controllers, not one. All three answer for the same cell: a publication controller that
  # answered for another audience would publish another audience's content.
  test "the nested publication and archive controllers declare the same cell as their entries controller" do
    CELLS.each do |audience, surface, controller|
      nested = [
        controller.module_parent::Entries::PublicationsController,
        controller.module_parent::Entries::ArchivesController,
      ]

      nested.each do |nested_controller|
        assert_equal audience, nested_controller.publishing_audience, nested_controller.name
        assert_equal surface, nested_controller.publishing_surface, nested_controller.name
        assert_equal controller::ENTRY_CLASS, nested_controller::ENTRY_CLASS, nested_controller.name
        assert_operator nested_controller, :<, Edit::Org::ApplicationController
        assert_equal :private, nested_controller::AUTHENTICATION_MODE, nested_controller.name
      end

      assert_includes(
        controller.module_parent::Entries::PublicationsController.ancestors,
        PublishingManagementPublicationsActions,
      )
      assert_includes(
        controller.module_parent::Entries::ArchivesController.ancestors,
        PublishingManagementArchivesActions,
      )
    end
  end

  # The concern reads its cell from constants the including controller declares, and
  # `const_defined?(..., false)` deliberately does not inherit: a controller that forgets one must
  # not silently answer for its parent's cell, which is another audience's data. Each guard is
  # asserted through a subclass that declares nothing.
  class UndeclaredEntriesController < Edit::Org::Publishing::Docs::App::EntriesController; end

  test "a controller that declares no cell raises rather than inheriting one" do
    %i(publishing_audience publishing_surface publishing_entry_class).each do |reader|
      error = assert_raises(NameError, reader.to_s) { UndeclaredEntriesController.public_send(reader) }

      assert_match(/must declare/, error.message, reader.to_s)
    end
  end
end
