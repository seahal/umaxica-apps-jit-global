# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientChronicleLevelTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "accepts integer ids" do
    record = ClientChronicleLevel.new(id: 9)

    assert_predicate record, :valid?
  end

  test "constants are defined" do
    assert_equal 1, ClientChronicleLevel::DEBUG
    assert_equal 2, ClientChronicleLevel::ERROR
    assert_equal 3, ClientChronicleLevel::INFO
    assert_equal 4, ClientChronicleLevel::NOTHING
    assert_equal 5, ClientChronicleLevel::WARN
  end

  test "ensure_defaults! creates records" do
    # Referenced levels retain the audit facts that name them.
    missing = ClientChronicleLevel::DEFAULTS - ClientChronicle.distinct.pluck(:level_id)

    assert_not_empty missing
    ClientChronicleLevel.where(id: missing).delete_all
    assert_difference("ClientChronicleLevel.count", missing.length) do
      ClientChronicleLevel.ensure_defaults!
    end
    assert_equal ClientChronicleLevel::DEFAULTS.sort, ClientChronicleLevel.order(:id).pluck(:id)
  end

  test "returns all default records" do
    ClientChronicleLevel.ensure_defaults!
    ids = ClientChronicleLevel.pluck(:id)

    assert_equal ClientChronicleLevel::DEFAULTS.sort, ids.sort
  end
end
