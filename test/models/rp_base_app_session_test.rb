# frozen_string_literal: true

require "test_helper"

class RpBaseAppSessionTest < ActiveSupport::TestCase
  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::RpBaseAppSession)
  end

  test "active? reads its revocation anchor without lazy-loading the strict association" do
    cell = RpCellBinding.fetch("rp_base_app")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer: "https://www.umaxica.app", subject: "active-session-subject", sid: "active-session-sid",
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    session = enrollment.session

    assert_predicate session, :active?

    RpBaseAppOpSessionBinding.find(session.op_session_binding_id).update!(revoked_at: Time.current)

    assert_not session.reload.active?
  end
end
