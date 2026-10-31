# frozen_string_literal: true

require "test_helper"

class ClientSignUpFlowTest < ActiveSupport::TestCase
  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientSignUpFlow)
  end

  # R-AU-46: a required reference association with no row must surface as the ordinary
  # belongs_to validation failure in both locales, not as `I18n::MissingTranslationData`
  # for `activerecord.attributes.client_sign_up_flow.cleanup_status`.
  test "a missing cleanup-status reference renders its validation failure in both locales" do
    flow =
      ClientSignUpFlow.new(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
        principal_id: 0, entry_method: "email", step: "checkpoint",
        nonce_digest: ClientSignUpFlow.digest_nonce("ra46-browser"),
        status_id: ClientSignUpFlowStatus::STARTED, state: "STARTED",
        cleanup_status_id: ClientSignUpFlowCleanupStatus.maximum(:id).to_i + 1,
      )

    [:en, :ja].each do |locale|
      I18n.with_locale(locale) do
        flow.valid?

        assert_includes flow.errors.messages, :cleanup_status,
                        "the missing reference row must fail the belongs_to validation in #{locale}"
        messages = flow.errors.full_messages_for(:cleanup_status)

        assert messages.join(" ").exclude?("Translation missing"),
               "the cleanup-status failure must render from the real translations in #{locale}"
      end
    end
  end

  test "the reported cleanup-status attribute has a translated name in both locales" do
    [:en, :ja].each do |locale|
      I18n.with_locale(locale) do
        assert_not(
          ClientSignUpFlow.human_attribute_name(:cleanup_status).exclude?(
            (locale == :en) ? "Cleanup status" : "片付け状態",
          ),
        )
      end
    end
  end

  # BL-22/REQ-CURFEW 5: a sign-up Flow is created after its Admission Binding, so the Binding's
  # curfew, not the Flow's own TTL, ends the attempt; the code caps `expires_at` at creation and
  # this closes the old "the Flow keeps an independent expiry" discrepancy from the code side.
  test "a newly created sign-up flow is capped at its binding curfew" do
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding,
      principal_id: 0, entry_method: "email", step: "cancelled",
      nonce_digest: ClientSignUpFlow.digest_nonce("bl22-browser"),
      status_id: ClientSignUpFlowStatus::CANCELLED,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING,
    )

    assert_predicate binding.reload.curfew_at, :present?,
                     "the Admission Binding must carry the durable curfew the cap reads"
    assert_equal binding.curfew_at.to_i, flow.reload.expires_at.to_i,
                 "the Flow's expiry must not outlive its Admission Binding curfew"
  end
end
