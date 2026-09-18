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

  # A binding matches a subject only when both name the same kind. A mismatched
  # pair is not a match, because treating it as one would bind an avatar to a
  # subject of the wrong type during the backfill.
  test "a binding only matches a subject of its own kind" do
    auditor = AvatarBackfill::AuditLegacyClientBindings.new
    persona = ClientPersona.new(id: 1)
    agent = Agent.new(id: 1)
    individual = Individual.new(id: 1)

    assert auditor.send(:binding_matches_subject?, AvatarPersonaBinding.new(persona_id: 1), persona)
    assert auditor.send(:binding_matches_subject?, AvatarAgentBinding.new(agent_id: 1), agent)
    assert auditor.send(:binding_matches_subject?, AvatarIndividualBinding.new(individual_id: 1), individual)

    assert_not auditor.send(:binding_matches_subject?, AvatarPersonaBinding.new(persona_id: 1), agent)
    assert_not auditor.send(:binding_matches_subject?, AvatarAgentBinding.new(agent_id: 1), persona)
    assert_not auditor.send(:binding_matches_subject?, AvatarAgentBinding.new(agent_id: 2), agent)
    assert_not auditor.send(:binding_matches_subject?, Object.new, persona)
  end

  test "the active binding for a subject is looked up in that subject's own binding table" do
    auditor = AvatarBackfill::AuditLegacyClientBindings.new

    assert_nil auditor.send(:active_binding_for_subject, Agent.new(id: 999_999))
    assert_nil auditor.send(:active_binding_for_subject, Individual.new(id: 999_999))
    assert_nil auditor.send(:active_binding_for_subject, Object.new)
  end
end
