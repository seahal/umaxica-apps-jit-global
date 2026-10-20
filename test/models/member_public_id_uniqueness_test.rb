# frozen_string_literal: true

require "test_helper"

class MemberPublicIdUniquenessTest < ActiveSupport::TestCase
  test "member IDs remain globally unique in the DB across different owners" do
    first = Member.create!(user: clients(:one), public_id: "member-contract-first")
    second = Member.create!(user: clients(:two), public_id: "member-contract-second")
    first.update!(moniker: "Relabelled")

    assert_equal "member-contract-first", first.reload.public_id
    assert_equal "member-contract-second", second.reload.public_id
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        Member.transaction(requires_new: true) do
          Member.new(user: clients(:two), public_id: first.public_id).save!(validate: false)
        end
      end
    assert_instance_of PG::UniqueViolation, error.cause
    assert_raises(ActiveRecord::NotNullViolation) do
      Member.transaction(requires_new: true) do
        Member.new(user: clients(:one), public_id: nil).save!(validate: false)
      end
    end
  end

  test "member duplicate ID validation rejects another owner without modifying the original" do
    first = Member.create!(user: clients(:one), public_id: "member-contract-first")
    candidate = Member.new(user: clients(:two), public_id: first.public_id)

    assert_not candidate.valid?
    assert candidate.errors.of_kind?(:public_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { candidate.save! }
    assert_predicate candidate, :new_record?
    assert_equal clients(:one).id, first.reload.user_id
  end
end
