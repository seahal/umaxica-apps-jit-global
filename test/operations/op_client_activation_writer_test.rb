# frozen_string_literal: true

require "test_helper"

# R5-WU19 activation authority: one writer, exact client, current epoch only; closed by default.
class OpClientActivationWriterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  DIGEST = "a" * 64

  test "a client with no activation is not admitted" do
    assert_not OpClientAdmissionQuery.admitted?(client_id: "core-app-jp")
  end

  test "enabling admits exactly that client at the current epoch, recording who and why" do
    result = write("core-app-jp", enabled: true)

    assert_equal OpAppProtocolEpoch.current_contract_epoch, result.contract_epoch
    assert OpClientAdmissionQuery.admitted?(client_id: "core-app-jp")
    assert_not OpClientAdmissionQuery.admitted?(client_id: "warp-app-jp")
    row = OpAppClientActivation.find_by!(client_id: "core-app-jp")

    assert_equal ["operator-1", "audit-1", DIGEST], [row.actor_ref, row.audit_ref, row.source_manifest_digest]
  end

  test "disabling closes the client again on the same row" do
    write("core-app-jp", enabled: true)
    write("core-app-jp", enabled: false)

    assert_not OpClientAdmissionQuery.admitted?(client_id: "core-app-jp")
    assert_equal 1, OpAppClientActivation.where(client_id: "core-app-jp").count
  end

  test "an activation for an older epoch does not admit at the current epoch" do
    write("core-com-jp", enabled: true)
    OpComProtocolEpoch.find(1).update!(contract_epoch: OpComProtocolEpoch.current_contract_epoch + 1)

    assert_not OpClientAdmissionQuery.admitted?(client_id: "core-com-jp")
  end

  test "each realm admits only its own clients" do
    write("base-org-ww", enabled: true)

    assert OpClientAdmissionQuery.admitted?(client_id: "base-org-ww")
    assert_equal 0, OpAppClientActivation.count + OpComClientActivation.count
  end

  test "an unknown client is never admitted" do
    assert_not OpClientAdmissionQuery.admitted?(client_id: "unknown-client")
    assert_not OpClientAdmissionQuery.admitted?(client_id: "")
  end

  test "the writer refuses missing audit facts, a malformed digest and a non-boolean state" do
    assert_raises(ArgumentError) { write("core-app-jp", enabled: true, audit_ref: "") }
    assert_raises(ArgumentError) { write("core-app-jp", enabled: "yes") }
    assert_raises(ActiveRecord::RecordInvalid) { write("core-app-jp", enabled: true, digest: "a" * 63) }
    assert_raises(RpCellBinding::UnknownCell) { write("unknown-client", enabled: true) }
  end

  private

  def write(client_id, enabled:, audit_ref: "audit-1", digest: DIGEST)
    OpClientActivationWriter.call(
      client_id:, enabled:, actor_ref: "operator-1", audit_ref:, source_manifest_digest: digest,
    )
  end
end
