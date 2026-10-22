# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch35ZeroFilesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Publishing CreateEntryOperation re-raises non-slug uniqueness" do
    entry_class =
      Class.new do
        const_set(:SURFACE, "docs")
        const_set(:AUDIENCE, "app")
        def self.transaction
          yield
        end

        def self.create!(*)
          raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint \"other_index\""
        end
      end

    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        Publishing::CreateEntryOperation.new(
          entry_class: entry_class,
          locale: "en",
          slug: "slug",
          title: "t",
          summary: "s",
          body: "b",
          operator_public_id: "op",
        ).call
      end
    assert_includes error.message, "other_index"
  end

  test "Publishing CreateEntryOperation maps slug uniqueness to failure" do
    index = Publishing::CreateEntryOperation.slug_index_name(
      Class.new do
        const_set(:SURFACE, "docs")
        const_set(:AUDIENCE, "app")
      end,
    )
    entry_class =
      Class.new do
        const_set(:SURFACE, "docs")
        const_set(:AUDIENCE, "app")
        def self.transaction
          yield
        end
        define_singleton_method(:create!) do |*|
          raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint \"#{index}\""
        end
      end

    result = Publishing::CreateEntryOperation.new(
      entry_class: entry_class,
      locale: "en",
      slug: "slug",
      title: "t",
      summary: "s",
      body: "b",
      operator_public_id: "op",
    ).call

    assert_not result.ok?
    assert_equal "is already used by another entry in this locale", result.errors[:slug]
  end
end
