# typed: false
# frozen_string_literal: true

require "test_helper"

# Bootstrap must serialize the full account/collective graph, not only the individual creator
# calls. Separate connections are required to expose an orphan collective race.
# rubocop:disable ThreadSafety/NewThread
class BaseSelectorBootstrapAuthorityConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  self.use_transactional_tests = false

  setup do
    VisitorStatus.ensure_defaults!
    VisitorVisibility.ensure_defaults!
    VisitorMfaLevel.ensure_defaults!
    VisitorMfaStatus.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    IndividualMembershipKind.ensure_defaults!
    IndividualMembershipState.ensure_defaults!
    @visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
  end

  teardown do
    next unless @visitor

    identity_ids = VisitorIdentity.where(source_record_id: @visitor.id).pluck(:id)
    individual_ids = Individual.where(visitor_identity_id: identity_ids).pluck(:id)
    company_ids = CompanyOwnership.where(visitor_id: @visitor.id).pluck(:company_id)
    IndividualMembership.where(individual_id: individual_ids).delete_all
    IndividualAssignment.where(visitor_identity_id: identity_ids).delete_all
    IndividualOwnership.where(individual_id: individual_ids).delete_all
    IndividualLifecycle.where(individual_id: individual_ids).delete_all
    Individual.where(id: individual_ids).delete_all
    CompanyUnitClosure.where(
      ancestor_id: CompanyUnit.where(company_id: company_ids).select(:id),
    ).or(
      CompanyUnitClosure.where(
        descendant_id: CompanyUnit.where(company_id: company_ids).select(:id),
      ),
    ).delete_all
    CompanyUnit.where(company_id: company_ids).delete_all
    CompanyOwnership.where(company_id: company_ids).delete_all
    CompanyLifecycle.where(company_id: company_ids).delete_all
    Company.where(id: company_ids).delete_all
    VisitorIdentity.where(id: identity_ids).delete_all
    VisitorAccount.where(visitor_id: @visitor.id).delete_all
    VisitorAuthorityLock.where(visitor_id: @visitor.id).delete_all
    Visitor.where(id: @visitor.id).delete_all
  end

  test "concurrent com bootstraps produce one account and one collective graph" do
    ActiveRecord::Base.connection_handler.clear_active_connections!

    results =
      concurrently(2) do
        BaseSelectorBootstrapAuthority.call(
          surface: :com,
          principal: Visitor.find(@visitor.id),
        )
      end

    errors = results.grep(Exception)

    assert_empty errors, errors.map { |error| "#{error.class}: #{error.message}" }.join("\n")
    assert_equal 2, results.size
    identity_ids = VisitorIdentity.where(source_record_id: @visitor.id).pluck(:id)
    individual_ids = Individual.where(visitor_identity_id: identity_ids).pluck(:id)
    company_ids = CompanyOwnership.where(visitor_id: @visitor.id).pluck(:company_id)

    assert_equal 1, individual_ids.size
    assert_equal 1, company_ids.size
    assert_equal 1, IndividualMembership.where(individual_id: individual_ids).count
    assert_equal 1, IndividualLifecycle.where(
      individual_id: individual_ids,
      state: AuthorityResourceLifecycleStateValue::ACTIVE,
    ).count
  end

  private

  def concurrently(count)
    ready = Queue.new
    release = Queue.new
    threads =
      Array.new(count) do
        Thread.new do
          ComZenithRecord.connection_pool.with_connection do
            ready << true
            release.pop
            yield
          end
        rescue StandardError => e
          e
        end
      end

    count.times { ready.pop }
    count.times { release << true }
    threads.map(&:value).tap { threads.each(&:join) }
  end
end
# rubocop:enable ThreadSafety/NewThread
