# frozen_string_literal: true

require "test_helper"

module Publishing
  class MediaUsageOwnershipTest < ActiveSupport::TestCase
    setup do
      @edition = publishing_edition(audience: "app", surface: "docs", locale: "ja")
      @entry = publishing_draft(edition: @edition, slug: "media-owner", title: "Media Owner")
      @revision = @entry.current_revision
      @media_file = publishing_media_file
    end

    test "publishing_media_usages no longer exists" do
      assert_not PublishingRecord.connection.table_exists?("publishing_media_usages")
      assert_raises(NameError) { Publishing.const_get(:MediaUsage) }
    end

    test "revision media usages have a required revision owner and no derived or version columns" do
      columns = PublishingRecord.connection.columns("publishing_revision_media_usages").map(&:name)

      assert_includes columns, "entry_revision_id"
      assert_not_includes columns, "entry_version_id"
      assert_not_includes columns, "entry_id"
      assert_not_includes columns, "locale"
      revision_owner =
        PublishingRecord.connection.columns("publishing_revision_media_usages")
          .find { |column| column.name == "entry_revision_id" }

      assert_not revision_owner.null
    end

    test "version media usages have a required version owner and no derived or revision columns" do
      columns = PublishingRecord.connection.columns("publishing_version_media_usages").map(&:name)

      assert_includes columns, "entry_version_id"
      assert_not_includes columns, "entry_revision_id"
      assert_not_includes columns, "entry_id"
      assert_not_includes columns, "locale"
      version_owner =
        PublishingRecord.connection.columns("publishing_version_media_usages")
          .find { |column| column.name == "entry_version_id" }

      assert_not version_owner.null
    end

    test "revision media remains editable until the revision is promoted" do
      usage = publishing_revision_media_usage(revision: @revision, media_file: @media_file)

      usage.update!(position: 3, caption: "draft")

      assert_equal 3, usage.reload.position
      assert_equal "draft", usage.caption
      assert_nothing_raised { usage.destroy! }
    end

    test "duplicate revision media positions are rejected" do
      publishing_revision_media_usage(revision: @revision, media_file: @media_file, position: 0)

      assert_raises(ActiveRecord::RecordNotUnique) do
        publishing_revision_media_usage(
          revision: @revision, media_file: publishing_media_file, position: 0,
        )
      end
    end

    test "promotion copies placement and presentation fields onto the immutable version" do
      publishing_revision_media_usage(
        revision: @revision, media_file: @media_file, role: "hero", position: 0, field_path: "hero",
        caption: "Hero caption", alt_text: "Hero alt", presentation_metadata: { "crop" => "center" },
      )
      second = publishing_media_file
      publishing_revision_media_usage(
        revision: @revision, media_file: second, role: "body", position: 1, field_path: "body.blocks.0",
      )

      version = PromoteRevisionOperation.call(revision: @revision)
      copied = version.media_usages.order(:position)

      assert_equal 2, copied.size
      assert_equal [@media_file.id, second.id], copied.map(&:media_file_id)
      assert_equal %w(hero body), copied.map(&:role)
      assert_equal [0, 1], copied.map(&:position)
      assert_equal "Hero caption", copied.first.caption
      assert_equal "Hero alt", copied.first.alt_text
      assert_equal({ "crop" => "center" }, copied.first.presentation_metadata)
    end

    test "released version media is immutable through active record and postgresql" do
      publishing_revision_media_usage(revision: @revision, media_file: @media_file)
      version = PromoteRevisionOperation.call(revision: @revision)
      usage = version.media_usages.sole

      assert_raises(ActiveRecord::ReadOnlyRecord) { usage.update!(caption: "changed") }
      assert_raises(ActiveRecord::ReadOnlyRecord) { usage.destroy! }
      assert_database_rejects do
        PublishingRecord.lease_connection.execute(
          "UPDATE publishing_version_media_usages SET caption = 'x' WHERE id = #{usage.id}",
        )
      end
      assert_database_rejects do
        PublishingRecord.lease_connection.execute(
          "DELETE FROM publishing_version_media_usages WHERE id = #{usage.id}",
        )
      end
    end

    test "a promoted revision can no longer change its media usages" do
      publishing_revision_media_usage(revision: @revision, media_file: @media_file)
      PromoteRevisionOperation.call(revision: @revision)

      assert_database_rejects do
        publishing_revision_media_usage(
          revision: @revision, media_file: publishing_media_file, position: 1, field_path: "body.blocks.1",
        )
      end
    end

    test "restore copies version media onto a new editable revision" do
      publishing_revision_media_usage(
        revision: @revision, media_file: @media_file, role: "hero", field_path: "hero",
      )
      version = PromoteRevisionOperation.call(revision: @revision)

      restored = RestoreVersionOperation.call(version:)
      copied = restored.media_usages.sole

      assert_equal @media_file.id, copied.media_file_id
      assert_equal "hero", copied.role
      copied.update!(caption: "restored draft")

      assert_equal "restored draft", copied.reload.caption
    end

    test "canonical schema creates owner-explicit media tables and never the union table" do
      schema = Rails.root.join("db/migration_support/publishing_schema.rb").read
      history = Rails.root.glob("db/publishing_migrate/*.rb").map { |path| path.basename.to_s }

      assert_includes schema, "publishing_revision_media_usages"
      assert_includes schema, "publishing_version_media_usages"
      assert_no_match(/create_table\(?\s*:publishing_media_usages\b/, schema)
      assert_not_includes history, "20260903180000_create_publishing_owner_media_usages.rb"
      assert_not_includes history, "20260903180100_split_publishing_media_usages.rb"
    end

    test "commit rejects version media that differs in presentation fields" do
      publishing_revision_media_usage(
        revision: @revision, media_file: @media_file, caption: "source caption",
      )

      assert_raises(ActiveRecord::StatementInvalid) do
        PublishingRecord.transaction(requires_new: true) do
          version = EntryVersion.create!(
            entry: @entry, entry_revision: @revision, locale: @revision.locale, title: @revision.title,
            body: @revision.body, schema_version: @revision.schema_version,
            content_digest: @revision.content_digest, sequence: 99,
          )
          VersionMediaUsage.create!(
            entry_version: version, media_file: @media_file, role: "body", field_path: "body.blocks.0",
            block_path: "blocks.0", position: 0, caption: "different caption",
          )
          PublishingRecord.lease_connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
        end
      end
    end
  end
end
