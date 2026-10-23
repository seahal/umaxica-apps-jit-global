# frozen_string_literal: true

require "test_helper"

class SignUpFlowAdmissionOwnershipTest < ActiveSupport::TestCase
  setup do
    @contexts = {}
    [
      [:app, "client", ClientSignUpFlow, ClientAuthAdmissionBinding, ClientAuthCeremonySession],
      [:com, "visitor", VisitorSignUpFlow, VisitorAuthAdmissionBinding, VisitorAuthCeremonySession],
    ].each do |surface, realm, flow_class, binding_class, ceremony_class|
      @contexts[surface] =
        2.times.map do
          client_id = "core-#{surface}-jp"
          parent = OidcAuthorizationTransactionCoordinator.issue!(
            surface: surface, intent: "authentication",
            params: {
              client_id: client_id,
              redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
              response_type: "code",
              scope: "openid profile",
              prompt: "create",
              state: SecureRandom.hex(16),
              nonce: SecureRandom.hex(16),
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
            },
          ).transaction
          issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
            transaction: parent, base_browser_nonce: SecureRandom.hex(32), base_token: nil,
          )
          binding = binding_class.find_by!(entry_ref: issuance.reference)
          attached, raw_sid = ceremony_class.issue!
          binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
          binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
          ceremony, = ceremony_class.rotate_and_admit!(
            admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
            authorization_transaction_ref: parent.transaction_id,
          )
          binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
          { parent: parent, binding: binding, ceremony: ceremony, flow_class: flow_class }
        end
    end
  end

  %i(app com).each do |surface|
    test "#{surface} allows one in-progress Flow per Binding and preserves terminal history" do
      own, other = @contexts.fetch(surface)
      flow_class = own.fetch(:flow_class)
      now = flow_class.database_now
      attributes = {
        auth_admission_binding: own.fetch(:binding),
        step: "start",
        entry_method: "email",
        issued_at: now,
        expires_at: now + 15.minutes,
        nonce_digest: flow_class.digest_nonce("owner-browser"),
      }
      flow = flow_class.create!(attributes)

      assert_equal own.fetch(:binding).id, flow.auth_admission_binding_id
      assert_raises(ActiveRecord::RecordNotUnique) do
        flow_class.transaction(requires_new: true) { flow_class.create!(attributes) }
      end
      assert_raises(ActiveRecord::ReadonlyAttributeError) do
        flow.update!(auth_admission_binding_id: other.fetch(:binding).id)
      end
      assert_equal own.fetch(:binding).id, flow.reload.auth_admission_binding_id

      SignUpTermination.call(cycle: flow, event: :cancel)
      replacement = flow_class.create!(attributes)

      assert_not_equal flow.id, replacement.id
      assert_predicate flow.reload, :sign_up_cancelled?
      assert_equal 2, flow_class.where(auth_admission_binding_id: own.fetch(:binding).id).count
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          own.fetch(:binding).class.transaction(requires_new: true) { own.fetch(:binding).destroy! }
        end

      assert_kind_of PG::RestrictViolation, error.cause
    end

    test "#{surface} refuses a missing or nonexistent owner at the database boundary" do
      own = @contexts.fetch(surface).first
      flow_class = own.fetch(:flow_class)
      now = flow_class.database_now
      valid = flow_class.create!(
        auth_admission_binding: own.fetch(:binding), step: "start", entry_method: "email",
        issued_at: now, expires_at: now + 15.minutes, nonce_digest: flow_class.digest_nonce("owner-browser"),
      )
      attributes = valid.attributes.except("id").merge("public_id" => PublicId.generate)

      assert_raises(ActiveRecord::NotNullViolation) do
        flow_class.transaction(requires_new: true) do
          flow_class.insert_all!([attributes.except("auth_admission_binding_id")])
        end
      end
      assert_raises(ActiveRecord::InvalidForeignKey) do
        flow_class.transaction(requires_new: true) do
          flow_class.insert_all!([attributes.merge("auth_admission_binding_id" => -1)])
        end
      end
    end

    test "#{surface} locator rejects another Binding's hint and resolves only its admitted owner" do
      own, other = @contexts.fetch(surface)
      flow_class = own.fetch(:flow_class)
      now = flow_class.database_now
      flows =
        [own, other].map do |context|
          flow_class.create!(
            auth_admission_binding: context.fetch(:binding), step: "start", entry_method: "email",
            issued_at: now, expires_at: now + 15.minutes, nonce_digest: flow_class.digest_nonce("owner-browser"),
          )
        end
      session = {}
      locator = SignUpCycleLocator.new(session, surface: surface)
      locator.issue!(flows.fetch(1), nonce: "foreign-browser")
      before = flows.map(&:attributes)

      assert_raises(SignUpCycleLocator::OwnershipMismatch) do
        locator.current(admission_binding: own.fetch(:binding), ceremony_session: own.fetch(:ceremony))
      end
      assert_equal before, flows.map { |flow| flow.reload.attributes }
      locator.clear!

      assert_equal flows.fetch(0), locator.current(
        admission_binding: own.fetch(:binding), ceremony_session: own.fetch(:ceremony),
      )
      assert_raises(SignUpCycleLocator::OwnershipMismatch) do
        locator.current(
          admission_binding: own.fetch(:binding), ceremony_session: other.fetch(:ceremony),
        )
      end
      assert_raises(SignUpCycleLocator::OwnershipMismatch) do
        locator.current(
          admission_binding: own.fetch(:binding), ceremony_session: own.fetch(:ceremony),
          public_id: flows.fetch(1).public_id,
        )
      end
    end
  end
end
