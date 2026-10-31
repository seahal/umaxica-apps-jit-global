# frozen_string_literal: true

require "test_helper"
require "timeout"

class IdentityAuthenticationStopRecorderConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  [Client, Operator].each do |actor_class|
    test "#{actor_class.name} stop recording rolls back the epoch if event insertion fails" do
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      event_class = IdentityAuthenticationStopRecorder::EVENT_CLASSES.fetch(actor_class.name)
      original_epoch = actor.authentication_epoch

      event_class.stub(:create!, ->(**) { raise ActiveRecord::ConnectionNotEstablished }) do
        assert_raises(ActiveRecord::ConnectionNotEstablished) do
          IdentityAuthenticationStopRecorder.call(actor:, reason: "sign_risk")
        end
      end

      assert_equal original_epoch, actor.reload.authentication_epoch
      assert_not event_class.exists?(actor_ref: actor.id.to_s)
    ensure
      event_class&.where(actor_ref: actor.id.to_s)&.delete_all if actor
      actor&.delete
    end

    test "#{actor_class.name} concurrent stop recordings preserve both epochs" do
      actor = actor_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      event_class = IdentityAuthenticationStopRecorder::EVENT_CLASSES.fetch(actor_class.name)
      ready = Queue.new
      start = Queue.new
      workers = []

      actor.with_lock do
        workers =
          2.times.map do
            Thread.new do
              actor_class.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                snapshot = actor_class.find(actor.id)
                ready << connection.select_value("SELECT pg_backend_pid()").to_i
                start.pop
                IdentityAuthenticationStopRecorder.call(actor: snapshot, reason: "sign_risk")
              end
            ensure
              ActiveRecord::Base.connection_handler.clear_active_connections!
            end
          end
        pids = 2.times.map { Timeout.timeout(10) { ready.pop } }
        2.times { start << true }
        pids.each do |pid|
          Timeout.timeout(10) do
            loop do
              blocked =
                actor_class.uncached do
                  actor_class.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
                end
              break if blocked

              Thread.pass
            end
          end
        end
      end
      events = workers.map { |worker| Timeout.timeout(10) { worker.value } }

      assert_equal [1, 2], events.map(&:cutoff_epoch).sort
      assert_equal 2, actor.reload.authentication_epoch
      assert_equal [1, 2], event_class.where(actor_ref: actor.id.to_s).order(:cutoff_epoch).pluck(:cutoff_epoch)
    ensure
      2.times { start << true } if start
      workers&.each { |worker| worker.join(10) }
      event_class&.where(actor_ref: actor.id.to_s)&.delete_all if actor
      actor&.delete
    end
  end
end
