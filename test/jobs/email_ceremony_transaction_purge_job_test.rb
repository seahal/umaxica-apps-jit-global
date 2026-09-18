# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class EmailCeremonyTransactionPurgeJobTest < ActiveJob::TestCase
  test "uses the isolated retention queue" do
    assert_equal "retention", EmailCeremonyTransactionPurgeJob.queue_name
  end

  test "calls purger service with default batch size" do
    mock_purger = Minitest::Mock.new
    mock_purger.expect(:call, nil)

    mock_new =
      lambda { |batch_size:|
        assert_equal 1000, batch_size
        mock_purger
      }

    IdentityEmailCeremonyTransactionPurger.stub(:new, mock_new) do
      EmailCeremonyTransactionPurgeJob.perform_now
    end

    mock_purger.verify
  end

  test "calls purger service with custom batch size" do
    mock_purger = Minitest::Mock.new
    mock_purger.expect(:call, nil)

    mock_new =
      lambda { |batch_size:|
        assert_equal 500, batch_size
        mock_purger
      }

    IdentityEmailCeremonyTransactionPurger.stub(:new, mock_new) do
      EmailCeremonyTransactionPurgeJob.perform_now(batch_size: 500)
    end

    mock_purger.verify
  end
end
