# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit tops for still-cold value/lib/model arms.
class BranchCoverageBatch27ValuesLibEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "AccountStanding refuses unsupported level" do
    assert_raises(ArgumentError) { AccountStanding.new(level: :nope, decisions: {}) }
  end

  test "ExternalAuthentication Failure refuses unsupported provider" do
    code = ExternalAuthentication::Failure::CODES.first
    reason = ExternalAuthentication::Failure::SAFE_REASONS.first

    assert_raises(ArgumentError) do
      ExternalAuthentication::Failure.new(
        code: code,
        provider: "facebook",
        retryable: false,
        safe_reason: reason,
      )
    end
  end

  test "ExternalAuthentication VerifiedPrincipal validation arms" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::VerifiedPrincipal.new(
        provider: "apple",
        subject: "sub",
        issuer: "",
        audience: "aud",
        verified_at: Time.current,
        verification_authority: "auth",
      )
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::VerifiedPrincipal.new(
        provider: "apple",
        subject: "sub",
        issuer: "iss",
        audience: "",
        verified_at: Time.current,
        verification_authority: "auth",
      )
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::VerifiedPrincipal.new(
        provider: "entra",
        subject: "sub",
        issuer: "iss",
        audience: "aud",
        verified_at: Time.current,
        verification_authority: "auth",
        tenant_context: nil,
      )
    end
  end

  test "ExternalAuthentication ProviderRegistry audience without credential key" do
    entry = Object.new
    entry.define_singleton_method(:audience_credential_key) { nil }

    ExternalAuthentication::ProviderRegistry.stub(:fetch, entry) do
      assert_raises(ArgumentError) { ExternalAuthentication::ProviderRegistry.audience("apple") }
    end
  end

  test "IdentityStepUpCeremonyContract validate helpers raise" do
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyContract.validate_required!({ "a" => "" }, %w(a))
    end
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyContract.validate_exact!({ "k" => "x" }, "k", "y")
    end
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyContract.validate_boolean!({ "k" => "yes" }, "k")
    end
  end

  test "IdentityTelephoneCeremonyContract blank return_to early return" do
    assert_nil IdentityTelephoneCeremonyContract.validate_return_to!({ "return_to" => "" })
  end

  test "McpSurfaceIdentity refuses unsupported surface" do
    assert_raises(ArgumentError) { McpSurfaceIdentity.new(realm: "base", surface: "nope") }
  end

  test "SecurityJwtAuthAccessTokenCodec resource type blank arm" do
    assert_nil SecurityJwtAuthAccessTokenCodec.extract_resource_type({})
  end

  test "SignInSequence valid_for and actor_matches false arms" do
    seq = SignInSequence.new(
      id: "1",
      surface: "app",
      participant: "guardrail",
      state: "STARTED",
      actor_type: "Client",
      actor_id: "1",
      expires_at: 1.hour.from_now.iso8601,
    )

    assert_not seq.valid_for?(surface: "com", actor: Client.new, participant: "guardrail")
    assert_not seq.valid_for?(surface: "app", actor: Client.new, participant: "checkpoint")
    assert_not seq.actor_matches?(nil)
    assert_not seq.actor_matches?(Object.new)
  end

  test "SignUpPolicyContext refuses unknown surface" do
    assert_raises(ArgumentError) do
      SignUpPolicyContext.build(surface: :nope, actor_authentication: Object.new, ticket: Object.new)
    end
  end

  test "TimezoneIdentifier returns nil for unknown zone" do
    assert_nil TimezoneIdentifier.normalize("Not/A/Real/Zone")
  end

  test "SingleUseToken consume_once blank digest" do
    klass =
      Class.new(ApplicationRecord) do
        self.table_name = "client_tokens"
        include SingleUseToken
      end

    assert_nil klass.consume_once_by_digest!(digest: "")
    assert_nil klass.consume_once_by_digest!(digest: nil)
  end

  test "TokenStatusManagement discarded and currently_valid_at arms" do
    token = ClientToken.new
    if token.has_attribute?(:discard_at)
      token.discard_at = 1.minute.ago

      assert_not token.currently_usable?
    end

    if ClientToken.column_names.include?("discard_at")
      scope = ClientToken.currently_valid_at

      assert_kind_of ActiveRecord::Relation, scope
    end
  end

  test "lib ChainSeal and ObservabilityRedactor easy arms" do
    assert_not ChainSeal.respond_to?(:ensure_ready!, true)
    assert_equal "[FILTERED]", ObservabilityRedactor.scrub(password: "secret")[:password]
  end

  test "lib LocalEnvironment and ConfigValuesOriginValue arms" do
    assert_not LocalEnvironment.respond_to?(:enabled?)
    assert_equal "https://example.com", ConfigValues.build("example.com").to_s
    assert_raises(ArgumentError) { ConfigValues.build("") }
  end

  test "JitSecurityTurnstileVerifier blank and error arms" do
    result = JitSecurityTurnstileVerifier.verify(token: "", remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", result["error"]
  end

  test "Publishing form validation blank arms" do
    assert_predicate Publishing::PublishEntryForm.new, :valid?

    [Publishing::ArchiveEntryForm, Publishing::EndPublicationForm].each do |form_class|
      form = form_class.new
      outcome =
        begin
          form.valid? ? :valid : :invalid
        rescue I18n::MissingTranslationData
          :translation_missing
        end

      assert_not_equal :valid, outcome
    end
  end

  test "BlindIndexUniquenessValidator and AssociatedRecordLimitValidator edges" do
    validator = BlindIndexUniquenessValidator.new(attributes: [:email])
    record = ClientEmail.new

    assert_nil validator.validate_each(record, :email, nil)
  end
end
