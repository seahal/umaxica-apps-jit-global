# typed: false
# frozen_string_literal: true

require "test_helper"

# The authentication context is the trusted answer to "which sign-in ceremony
# produced this session", so the two lookups have deliberately different
# strictness: issuing a session under an unknown context must fail loudly, while
# reading one out of an already-signed token must fail closed.
class AuthenticationContextValueTest < ActiveSupport::TestCase
  test "the registry is closed" do
    assert_equal %w(normal emergency), AuthenticationContextValue::KEYS
  end

  test "issue-time lookup refuses a context this build does not enumerate" do
    assert_raises(AuthenticationContextValue::UnknownContextError) do
      AuthenticationContextValue.for("elevated")
    end
  end

  test "a token minted before the claim existed reads as normal" do
    assert_predicate AuthenticationContextValue.from_claims({}), :normal?
    assert_predicate AuthenticationContextValue.from_claims(nil), :normal?
  end

  test "an unrecognised claim value carries no capabilities rather than defaulting to normal" do
    context = AuthenticationContextValue.from_claim("elevated")

    assert_not_predicate context, :normal?
    assert_not_predicate context, :emergency?
    assert_empty context.capabilities
    assert_not context.step_up_permitted?
    assert_not context.permits_rule?(:show?)
  end

  test "a normal context permits step-up and every policy rule" do
    context = AuthenticationContextValue.normal

    assert_predicate context, :step_up_permitted?
    %i(index? show? create? update? destroy? retire?).each do |rule|
      assert context.permits_rule?(rule), "a normal session must not be narrowed by the context layer"
    end
  end

  # The allowlist is the point: a sensitive action added tomorrow is denied to a
  # Restricted Mode session without anyone remembering to guard it.
  test "an emergency context permits read rules only, and never step-up" do
    context = AuthenticationContextValue.emergency

    assert_not context.step_up_permitted?
    assert context.permits_rule?(:index?)
    assert context.permits_rule?(:show?)
    %i(create? update? destroy? retire? approve?).each do |rule|
      assert_not context.permits_rule?(rule), "#{rule} must be unavailable in Restricted Mode by default"
    end
  end

  test "an emergency context narrows authorization scopes and never adds one" do
    scopes = %w(authenticated domain:operator read:org write:org)
    constrained = AuthenticationContextValue.emergency.constrain_scopes(scopes)

    assert_equal %w(authenticated domain:operator read:org), constrained
    assert_empty constrained - scopes
  end

  test "a normal context leaves scopes untouched" do
    scopes = %w(authenticated domain:operator read:org write:org)

    assert_equal scopes, AuthenticationContextValue.normal.constrain_scopes(scopes)
  end
end
