# frozen_string_literal: true

require "test_helper"

class OpOrgAuthorityStopParticipantFinalStateTest < ActiveSupport::TestCase
  fixtures :op_org_authority_stop_participant_statuses

  test "acknowledged participant is final" do
    participant = OpOrgAuthorityStopParticipant.new(
      status: op_org_authority_stop_participant_statuses(:acknowledged),
    )

    assert_predicate participant, :final?
  end

  test "pending participant is not final" do
    participant = OpOrgAuthorityStopParticipant.new(
      status: op_org_authority_stop_participant_statuses(:pending),
    )

    assert_not participant.final?
  end
end
