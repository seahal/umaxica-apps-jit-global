# typed: false
# frozen_string_literal: true

require "test_helper"

class EnforcementCasePublicIdTest < ActiveSupport::TestCase
  REALM_CASES = [AppEnforcementCase, ComEnforcementCase, OrgEnforcementCase].freeze

  test "each realm enforcement case uses the shared Nanoid-21 issuer" do
    REALM_CASES.each do |case_class|
      enforcement_case = case_class.new
      enforcement_case.valid?

      assert_match(/\A[A-Za-z0-9_-]{21}\z/, enforcement_case.public_id, case_class.name)
    end
  end

  test "retries an internally generated public_id after its named unique-index collision" do
    client = clients(:one)
    operator = operators(:one)
    existing = AppEnforcementCase.create!(case_attributes(client, operator).merge(public_id: "a" * 21))
    generated = [existing.public_id, "b" * 21]

    Nanoid.stub(:generate, ->(**_args) { generated.shift }) do
      replacement = AppEnforcementCase.create!(case_attributes(client, operator))

      assert_equal "b" * 21, replacement.public_id
    end
  end

  test "retries a database collision when validation is bypassed" do
    client = clients(:one)
    operator = operators(:one)
    existing = AppEnforcementCase.create!(case_attributes(client, operator).merge(public_id: "c" * 21))
    generated = [existing.public_id, "d" * 21]

    Nanoid.stub(:generate, ->(**_args) { generated.shift }) do
      replacement = AppEnforcementCase.new(case_attributes(client, operator))
      replacement.save!(validate: false)

      assert_equal "d" * 21, replacement.public_id
    end
  end

  test "stops after the bounded public_id collision retry budget" do
    client = clients(:one)
    operator = operators(:one)
    existing = AppEnforcementCase.create!(case_attributes(client, operator).merge(public_id: "e" * 21))
    generated = Array.new(AppEnforcementCase::MAX_PUBLIC_ID_COLLISION_RETRIES + 1, existing.public_id)

    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        Nanoid.stub(:generate, ->(**_args) { generated.shift }) do
          AppEnforcementCase.new(case_attributes(client, operator)).save!(validate: false)
        end
      end

    assert_empty generated
    assert_match(/index_app_enforcement_cases_on_public_id/, error.message)
  end

  test "does not regenerate a caller-supplied public_id after a collision" do
    client = clients(:one)
    operator = operators(:one)
    existing = AppEnforcementCase.create!(case_attributes(client, operator).merge(public_id: "f" * 21))
    generated = ["g" * 21]

    Nanoid.stub(:generate, ->(**_args) { generated.shift }) do
      replacement = AppEnforcementCase.new(case_attributes(client, operator).merge(public_id: existing.public_id))

      assert_raises(ActiveRecord::RecordNotUnique) { replacement.save!(validate: false) }
      assert_equal existing.public_id, replacement.public_id
      assert_equal ["g" * 21], generated
    end
  end

  private

  def case_attributes(client, operator)
    {
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    }
  end
end
