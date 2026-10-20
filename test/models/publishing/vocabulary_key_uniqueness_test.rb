# frozen_string_literal: true

require "test_helper"

module Publishing
  class VocabularyKeyUniquenessTest < ActiveSupport::TestCase
    FAMILIES = [
      Docs::App::Vocabulary,
      Docs::Com::Vocabulary,
      Docs::Org::Vocabulary,
      Help::App::Vocabulary,
      Help::Com::Vocabulary,
      Help::Org::Vocabulary,
      Info::App::Vocabulary,
      Info::Com::Vocabulary,
      Info::Org::Vocabulary,
      News::App::Vocabulary,
      News::Com::Vocabulary,
      News::Org::Vocabulary,
    ].freeze

    test "vocabulary keys remain independent across all twelve physical families" do
      FAMILIES.each do |model|
        vocabulary = model.create!(
          key: "consistency_key", kind: TaxonomyKind::SINGLE_HIERARCHICAL,
          internal_name: "Consistency",
        )

        assert_equal "consistency_key", vocabulary.reload.key
      end
    end

    FAMILIES.each do |model|
      test "#{model.name} preserves key format sentinels and string casting" do
        [nil, "", " ", 0, "bad-key", "Upper"].each do |key|
          vocabulary = model.new(key: key, kind: TaxonomyKind::SINGLE_HIERARCHICAL, internal_name: "Format")

          assert_not vocabulary.valid?
          assert vocabulary.errors.of_kind?(:key, :invalid)
        end
        ["a", "ab", false].each do |key|
          vocabulary = model.create!(key: key, kind: TaxonomyKind::SINGLE_HIERARCHICAL, internal_name: "Format")

          assert_equal((key == false) ? "f" : key, vocabulary.reload.key)
        end
        [[nil, ActiveRecord::NotNullViolation], ["", ActiveRecord::CheckViolation]].each do |key, error_class|
          assert_raises(error_class) do
            model.transaction(requires_new: true) do
              model.new(
                key: key, kind: TaxonomyKind::SINGLE_HIERARCHICAL,
                internal_name: "SQL",
              ).save!(validate: false)
            end
          end
        end
      end

      test "#{model.name} preserves database duplicates and immutable keys" do
        vocabulary = model.create!(
          key: "consistency_key", kind: TaxonomyKind::SINGLE_HIERARCHICAL,
          internal_name: "Consistency",
        )
        error =
          assert_raises(ActiveRecord::RecordNotUnique) do
            model.transaction(requires_new: true) do
              model.new(
                key: vocabulary.key, kind: vocabulary.kind,
                internal_name: "Duplicate",
              ).save!(validate: false)
            end
          end
        assert_instance_of PG::UniqueViolation, error.cause
        assert_predicate vocabulary, :valid?
        vocabulary.update!(internal_name: "Relabelled")

        assert_equal "Relabelled", vocabulary.reload.internal_name

        other = model.create!(key: "other_key", kind: vocabulary.kind, internal_name: "Other")
        error =
          assert_raises(ActiveRecord::StatementInvalid) do
            model.transaction(requires_new: true) { vocabulary.update!(key: other.key) }
          end
        assert_instance_of PG::RestrictViolation, error.cause
        assert_equal "consistency_key", vocabulary.reload.key
      end

      test "#{model.name} refuses ordinary duplicate keys independent of kind and archival" do
        vocabulary = model.create!(
          key: "consistency_key", kind: TaxonomyKind::SINGLE_HIERARCHICAL,
          internal_name: "Consistency",
        )
        [false, true].each do |archived|
          if archived
            vocabulary.update!(archived_at: Time.utc(2026, 1, 1), archive_reason: "Retired")
          end
          duplicate = model.new(
            key: vocabulary.key, kind: TaxonomyKind::MULTIPLE_ORDERED_FLAT,
            internal_name: "Duplicate",
          )

          assert_not duplicate.valid?
          assert duplicate.errors.of_kind?(:key, :taken)
          [:en, :ja].each do |locale|
            I18n.with_locale(locale) { assert_not_empty duplicate.errors.full_messages }
          end
          assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
          assert_predicate duplicate, :new_record?
          assert_equal 1, model.where(key: vocabulary.key).count
        end
      end

      test "#{model.name} adds one key probe for creation and none for an unchanged existing key" do
        existing = model.create!(
          key: "existing_key", kind: TaxonomyKind::SINGLE_HIERARCHICAL,
          internal_name: "Existing",
        )
        candidate = model.new(
          key: "another_key", kind: TaxonomyKind::SINGLE_HIERARCHICAL,
          internal_name: "Another",
        )
        queries = []
        subscriber =
          lambda do |_name, _start, _finish, _id, payload|
            sql = payload.fetch(:sql)
            queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name) && sql.match?(/"key"\s*=/)
          end
        ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
          assert_predicate candidate, :valid?
          existing.internal_name = "Relabelled"

          assert_predicate existing, :valid?
        end
        assert_equal 1, queries.size
        candidate.save!

        assert_equal "another_key", candidate.reload.key
      end
    end
  end
end
