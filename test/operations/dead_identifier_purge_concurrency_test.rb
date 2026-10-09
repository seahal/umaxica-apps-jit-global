# frozen_string_literal: true

require "test_helper"

class DeadIdentifierPurgeConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(app com org).each do |realm|
    %w(email telephone).each do |channel|
      test "#{realm} #{channel} reuse racing with purge preserves live uniqueness and records dead history" do
        owner_model, model, history_model, owner_key, status_key, verified, owner_status =
          case [realm, channel]
          when ["app", "email"]
            [Client, ClientEmail, ClientEmailHistory, :user_id, :user_email_status_id,
             ClientEmailStatus::VERIFIED, ClientStatus::ACTIVE,]
          when ["app", "telephone"]
            [Client, ClientTelephone, ClientTelephoneHistory, :user_id, :user_identity_telephone_status_id,
             ClientTelephoneStatus::VERIFIED, ClientStatus::ACTIVE,]
          when ["com", "email"]
            [Visitor, VisitorEmail, VisitorEmailHistory, :visitor_id, :visitor_email_status_id,
             VisitorEmailStatus::VERIFIED, VisitorStatus::ACTIVE,]
          when ["com", "telephone"]
            [Visitor, VisitorTelephone, VisitorTelephoneHistory, :visitor_id, :visitor_telephone_status_id,
             VisitorTelephoneStatus::VERIFIED, VisitorStatus::ACTIVE,]
          when ["org", "email"]
            [Operator, OperatorEmail, OperatorEmailHistory, :staff_id, :staff_identity_email_status_id,
             OperatorEmailStatus::VERIFIED, OperatorStatus::ACTIVE,]
          when ["org", "telephone"]
            [Operator, OperatorTelephone, OperatorTelephoneHistory, :staff_id, :staff_identity_telephone_status_id,
             OperatorTelephoneStatus::VERIFIED, OperatorStatus::ACTIVE,]
          end
        owner = owner_model.create!(status_id: owner_status, created_at: 4.days.ago)
        replacement_owner = owner_model.create!(status_id: owner_status)
        attributes = { :confirm_policy => true, status_key => verified }
        identifier, equivalent =
          if channel == "email"
            address = "purge-reuse-#{owner.id}@example.test"
            attributes[:raw_address] = address
            [address, " #{address.upcase} "]
          else
            number = "+8190#{(owner.id.to_i % 100_000_000).to_s.rjust(8, "0")}"
            attributes[:raw_number] = number
            attributes[:confirm_using_mfa] = true
            [number, "0#{number.delete_prefix("+81")}"]
          end
        record = model.create!(attributes.merge(owner_key => owner.id, :created_at => 3.days.ago))
        record.finalize_binding!(at: record.created_at) unless realm == "org"
        if realm == "org"
          owner.update!(discard_at: owner.created_at + 1.day, purge_eligible_at: owner.created_at + 2.days)
        else
          record.update!(discard_at: record.created_at + 1.day, purge_eligible_at: record.created_at + 2.days)
        end
        replacement_attributes = attributes.merge(owner_key => replacement_owner.id)
        replacement_attributes[(channel == "email") ? :raw_address : :raw_number] = equivalent
        ready = Queue.new
        release = Queue.new
        outcomes = Queue.new
        model.connection_pool.release_connection
        threads = [
          Thread.new do
            model.connection_pool.with_connection do
              local = model.find(record.id)
              ready << true
              release.pop
              history =
                if channel == "email"
                  EmailIdentifierPurger.call(record: local)
                else
                  TelephoneIdentifierPurger.call(record: local)
                end
              outcomes << [:purged, history.id]
            end
          end,
          Thread.new do
            model.connection_pool.with_connection do
              ready << true
              release.pop
              begin
                candidate = model.create!(replacement_attributes)
                candidate.finalize_binding! unless realm == "org"
                outcomes << [:created, candidate.id]
              rescue ActiveRecord::RecordNotUnique
                outcomes << [:conflict, nil]
              rescue ActiveRecord::RecordInvalid => e
                digest_attribute = (channel == "email") ? :address : :number
                raise unless e.record.errors.of_kind?(digest_attribute, :taken)

                outcomes << [:conflict, nil]
              end
            end
          end,
        ]
        2.times { ready.pop }
        2.times { release << true }
        threads.each(&:value)
        results = 2.times.map { outcomes.pop }

        assert_equal 1, results.count { |status, _| status == :purged }
        assert_equal 1, results.count { |status, _| %i(created conflict).include?(status) }
        assert_not model.exists?(record.id)
        assert_equal 1, history_model.where(owner_key => owner.id).count
        assert history_model.find(results.find { |status, _| status == :purged }.last).matches_identifier?(identifier)
        if results.any? { |status, _| status == :conflict }
          replacement = model.find_by(owner_key => replacement_owner.id)
          replacement = model.create!(replacement_attributes) unless replacement
          replacement.finalize_binding! unless realm == "org"
        end
        current = model.find_by!(owner_key => replacement_owner.id)

        assert_equal verified, current[status_key]
        assert_predicate current, :binding_effective? unless realm == "org"

        assert_equal 1, model.where(owner_key => replacement_owner.id).count
        assert_equal 0, history_model.where(owner_key => replacement_owner.id).count
      ensure
        threads&.each { |thread| thread.join if thread.alive? }
        [owner, replacement_owner].compact.each do |actor|
          model.where(owner_key => actor.id).find_each(&:destroy!)
          history_model.where(owner_key => actor.id).find_each(&:destroy!)
          actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
          actor.reload.destroy!
        end
      end
    end
  end

  %w(app com org).each do |realm|
    ["email", "telephone"].each do |channel|
      test "#{realm} #{channel} concurrent irreversible purge inserts exactly one history" do
        owner, model, history_model, owner_key =
          case [realm, channel]
          when ["app", "email"]
            [Client.create!(status_id: ClientStatus::ACTIVE), ClientEmail, ClientEmailHistory, :user_id]
          when ["app", "telephone"]
            [Client.create!(status_id: ClientStatus::ACTIVE), ClientTelephone, ClientTelephoneHistory, :user_id]
          when ["com", "email"]
            [Visitor.create!(status_id: VisitorStatus::ACTIVE), VisitorEmail, VisitorEmailHistory, :visitor_id]
          when ["com", "telephone"]
            [Visitor.create!(status_id: VisitorStatus::ACTIVE), VisitorTelephone, VisitorTelephoneHistory, :visitor_id]
          when ["org", "email"]
            [Operator.create!, OperatorEmail, OperatorEmailHistory, :staff_id]
          when ["org", "telephone"]
            [Operator.create!, OperatorTelephone, OperatorTelephoneHistory, :staff_id]
          end
        attributes = { owner_key => owner.id, :confirm_policy => true, :created_at => 3.days.ago }
        if channel == "email"
          attributes[:raw_address] = "purge-race-#{SecureRandom.hex(8)}@example.com"
        else
          attributes[:raw_number] = "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
          attributes[:confirm_using_mfa] = true
        end
        if realm == "org"
          owner.update!(discard_at: owner.created_at, purge_eligible_at: owner.created_at)
        else
          attributes[:discard_at] = 2.days.ago
          attributes[:purge_eligible_at] = 1.day.ago
        end
        record = model.create!(attributes)
        ready = Queue.new
        release = Queue.new
        outcomes = Queue.new
        model.connection_pool.release_connection
        threads =
          2.times.map do
            Thread.new do
              model.connection_pool.with_connection do
                local = model.find(record.id)
                ready << true
                release.pop
                result =
                  if channel == "email"
                    EmailIdentifierPurger.call(record: local)
                  else
                    TelephoneIdentifierPurger.call(record: local)
                  end
                outcomes << result
              end
            end
          end
        2.times { ready.pop }
        2.times { release << true }
        threads.each(&:value)
        results = 2.times.map { outcomes.pop }

        assert_equal 1, results.count(nil)
        assert_equal 1, results.compact.size
        assert_equal 1, history_model.where(owner_key => owner.id).count
        assert_not model.exists?(record.id)
      ensure
        threads&.each { |thread| thread.join if thread.alive? }
        history_model&.where(owner_key => owner.id)&.find_each(&:destroy!) if owner
        record&.destroy! if record&.persisted? && model.exists?(record.id)
        owner&.reload&.update!(discard_at: owner.created_at, purge_eligible_at: owner.created_at)
        owner&.destroy!
      end
    end
  end
end
