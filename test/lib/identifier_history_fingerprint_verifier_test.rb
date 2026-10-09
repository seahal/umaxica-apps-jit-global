# frozen_string_literal: true

require "test_helper"
require "argon2"
require "digest"

# Boolean comparisons prevent fingerprints and identifiers entering failure diagnostics.
class IdentifierHistoryFingerprintVerifierTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  %w(app com org).each do |realm|
    %w(email telephone).each do |channel|
      test "#{realm} #{channel} history normalizes candidates and pins salted production Argon2id" do
        identifier, equivalent, other =
          case channel
          when "email" then ["history@example.test", " HISTORY@EXAMPLE.TEST ", "other@example.test"]
          when "telephone" then ["+819012345678", "090-1234-5678", "+819087654321"]
          end
        first = IdentifierHistoryFingerprintVerifier.create(identifier:, realm:, channel:)
        second = IdentifierHistoryFingerprintVerifier.create(identifier: equivalent, realm:, channel:)

        assert_withheld("Fingerprint must be a serialized Argon2id verifier") { first.is_a?(String) }
        assert_withheld("Production costs must not use Rails test min_cost") do
          first.match?(/\A\$argon2id\$v=19\$m=65536,t=3,p=4\$/)
        end
        assert_withheld { second.match?(/\A\$argon2id\$v=19\$m=65536,t=3,p=4\$/) }
        assert_withheld("Equivalent identifiers must receive independent random salts") { first != second }
        assert_withheld("Salt must vary, not only hash output") do
          first.split("$").fetch(4) != second.split("$").fetch(4)
        end
        assert IdentifierHistoryFingerprintVerifier.matches?(
          fingerprint: first, identifier: equivalent, realm:,
          channel:,
        )
        assert IdentifierHistoryFingerprintVerifier.matches?(fingerprint: second, identifier:, realm:, channel:)
        assert_not IdentifierHistoryFingerprintVerifier.matches?(
          fingerprint: first, identifier: other, realm:,
          channel:,
        )
        assert_not first.include?(identifier), "Stored fingerprint must contain no raw identifier"
        assert_not Argon2::Password.verify_password(identifier, first), "Argon2 must not hash raw normalized PII"
        assert_not Argon2::Password.verify_password(Digest::SHA256.hexdigest(identifier), first),
                   "Unkeyed SHA must not substitute for the dedicated history HMAC"
        %w(app com org).reject { |candidate| candidate == realm }.each do |foreign_realm|
          assert_not IdentifierHistoryFingerprintVerifier.matches?(
            fingerprint: first, identifier:, realm: foreign_realm, channel:,
          ), "Fingerprint must not match another realm"
        end
        foreign_channel = (channel == "email") ? "telephone" : "email"

        assert_not IdentifierHistoryFingerprintVerifier.matches?(
          fingerprint: first, identifier:, realm:, channel: foreign_channel,
        ), "Fingerprint must not match another channel"
      end

      test "#{realm} #{channel} history requires its dedicated key independently of live lookup keys" do
        identifier = (channel == "email") ? "history@example.test" : "+819012345678"
        history_key = "#{realm.upcase}_#{channel.upcase}_HISTORY_KEY"
        live_key =
          (channel == "email") ? "#{realm.upcase}_EMAIL_ADDRESS_HMAC_KEY" :
                              "#{realm.upcase}_TELEPHONE_NUMBER_HMAC_KEY"
        original_history = ENV.fetch(history_key)
        original_live = ENV.fetch(live_key)
        fingerprint = IdentifierHistoryFingerprintVerifier.create(identifier:, realm:, channel:)
        ENV[live_key] = "independent-live-key-test-#{realm}-#{channel}"

        assert IdentifierHistoryFingerprintVerifier.matches?(fingerprint:, identifier:, realm:, channel:),
               "Live lookup key changes must not affect history matching"
        ENV[history_key] = "independent-history-key-test-#{realm}-#{channel}"

        assert_not IdentifierHistoryFingerprintVerifier.matches?(fingerprint:, identifier:, realm:, channel:),
                   "The selected dedicated history key must affect matching"
        ENV.delete(history_key)

        assert_raises(KeyError) { IdentifierHistoryFingerprintVerifier.create(identifier:, realm:, channel:) }
        assert_raises(KeyError) do
          IdentifierHistoryFingerprintVerifier.matches?(fingerprint:, identifier:, realm:, channel:)
        end
        ENV[history_key] = ""

        assert_raises(KeyError) { IdentifierHistoryFingerprintVerifier.create(identifier:, realm:, channel:) }
        assert_raises(KeyError) do
          IdentifierHistoryFingerprintVerifier.matches?(fingerprint:, identifier:, realm:, channel:)
        end
      ensure
        ENV[history_key] = original_history if original_history
        ENV[live_key] = original_live if original_live
      end

      test "#{realm} #{channel} history refuses reuse of every configured live identifier HMAC key" do
        identifier = (channel == "email") ? "history-key-isolation@example.test" : "+819012399922"
        history_key = "#{realm.upcase}_#{channel.upcase}_HISTORY_KEY"
        original_history = ENV.fetch(history_key)
        fingerprint = IdentifierHistoryFingerprintVerifier.create(identifier:, realm:, channel:)
        %w(
          APP_EMAIL_ADDRESS_HMAC_KEY COM_EMAIL_ADDRESS_HMAC_KEY ORG_EMAIL_ADDRESS_HMAC_KEY
          APP_TELEPHONE_NUMBER_HMAC_KEY COM_TELEPHONE_NUMBER_HMAC_KEY ORG_TELEPHONE_NUMBER_HMAC_KEY
        ).each do |live_key|
          ENV[history_key] = ENV.fetch(live_key)

          assert_raises(ArgumentError) { IdentifierHistoryFingerprintVerifier.create(identifier:, realm:, channel:) }
          assert_raises(ArgumentError) do
            IdentifierHistoryFingerprintVerifier.matches?(fingerprint:, identifier:, realm:, channel:)
          end
        end
      ensure
        ENV[history_key] = original_history if original_history
      end

      test "#{realm} #{channel} history also refuses live keys configured through credentials" do
        identifier = (channel == "email") ? "history-credential-key@example.test" : "+819012399924"
        history_key = "#{realm.upcase}_#{channel.upcase}_HISTORY_KEY"
        original_history = ENV.fetch(history_key)
        ENV[history_key] = "synthetic-history-live-collision"
        %i(
          APP_EMAIL_ADDRESS_HMAC_KEY COM_EMAIL_ADDRESS_HMAC_KEY ORG_EMAIL_ADDRESS_HMAC_KEY
          APP_TELEPHONE_NUMBER_HMAC_KEY COM_TELEPHONE_NUMBER_HMAC_KEY ORG_TELEPHONE_NUMBER_HMAC_KEY
        ).each do |live_key|
          configured_key = ->(name) { (name == live_key) ? ENV.fetch(history_key) : nil }

          Rails.app.creds.stub(:option, configured_key) do
            assert_raises(ArgumentError) { IdentifierHistoryFingerprintVerifier.create(identifier:, realm:, channel:) }
          end
        end
      ensure
        ENV[history_key] = original_history if original_history
      end

      test "#{realm} #{channel} malformed nil NUL and non scalar identifiers fail closed" do
        valid = (channel == "email") ? "history@example.test" : "+819012345678"
        fingerprint = IdentifierHistoryFingerprintVerifier.create(identifier: valid, realm:, channel:)
        malformed = (channel == "email") ? "not-an-email" : "not-a-number"
        [nil, "", " ", malformed, "#{valid}\0", "\xFF", 0, false, [], {}].each do |identifier|
          assert_raises(ArgumentError) { IdentifierHistoryFingerprintVerifier.create(identifier:, realm:, channel:) }
          assert_not IdentifierHistoryFingerprintVerifier.matches?(fingerprint:, identifier:, realm:, channel:),
                     "Malformed candidate must not acquire matching authority"
        end
      end

      test "#{realm} #{channel} missing malformed and non scalar fingerprints are refused" do
        identifier = (channel == "email") ? "history@example.test" : "+819012345678"

        [nil, "", " ", "not-argon2", "\0", "\xFF", 0, false, [], {},
         "$argon2id$v=19$m=65536,t=3,p=4$",].each do |fingerprint|
          assert_not IdentifierHistoryFingerprintVerifier.matches?(fingerprint:, identifier:, realm:, channel:),
                     "Invalid stored fingerprint must fail closed without legacy matching"
        end
        raw_fingerprint = Argon2::Password.create(identifier, t_cost: 3, m_cost: 16, p_cost: 4)

        assert_not IdentifierHistoryFingerprintVerifier.matches?(
          fingerprint: raw_fingerprint, identifier:, realm:, channel:,
        ),
                   "A raw PII Argon2 hash must not be accepted as a legacy history verifier"
      end
    end
  end

  %w(email telephone).each do |channel|
    test "#{channel} history remains realm domain separated even with equal configured keys" do
      keys = %w(APP_EMAIL_HISTORY_KEY COM_EMAIL_HISTORY_KEY ORG_EMAIL_HISTORY_KEY
                APP_TELEPHONE_HISTORY_KEY COM_TELEPHONE_HISTORY_KEY ORG_TELEPHONE_HISTORY_KEY)
      original = keys.index_with { |key| ENV.fetch(key) }
      keys.each { |key| ENV[key] = "same-test-history-key-for-domain-separation" }
      identifier = (channel == "email") ? "history@example.test" : "+819012345678"
      %w(app com org).each do |realm|
        fingerprint = IdentifierHistoryFingerprintVerifier.create(identifier:, realm:, channel:)

        assert IdentifierHistoryFingerprintVerifier.matches?(fingerprint:, identifier:, realm:, channel:)
        %w(app com org).reject { |candidate| candidate == realm }.each do |foreign_realm|
          assert_not IdentifierHistoryFingerprintVerifier.matches?(
            fingerprint:, identifier:, realm: foreign_realm, channel:,
          ), "Realm domain binding must not rely solely on different secrets or random salts"
        end
      end
    ensure
      original&.each { |key, value| ENV[key] = value }
    end
  end

  test "missing unknown empty non scalar and NUL realm or channel are never inferred" do
    [nil, "", " ", "unknown", "app\0", 0, false, [], {}].each do |realm|
      assert_raises(ArgumentError) do
        IdentifierHistoryFingerprintVerifier.create(identifier: "history@example.test", realm:, channel: "email")
      end
    end
    [nil, "", " ", "unknown", "email\0", 0, false, [], {}].each do |channel|
      assert_raises(ArgumentError) do
        IdentifierHistoryFingerprintVerifier.create(identifier: "history@example.test", realm: "app", channel:)
      end
    end
    assert_raises(ArgumentError) { IdentifierHistoryFingerprintVerifier.create(identifier: "history@example.test") }
    assert_raises(ArgumentError) { IdentifierHistoryFingerprintVerifier.matches?(fingerprint: "not-argon2") }
  end
end
