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

  test "entry action wrappers delegate to the shared concern on every cell" do
    originals = {}
    %i(index show new edit create update).each do |action|
      originals[action] = PublishingManagementEntriesActions.instance_method(action)
      PublishingManagementEntriesActions.define_method(action) { action }
    end

    begin
      CELLS.each do |_audience, _surface, controller|
        instance = controller.new

        %i(index show new edit create update).each do |action|
          assert_equal action, instance.public_send(action), "#{controller.name}##{action}"
        end
      end
    ensure
      originals.each do |action, method|
        PublishingManagementEntriesActions.define_method(action, method)
      end
    end
  end

  test "nested publication and archive action wrappers delegate on every cell" do
    pub_originals = {}
    arch_originals = {}
    %i(create destroy).each do |action|
      if PublishingManagementPublicationsActions.method_defined?(action)
        pub_originals[action] = PublishingManagementPublicationsActions.instance_method(action)
        PublishingManagementPublicationsActions.define_method(action) { action }
      end
      if PublishingManagementArchivesActions.method_defined?(action)
        arch_originals[action] = PublishingManagementArchivesActions.instance_method(action)
        PublishingManagementArchivesActions.define_method(action) { action }
      end
    end

    begin
      CELLS.each do |_audience, _surface, controller|
        publications = controller.module_parent::Entries::PublicationsController.new
        archives = controller.module_parent::Entries::ArchivesController.new

        pub_originals.each_key do |action|
          assert_equal action, publications.public_send(action), "#{publications.class.name}##{action}"
        end
        arch_originals.each_key do |action|
          assert_equal action, archives.public_send(action), "#{archives.class.name}##{action}"
        end
      end
    ensure
      pub_originals.each { |action, method| PublishingManagementPublicationsActions.define_method(action, method) }
      arch_originals.each { |action, method| PublishingManagementArchivesActions.define_method(action, method) }
    end
  end
end
