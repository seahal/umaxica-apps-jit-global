# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthorityLockTest < ActiveSupport::TestCase
  fixtures :clients, :visitors, :operators

  test "reuses an existing lock row for each surface" do
    assert_lock_reuse(ClientAuthorityLock, :client_id, clients(:one))
    assert_lock_reuse(VisitorAuthorityLock, :visitor_id, visitors(:reserved_visitor))
    assert_lock_reuse(OperatorAuthorityLock, :operator_id, operators(:one))
  end

  private

  def assert_lock_reuse(lock_class, foreign_key, principal)
    first = lock_class.acquire_for!(**{ foreign_key => principal.id })
    second = lock_class.acquire_for!(**{ foreign_key => principal.id })

    assert_equal first.id, second.id
    assert_equal 1, lock_class.where(id: first.id).count
  end
end
