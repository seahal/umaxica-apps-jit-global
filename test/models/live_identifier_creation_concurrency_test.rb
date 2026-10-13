# frozen_string_literal: true

require "test_helper"

class LiveIdentifierCreationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  [
    [Client, ClientEmail, :user_id, ClientStatus::ACTIVE, "app", "email", ClientEmailHistory],
    [Client, ClientTelephone, :user_id, ClientStatus::ACTIVE, "app", "telephone", ClientTelephoneHistory],
    [Visitor, VisitorEmail, :visitor_id, VisitorStatus::ACTIVE, "com", "email", VisitorEmailHistory],
    [Visitor, VisitorTelephone, :visitor_id, VisitorStatus::ACTIVE, "com", "telephone", VisitorTelephoneHistory],
    [Operator, OperatorEmail, :staff_id, OperatorStatus::ACTIVE, "org", "email", OperatorEmailHistory],
    [Operator, OperatorTelephone, :staff_id, OperatorStatus::ACTIVE, "org", "telephone", OperatorTelephoneHistory],
  ].each do |owner_model, model, owner_key, owner_status, realm, channel, history_model|
    test "#{realm} #{channel} equivalent concurrent live creation has one winner and usable conflict rollback" do
      owners = 2.times.map { owner_model.create!(status_id: owner_status) }
      identifier =
        (channel == "email") ? "create-race-#{SecureRandom.hex(8)}@example.test" :
          "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
      equivalent = (channel == "email") ? " #{identifier.upcase} " : "0#{identifier.delete_prefix("+81")}"
      input_key = (channel == "email") ? :raw_address : :raw_number
      error_attribute = (channel == "email") ? :address : :number
      digest_column = (channel == "email") ? :address_digest : :number_digest
      digest =
        (channel == "email") ? IdentifierBlindIndex.bidx_for_email(identifier, realm: realm) :
          IdentifierBlindIndex.bidx_for_telephone(identifier, realm: realm)
      ready = Queue.new
      release = Queue.new
      results = Queue.new
      model.connection_pool.release_connection
      threads =
        owners.zip([identifier, equivalent]).map do |owner, input|
          Thread.new do
            model.connection_pool.with_connection do
              ready << true
              release.pop
              begin
                model.transaction(requires_new: true) do
                  attributes = { owner_key => owner.id, :confirm_policy => true, input_key => input }
                  attributes[:confirm_using_mfa] = true if channel == "telephone"
                  record = model.create!(**attributes)
                  record.finalize_binding! unless realm == "org"
                end
                results << :created
              rescue ActiveRecord::RecordNotUnique
                results << :conflict
              rescue ActiveRecord::RecordInvalid => e
                raise unless e.record.errors.of_kind?(error_attribute, :taken)

                results << :conflict
              end
              # A failed PostgreSQL transaction must not poison this worker's subsequent reads.
              results << model.where(digest_column => digest).count
            end
          end
        end
      2.times { ready.pop }
      2.times { release << true }
      threads.each(&:value)
      outcomes = 4.times.map { results.pop }

      assert_equal 1, outcomes.count(:created)
      assert_equal 1, outcomes.count(:conflict)
      assert_equal [1, 1], outcomes.grep(Integer)
      assert_equal 1, model.where(digest_column => digest).count
      winner = model.find_by!(digest_column => digest)

      assert_includes owners.map(&:id), winner[owner_key]
      assert_predicate winner, :binding_effective? unless realm == "org"
    ensure
      threads&.each { |thread| thread.join if thread.alive? }
      owners&.each do |owner|
        model.where(owner_key => owner.id).find_each(&:destroy_without_dead_history!)
        history_model.where(owner_key => owner.id).find_each(&:destroy!)
        owner.reload.update!(discard_at: owner.created_at, purge_eligible_at: owner.created_at)
        owner.destroy!
      end
    end
  end
end
