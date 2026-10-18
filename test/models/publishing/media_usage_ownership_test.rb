# frozen_string_literal: true

require "test_helper"

module Publishing
  class MediaUsageOwnershipTest < ActiveSupport::TestCase
    setup do
      @entry = publishing_draft(audience: "app", surface: "docs", slug: "media-owner", title: "Media Owner")
      @revision = @entry.current_revision
      @media_file = publishing_media_file
    end

    test "publishing_media_usages no longer exists" do
      assert_not PublishingRecord.connection.table_exists?("publishing_media_usages")
      assert_raises(NameError) { Publishing.const_get(:MediaUsage) }
    end

    test "revision media usages have a required revision owner and no derived or version columns" do
      columns = PublishingRecord.connection.columns("publishing_docs_app_revision_media_usages").map(&:name)

      assert_includes columns, "entry_revision_id"
      assert_not_includes columns, "entry_version_id"
      assert_not_includes columns, "entry_id"
      assert_not_includes columns, "locale"
      revision_owner =
        PublishingRecord.connection.columns("publishing_docs_app_revision_media_usages")
          .find { |column| column.name == "entry_revision_id" }

      assert_not revision_owner.null
    end

    test "version media usages have a required version owner and no derived or revision columns" do
      columns = PublishingRecord.connection.columns("publishing_docs_app_version_media_usages").map(&:name)

      assert_includes columns, "entry_version_id"
      assert_not_includes columns, "entry_revision_id"
      assert_not_includes columns, "entry_id"
      assert_not_includes columns, "locale"
      version_owner =
        PublishingRecord.connection.columns("publishing_docs_app_version_media_usages")
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

    # A usage records where in the document the media appears. With neither a field_path nor a
    # block_path it names no location, so a renderer has nowhere to place it and an editor has
    # nothing to point at. Refused with a message rather than persisted as an orphan.
    test "a usage that names no location in the document is refused" do
      usage = @revision.media_usages.new(
        media_file: @media_file, role: "body", position: 0, field_path: nil, block_path: nil,
      )

      assert_not usage.valid?
      assert_equal ["must have a field_path or block_path"], usage.errors[:base]
    end

    test "either path alone is enough to locate the usage" do
      field_only = @revision.media_usages.new(
        media_file: @media_file, role: "body", position: 0, field_path: "body.blocks.0", block_path: nil,
      )
      block_only = @revision.media_usages.new(
        media_file: @media_file, role: "body", position: 1, field_path: nil, block_path: "blocks.0",
      )

      assert_predicate field_only, :valid?
      assert_predicate block_only, :valid?
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
      usage = Docs::App::VersionMediaUsage.find_by!(entry_version_id: version.id)

      assert_raises(ActiveRecord::ReadOnlyRecord) { usage.update!(caption: "changed") }
      assert_raises(ActiveRecord::ReadOnlyRecord) { usage.destroy! }
      assert_database_rejects do
        PublishingRecord.lease_connection.execute(
          "UPDATE publishing_docs_app_version_media_usages SET caption = 'x' WHERE id = #{usage.id}",
        )
      end
      assert_database_rejects do
        PublishingRecord.lease_connection.execute(
          "DELETE FROM publishing_docs_app_version_media_usages WHERE id = #{usage.id}",
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
      copied = Docs::App::RevisionMediaUsage.find_by!(entry_revision_id: restored.id)

      assert_equal @media_file.id, copied.media_file_id
      assert_equal "hero", copied.role
      copied.update!(caption: "restored draft")

      assert_equal "restored draft", copied.reload.caption
    end

    test "canonical schema creates owner-explicit media tables and never the union table" do
      schema = Rails.root.join("db/migration_support/publishing_schema.rb").read
      history = Rails.root.glob("db/publishing_migrate/*.rb").map { |path| path.basename.to_s }

      assert_includes schema, "_revision_media_usages"
      assert_includes schema, "_version_media_usages"
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
          version = Docs::App::EntryVersion.create!(
            entry: @entry, entry_revision: @revision, locale: @revision.locale, title: @revision.title,
            body: @revision.body, schema_version: @revision.schema_version,
            content_digest: @revision.content_digest, sequence: 99,
          )
          Docs::App::VersionMediaUsage.create!(
            entry_version: version, media_file: @media_file, role: "body", field_path: "body.blocks.0",
            block_path: "blocks.0", position: 0, caption: "different caption",
          )
          PublishingRecord.lease_connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
        end
      end
    end
  end
end
