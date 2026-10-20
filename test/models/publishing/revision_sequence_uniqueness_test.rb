# frozen_string_literal: true

require "test_helper"

module Publishing
  class RevisionSequenceUniquenessTest < ActiveSupport::TestCase
    FAMILIES = [
      [Docs::App::Entry, Docs::App::EntryRevision],
      [Docs::Com::Entry, Docs::Com::EntryRevision],
      [Docs::Org::Entry, Docs::Org::EntryRevision],
      [Help::App::Entry, Help::App::EntryRevision],
      [Help::Com::Entry, Help::Com::EntryRevision],
      [Help::Org::Entry, Help::Org::EntryRevision],
      [Info::App::Entry, Info::App::EntryRevision],
      [Info::Com::Entry, Info::Com::EntryRevision],
      [Info::Org::Entry, Info::Org::EntryRevision],
      [News::App::Entry, News::App::EntryRevision],
      [News::Com::Entry, News::Com::EntryRevision],
      [News::Org::Entry, News::Org::EntryRevision],
    ].freeze

    FAMILIES.each do |entry_class, revision_class|
      test "#{revision_class.name} scopes sequence uniqueness to an entry and retains DB enforcement" do
        first_entry = entry_class.create!(locale: "ja")
        second_entry = entry_class.create!(locale: "ja")
        metadata = { locale: "ja",
                     title: "Sequence",
                     summary: "Summary",
                     body: { "text" => "Body" },
                     schema_version: 1,
                     content_digest: Digest::SHA256.hexdigest("sequence"),
                     sequence: 1, }
        first = revision_class.create!(metadata.merge(entry: first_entry))
        second = revision_class.create!(metadata.merge(entry: second_entry))
        adjacent = revision_class.create!(metadata.merge(entry: first_entry, sequence: 2))

        assert_equal 1, first.reload.sequence
        assert_equal 1, second.reload.sequence
        assert_equal 2, adjacent.reload.sequence
        first.update!(title: "Updated draft")

        assert_equal "Updated draft", first.reload.title
        assert_raises(ActiveRecord::RecordNotUnique) do
          revision_class.transaction(requires_new: true) do
            revision_class.new(metadata.merge(entry: first_entry)).save!(validate: false)
          end
        end
      end

      test "#{revision_class.name} refuses a duplicate sequence before creation" do
        entry = entry_class.create!(locale: "ja")
        metadata = { locale: "ja",
                     title: "Sequence",
                     summary: "Summary",
                     body: { "text" => "Body" },
                     schema_version: 1,
                     content_digest: Digest::SHA256.hexdigest("sequence"),
                     sequence: 1, }
        revision_class.create!(metadata.merge(entry: entry))
        duplicate = revision_class.new(metadata.merge(entry: entry))

        assert_not duplicate.valid?
        assert duplicate.errors.of_kind?(:sequence, :taken)
        assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      end
    end
  end
end
