# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_active_record_encryption_key_provider"

# Credential lookup that has to answer nothing rather than raise when a store
# cannot serve a key, so the caller's own fallback decision is the one that runs;
# and the avatar binding matcher, which pairs a binding with a subject only when
# both are of the same kind.
class EncryptionKeyLookupAndBindingMatchingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # A credential store that raises, or that answers neither #option nor #require,
  # is treated as "not configured" so credential_or_fallback makes the decision
  # about what to do next rather than the exception escaping at boot.
  test "a credential store that cannot answer resolves to no value rather than raising" do
    empty_store = Object.new

    Rails.app.stub(:creds, empty_store) do
      assert_nil JitSecurityActiveRecordEncryptionKeyProvider.credential_value(:ANY_KEY)
      assert_nil JitSecurityActiveRecordEncryptionKeyProvider.optional_credential_value(:ANY_KEY)
    end
  end

  test "a credential store that raises resolves to no value rather than propagating" do
    raising = Object.new
    raising.define_singleton_method(:option) { |_key| raise KeyError, "no such credential" }
    raising.define_singleton_method(:require) { |_key| raise KeyError, "no such credential" }

    Rails.app.stub(:creds, raising) do
      assert_nil JitSecurityActiveRecordEncryptionKeyProvider.credential_value(:ANY_KEY)
      assert_nil JitSecurityActiveRecordEncryptionKeyProvider.optional_credential_value(:ANY_KEY)
    end
  end

  test "a previous-key list that is not JSON is read as a single key rather than discarded" do
    single = Object.new
    single.define_singleton_method(:option) { |_key| "not-json-just-a-key" }

    Rails.app.stub(:creds, single) do
      assert_equal ["not-json-just-a-key"], JitSecurityActiveRecordEncryptionKeyProvider.parse_local_previous
    end

    listed = Object.new
    listed.define_singleton_method(:option) { |_key| %(["key-a","key-b"]) }

    Rails.app.stub(:creds, listed) do
      assert_equal %w(key-a key-b), JitSecurityActiveRecordEncryptionKeyProvider.parse_local_previous
    end

    blank = Object.new
    blank.define_singleton_method(:option) { |_key| nil }

    Rails.app.stub(:creds, blank) do
      assert_empty JitSecurityActiveRecordEncryptionKeyProvider.parse_local_previous
    end
  end
end
