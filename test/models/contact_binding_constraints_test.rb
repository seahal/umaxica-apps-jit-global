# frozen_string_literal: true

require "test_helper"

class ContactBindingConstraintsTest < ActiveSupport::TestCase
  [
    [ClientEmail, Client, :user_id, :address, :address_digest, "nonblank@example.test"],
    [VisitorEmail, Visitor, :visitor_id, :address, :address_digest, "nonblank@example.test"],
    [ClientTelephone, Client, :user_id, :number, :number_digest, "+819012345671"],
    [VisitorTelephone, Visitor, :visitor_id, :number, :number_digest, "+819012345671"],
  ].each do |model, owner_class, owner_key, destination_key, digest_key, destination|
    test "#{model.name} effective digest rejects nil empty and whitespace and accepts one nonblank character" do
      owner = owner_class.create!
      contact = model.create!(owner_key => owner.id, destination_key => destination, :confirm_policy => "1")
      original = contact.attributes
      decision_time = model.database_now
      # Empty is the shortest representable String. PostgreSQL cannot represent a NUL in this column.
      [nil, "", " ", "\t\n", "\u00a0", "\u2000", "\u200a", "\u3000"].each do |invalid|
        assert_raises(ActiveRecord::StatementInvalid, "blank digest=#{invalid.inspect}") do
          model.transaction(requires_new: true) do
            contact.update_columns(digest_key => invalid, :binding_finalized_at => decision_time)
          end
        end

        assert_equal original, contact.reload.attributes
      end
      # One nonblank character is the nearest positive length; this CHECK does not prescribe digest format.
      contact.update_columns(digest_key => "a", :binding_finalized_at => decision_time)

      assert_equal "a", contact.reload[digest_key]
      assert_predicate contact, :binding_effective?

      # U+2000..U+200A is the Unicode whitespace range; its immediately adjacent values are nonblank.
      ["\u1fff", "\u200b"].each do |nonblank|
        adjacent_owner = owner_class.create!
        adjacent = model.create!(owner_key => adjacent_owner.id, destination_key => destination, :confirm_policy => "1")
        adjacent.update_columns(digest_key => nonblank, :binding_finalized_at => decision_time)

        assert_equal nonblank, adjacent.reload[digest_key]
        assert_predicate adjacent, :binding_effective?
      end
    end
  end

  test "app and com contacts allow independent candidates but enforce effective digest and owner cardinality" do
    [
      [ClientEmail, Client, :user_id, :address, "bindings@example.test"],
      [VisitorEmail, Visitor, :visitor_id, :address, "bindings@example.test"],
      [ClientTelephone, Client, :user_id, :number, "+819012345678"],
      [VisitorTelephone, Visitor, :visitor_id, :number, "+819012345678"],
    ].each do |model, owner_class, owner_key, destination_key, destination|
      owner = owner_class.create!
      other_owner = owner_class.create!
      first = model.create!(owner_key => owner.id, destination_key => destination, :confirm_policy => "1")
      rival = model.create!(owner_key => other_owner.id, destination_key => destination, :confirm_policy => "1")
      second_destination = (destination_key == :address) ? "other-bindings@example.test" : "+819087654321"
      same_owner = model.create!(owner_key => owner.id, destination_key => second_destination, :confirm_policy => "1")

      assert_equal [false, false, false],
                   [first.binding_effective?, rival.binding_effective?, same_owner.binding_effective?]
      first.finalize_binding!
      digest_error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { rival.finalize_binding! }
        end
      owner_error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { same_owner.finalize_binding! }
        end

      assert_includes digest_error.message, "#{model.table_name}_effective_digest"
      assert_includes owner_error.message, "#{model.table_name}_effective_owner"
      assert_equal [first.id], model.effective_binding.where(owner_key => owner.id).pluck(:id)
      first.release_binding!
      rival.reload.finalize_binding!
      same_owner.reload.finalize_binding!

      assert_equal [true, true, true],
                   [first.reload.binding_released?, rival.reload.binding_effective?,
                    same_owner.reload.binding_effective?,]
    end
  end

  test "a pending binding cannot acquire a release fact without recognition in any Contact table" do
    [
      [ClientEmail, Client, :user_id, :address, "pending-release@example.test"],
      [VisitorEmail, Visitor, :visitor_id, :address, "pending-release@example.test"],
      [ClientTelephone, Client, :user_id, :number, "+819012345680"],
      [VisitorTelephone, Visitor, :visitor_id, :number, "+819012345680"],
    ].each do |model, owner_class, owner_key, destination_key, destination|
      owner = owner_class.create!
      contact = model.create!(owner_key => owner.id, destination_key => destination, :confirm_policy => "1")
      unchanged = contact.reload.attributes
      assert_raises(ActiveRecord::StatementInvalid) do
        model.transaction(requires_new: true) do
          contact.update_columns(binding_released_at: model.database_now)
        end
      end

      assert_equal unchanged, contact.reload.attributes
      assert_nil contact.binding_finalized_at
      assert_nil contact.binding_released_at
    end
  end

  test "all contact tables preserve bound owner, digest and one-way release through direct database writes" do
    [
      [ClientEmail, Client, :user_id, :address, :address_digest, "immutable@example.test"],
      [VisitorEmail, Visitor, :visitor_id, :address, :address_digest, "immutable@example.test"],
      [ClientTelephone, Client, :user_id, :number, :number_digest, "+819012345679"],
      [VisitorTelephone, Visitor, :visitor_id, :number, :number_digest, "+819012345679"],
    ].each do |model, owner_class, owner_key, destination_key, digest_key, destination|
      owner = owner_class.create!
      other_owner = owner_class.create!
      contact = model.create!(owner_key => owner.id, destination_key => destination, :confirm_policy => "1")
      contact.finalize_binding!
      recognized_at = contact.reload.binding_finalized_at
      [
        { owner_key => other_owner.id }, { digest_key => "substituted-digest" }, { binding_finalized_at: nil },
      ].each do |mutation|
        error =
          assert_raises(ActiveRecord::StatementInvalid) do
            model.transaction(requires_new: true) { contact.update_columns(mutation) }
          end

        assert_match(/binding .*immutable/, error.message)
        assert_equal recognized_at, contact.reload.binding_finalized_at
      end
      contact.release_binding!
      released_at = contact.reload.binding_released_at
      [nil, released_at + Rational(1, 1_000_000)].each do |replacement|
        error =
          assert_raises(ActiveRecord::StatementInvalid) do
            model.transaction(requires_new: true) { contact.update_columns(binding_released_at: replacement) }
          end

        assert_includes error.message, "released contact binding cannot be reactivated or rewritten"
        assert_equal released_at, contact.reload.binding_released_at
      end
    end
  end
end
