# typed: false
# frozen_string_literal: true

require "test_helper"
require "yaml"

class RecurringCeremonyCleanupContractTest < ActiveSupport::TestCase
  CEREMONY_PURGE_JOBS = %w(
    EmailCeremonyTransactionPurgeJob
    PasskeyCeremonyTransactionPurgeJob
    SecretCredentialCeremonyTransactionPurgeJob
    SocialCeremonyTransactionPurgeJob
    StepUpCeremonyTransactionPurgeJob
    TelephoneCeremonyTransactionPurgeJob
    TotpCeremonyTransactionPurgeJob
  ).freeze

  test "production recurring schedule registers all ceremony transaction purge jobs" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    production_jobs = recurring.fetch("production").values.filter_map { |entry| entry["class"] }

    CEREMONY_PURGE_JOBS.each do |job_class|
      assert_includes production_jobs, job_class
    end
  end

  test "ceremony transaction cleanup remains separate from purge_eligible_at retention cleanup" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    production = recurring.fetch("production")

    assert_equal "RetentionPurgeJob", production.fetch("retention_purge").fetch("class")
    assert_equal "EmailCeremonyTransactionPurgeJob",
                 production.fetch("email_ceremony_transaction_purge").fetch("class")
  end

  test "processor notification retry is a bounded retention task" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))

    %w(development production).each do |environment|
      retry_task = recurring.fetch(environment).fetch("processor_erasure_notification_retry")

      assert_equal "ProcessorErasureNotificationRetryJob", retry_task.fetch("class")
      assert_equal "retention", retry_task.fetch("queue")
      assert_equal [{ "batch_size" => 100 }], retry_task.fetch("args")
      assert_equal "every 15 minutes", retry_task.fetch("schedule")
    end
  end
end
