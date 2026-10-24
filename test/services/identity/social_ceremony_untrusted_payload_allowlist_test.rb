# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Guards the invariant that the social ceremony's UNVERIFIED JWT decode is used
# only for routing/extraction. Untrusted decoding must stay confined to the
# allowlisted locations so a future change cannot quietly start trusting the
# unverified payload for an authn/authz/link/commit decision.
class IdentitySocialCeremonyUntrustedPayloadAllowlistTest < ActiveSupport::TestCase
  APP_ROOT = Rails.root.join("app")

  # Files permitted to invoke the social contract's untrusted routing decode.
  ALLOWLIST = %w(
    app/values/identity_social_ceremony_contract.rb
    app/values/identity_social_ceremony_grant.rb
  ).freeze

  test "untrusted routing decode is only referenced in allowlisted locations" do
    callers = app_files_matching(/IdentitySocialCeremonyContract\.decode_untrusted_routing_payload/)

    unexpected = callers - ALLOWLIST

    assert_empty(
      unexpected,
      "decode_untrusted_routing_payload is untrusted and must stay confined to routing/extraction. " \
      "Unexpected callers: #{unexpected.join(", ")}",
    )
  end

  test "the social contract no longer exposes the ambiguous decode_unverified_payload name" do
    assert_not(
      IdentitySocialCeremonyContract.respond_to?(:decode_unverified_payload),
      "decode_unverified_payload was renamed to decode_untrusted_routing_payload to mark it untrusted",
    )
    assert_respond_to IdentitySocialCeremonyContract, :decode_untrusted_routing_payload

    leftover = app_files_matching(/IdentitySocialCeremonyContract\.decode_unverified_payload/)

    assert_empty leftover,
                 "stale references to IdentitySocialCeremonyContract.decode_unverified_payload: #{leftover.join(", ")}"
  end

  private

  def app_files_matching(pattern)
    Dir.glob(APP_ROOT.join("**", "*.rb")).filter_map do |path|
      next unless File.read(path).match?(pattern)

      Pathname.new(path).relative_path_from(Rails.root).to_s
    end.sort
  end
end
