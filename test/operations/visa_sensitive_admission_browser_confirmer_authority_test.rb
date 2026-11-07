# typed: false
# frozen_string_literal: true

require "test_helper"

class VisaSensitiveAdmissionBrowserConfirmerAuthorityTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "browser confirmation rejects an actor, token, and grant from different realms" do
    assert_raises(VisaSensitiveAdmissionBrowserConfirmer::InvalidAuthority) do
      VisaSensitiveAdmissionBrowserConfirmer.call!(
        actor: Client.new,
        token: OperatorToken.new,
        grant: OpOrgGrant.new,
        payload: {},
        client_id: "base-app-ww",
        rp_session_ref: "rp-session-ref",
        public_ref: SecureRandom.uuid,
        browser_digest: "a" * 64,
      )
    end
  end
end
