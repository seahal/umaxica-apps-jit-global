# typed: false
# frozen_string_literal: true

require "test_helper"

# A family cutover marker is the point of no return for one authority-owner family: once it exists,
# reviewed backfill is refused. The marker row must therefore be created at most once and never
# change afterwards, for every family and not only the one the cutover operation tests exercise.
class AuthorityCutoverMarkerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [
    AgentAuthorityCutover,
    BureauAuthorityCutover,
    CompanyAuthorityCutover,
    EnterpriseAuthorityCutover,
    IndividualAuthorityCutover,
  ].each do |cutover_class|
    test "#{cutover_class.name} is not established before a marker exists" do
      cutover_class.where(id: cutover_class::CUTOVER_ID).delete_all

      assert_not cutover_class.established?
    end

    test "#{cutover_class.name} establish! creates the single marker and replays without a second row" do
      cutover_class.where(id: cutover_class::CUTOVER_ID).delete_all

      first = cutover_class.establish!
      second = cutover_class.establish!

      assert_predicate cutover_class, :established?
      assert_equal cutover_class::CUTOVER_ID, first.id
      assert_equal first.id, second.id
      assert_equal 1, cutover_class.count
    end

    test "#{cutover_class.name} marker cannot be updated or destroyed once persisted" do
      cutover_class.where(id: cutover_class::CUTOVER_ID).delete_all
      marker = cutover_class.establish!
      established_at = cutover_class.find(marker.id).cutover_at

      assert_raises(ActiveRecord::ReadOnlyRecord) { marker.update!(cutover_at: 1.minute.from_now) }
      assert_raises(ActiveRecord::ReadOnlyRecord) { marker.destroy! }
      assert_equal established_at, cutover_class.find(marker.id).cutover_at
    end
  end

  [
    AgentLifecycle,
    BureauLifecycle,
    CompanyLifecycle,
    EnterpriseLifecycle,
    IndividualLifecycle,
  ].each do |lifecycle_class|
    test "#{lifecycle_class.name} is active only in the active state" do
      assert_predicate lifecycle_class.new(state: AuthorityResourceLifecycleStateValue::ACTIVE), :active?

      [
        AuthorityResourceLifecycleStateValue::INACTIVE,
        AuthorityResourceLifecycleStateValue::DISCARDED,
        AuthorityResourceLifecycleStateValue::DELETED,
        AuthorityResourceLifecycleStateValue::RETAINED,
      ].each do |state|
        assert_not lifecycle_class.new(state: state).active?, "#{state} must not count as active"
      end
    end

    test "#{lifecycle_class.name} is not active with a missing or empty state" do
      assert_not lifecycle_class.new(state: nil).active?
      assert_not lifecycle_class.new(state: "").active?
    end
  end
end
