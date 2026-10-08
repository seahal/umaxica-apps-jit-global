# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/avatar_legacy_client_id_detector"

class AvatarLegacyClientIdDetectorTest < Minitest::Test
  def test_non_avatar_ownership_reads_and_writes_are_accepted
    source = <<~RUBY
      ClientSecretCredential.available_at(now).where(client_id: actor.id)
      ClientSecretIssuance.create!(client_id: client.id)
      credential = ClientSecretCredential.find(1)
      credential.update!(client_id: user.id)
      credential.client_id = actor.id
      AvatarOwnership.where(client_id: principal.id)
    RUBY
    assert_empty AvatarLegacyClientIdDetector.new.offending_lines(source)
  end

  def test_avatar_multiline_hash_and_assignment_writes_are_rejected
    source = <<~RUBY
      Avatar.create!(
        client_id:
          actor.id
      )
      avatar = Avatar.find(1)
      avatar.client_id = user.id
      avatar.update!({ "client_id" => principal.id })
      Avatar.where(active: true).update_all(client_id: current_client.id)
      client.avatars.create!(client_id: client.id)
    RUBY
    assert_equal [1, 6, 7, 8, 9], AvatarLegacyClientIdDetector.new.offending_lines(source)
  end

  def test_avatar_reads_and_unused_hashes_are_not_writes
    source = <<~RUBY
      Avatar.where(client_id: actor.id)
      Avatar.find_by(client_id: client.id)
      avatar.client_id == user.id
      payload = { client_id: principal.id }
      log(client_id: actor.id)
      # Avatar.create!(client_id: actor.id)
      text = "Avatar.create!(client_id: actor.id)"
    RUBY
    assert_empty AvatarLegacyClientIdDetector.new.offending_lines(source)
  end

  def test_hash_and_receiver_aliases_are_followed_without_exempting_a_whole_class
    source = <<~RUBY
      class ClientSecretIssuance
        def issue
          attributes = { client_id: actor.id }
          record = Avatar.new
          alias_record = record
          alias_record.update!(attributes)
          ClientSecretCredential.create!(attributes)
        end
      end
    RUBY
    assert_equal [6], AvatarLegacyClientIdDetector.new.offending_lines(source)
  end

  def test_legacy_value_alias_and_named_attribute_writer_are_rejected
    source = <<~RUBY
      owner_id = @client.id
      avatar.update_column(:client_id, owner_id)
      avatar.write_attribute("client_id", legacy_compatibility_client_id)
      avatar[:client_id] = @user.id
      Avatar.insert_all([{ client_id: actor.id }])
    RUBY
    assert_equal [2, 3, 4, 5], AvatarLegacyClientIdDetector.new.offending_lines(source)
  end

  def test_local_bindings_do_not_leak_between_methods_and_reassignment_changes_the_receiver
    source = <<~RUBY
      def credential
        record = ClientSecretCredential.new
        record.update!(client_id: actor.id)
      end
      def avatar
        record = Avatar.new
        record.update!(client_id: actor.id)
        record = ClientSecretIssuance.new
        record.update!(client_id: actor.id)
      end
    RUBY
    assert_equal [7], AvatarLegacyClientIdDetector.new.offending_lines(source)
  end

  def test_empty_source_is_accepted_and_invalid_source_fails_explicitly
    assert_empty AvatarLegacyClientIdDetector.new.offending_lines("")
    assert_raises(ArgumentError) { AvatarLegacyClientIdDetector.new.offending_lines("Avatar.create!(") }
  end

  def test_unresolved_write_receivers_cannot_hide_avatar_writes
    source = <<~RUBY
      def bind(record)
        record.update!(client_id: actor.id)
      end
      Avatar.create! do |row|
        row.client_id = client.id
      end
    RUBY
    assert_equal [2, 5], AvatarLegacyClientIdDetector.new.offending_lines(source)
  end

  def test_keyword_splat_and_namespaced_avatar_writes_are_rejected
    source = <<~RUBY
      attributes = { client_id: legacy_compatibility_client_id }
      ::Avatar.create!(**attributes)
      Avatar.find_by(client_id: actor.id)&.update!(client_id: principal.id)
    RUBY
    assert_equal [2, 3], AvatarLegacyClientIdDetector.new.offending_lines(source)
  end

  def test_relation_reassignment_preserves_its_table_without_recursive_bindings
    source = <<~RUBY
      scope = ClientSecretCredential.all
      scope = scope.where(active: true)
      scope.update_all(client_id: actor.id)
      scope = Avatar.all
      scope = scope.where(active: true)
      scope.update_all(client_id: actor.id)
    RUBY
    assert_equal [6], AvatarLegacyClientIdDetector.new.offending_lines(source)
  end
end
