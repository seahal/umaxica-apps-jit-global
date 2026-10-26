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
    test "#{surface} completed registration keeps its retention and principal when its Flow is collected" do
      own = @contexts.fetch(surface).first
      flow_class = own.fetch(:flow_class)
      principal =
        if surface == :app
          Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, security_mode_id: ClientSecurityMode::NORMAL)
        else
          Visitor.create!(status_id: VisitorStatus::ACTIVE, security_mode_id: VisitorSecurityMode::NORMAL)
        end
      principal_before = principal.attributes
      now = flow_class.database_now
      flow = flow_class.create!(
        auth_admission_binding: own.fetch(:binding), principal_id: principal.id,
        step: "completed", status_id: flow_class.status_id_for("COMPLETED"), completed_at: now,
        entry_method: "email", issued_at: now, expires_at: now + 15.minutes,
        nonce_digest: flow_class.digest_nonce("owner-browser"),
      )
      later = now + 3.hours

      assert_predicate flow, :cleanup_idle?
      assert_not AuthAdmissionBindingPurger.purge_for_parent!(
        parent: own.fetch(:parent), now: later, retention_period: 1.second,
      )
      assert flow_class.exists?(flow.id), "default infinite retention is not shortened"
      flow.discard_now!(purge_after: 2.hours)

      assert AuthAdmissionBindingPurger.purge_for_parent!(
        parent: own.fetch(:parent), now: later, retention_period: 1.second,
      )
      assert_not flow_class.exists?(flow.id)
      assert_not own.fetch(:binding).class.exists?(own.fetch(:binding).id)
      assert_equal principal_before, principal.reload.attributes
    end

    test "#{surface} creation refuses missing Admission and a parent at or beyond its deadline" do
      own = @contexts.fetch(surface).first
      binding = own.fetch(:binding)
      flow_class = own.fetch(:flow_class)
      now = flow_class.database_now
      attributes = {
        step: "start",
        entry_method: "email",
        issued_at: now,
        expires_at: now + 15.minutes,
        nonce_digest: flow_class.digest_nonce("owner-browser"),
      }
      missing = flow_class.new(attributes)

      assert_not missing.valid?
      assert missing.errors.of_kind?(:auth_admission_binding, :blank)
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
        binding.class.stub(:database_now, own.fetch(:parent).reload.expires_at + offset) do
          candidate = flow_class.new(attributes.merge(auth_admission_binding: binding))

          assert_equal offset.negative?, candidate.valid?, "parent expiry offset #{offset}"
          assert_equal !offset.negative?, candidate.errors.key?(:auth_admission_binding)
        end
      end
      own.fetch(:parent).prepare_cancellation_handoff!(
        reference: SecureRandom.uuid, ciphertext: "retained-cancellation-proof",
      )
      own.fetch(:parent).cancel!(cancellation_handoff_digest: SecureRandom.hex(32))
      cancelled = flow_class.new(attributes.merge(auth_admission_binding: binding))

      assert_not cancelled.valid?
      assert cancelled.errors.key?(:auth_admission_binding)
      assert_equal 0, flow_class.where(auth_admission_binding_id: binding.id).count
    end

    test "#{surface} refuses absent admission proof and malformed continuity before selecting a Flow" do
      own = @contexts.fetch(surface).first
      binding = own.fetch(:binding)
      ceremony = own.fetch(:ceremony)
      flow_class = own.fetch(:flow_class)
      now = flow_class.database_now
      flow = flow_class.create!(
        auth_admission_binding: binding, step: "start", entry_method: "email",
        issued_at: now, expires_at: now + 15.minutes, nonce_digest: flow_class.digest_nonce("owner-browser"),
      )
      session = {}
      locator = SignUpCycleLocator.new(session, surface: surface)
      before = flow.attributes
      assert_raises(SignUpCycleLocator::OwnershipMismatch) do
        locator.current(admission_binding: nil, ceremony_session: ceremony)
      end
      assert_raises(SignUpCycleLocator::OwnershipMismatch) do
        locator.current(admission_binding: binding, ceremony_session: nil)
      end
      ["", [], {}, { "public_id" => flow.public_id },
       { "public_id" => flow.public_id, "nonce" => "" },].each do |payload|
        session[SignUpCycleLocator::SESSION_KEYS.fetch(surface)] = payload
        assert_raises(SignUpCycleLocator::OwnershipMismatch) do
          locator.current(admission_binding: binding, ceremony_session: ceremony)
        end
        assert_equal before, flow.reload.attributes
      end
      foreign_class = (surface == :app) ? VisitorSignUpFlow : ClientSignUpFlow
      assert_raises(ArgumentError) { SignUpCycleLocator.new({}, surface: surface, cycle_class: foreign_class) }
    end

    test "#{surface} binding purge waits for terminal Flow retention and deletes children first" do
      own = @contexts.fetch(surface).first
      flow_class = own.fetch(:flow_class)
      now = flow_class.database_now
      flow = flow_class.create!(
        auth_admission_binding: own.fetch(:binding), step: "start", entry_method: "email",
        issued_at: now, expires_at: now + 15.minutes, nonce_digest: flow_class.digest_nonce("owner-browser"),
      )
      parent = own.fetch(:parent)
      binding = own.fetch(:binding)
      retention = 1.second
      later = now + 3.hours

      assert_not AuthAdmissionBindingPurger.purge_for_parent!(parent: parent, now: later, retention_period: retention)
      assert flow_class.exists?(flow.id)
      assert binding.class.exists?(binding.id)

      SignUpTermination.call(cycle: flow, event: :cancel)

      assert_predicate flow.reload, :cleanup_completed?
      flow.discard_now!(purge_after: 2.hours)
      boundary = flow.reload.purge_eligible_at
      replacement = flow_class.create!(
        auth_admission_binding: binding, step: "start", entry_method: "email",
        issued_at: now, expires_at: now + 15.minutes, nonce_digest: flow_class.digest_nonce("replacement-browser"),
      )

      assert_not AuthAdmissionBindingPurger.purge_for_parent!(parent: parent, now: later, retention_period: retention)
      assert flow_class.exists?(flow.id), "one live child retains terminal history as well"
      assert flow_class.exists?(replacement.id)
      SignUpTermination.call(cycle: replacement, event: :cancel)

      assert_not AuthAdmissionBindingPurger.purge_for_parent!(
        parent: parent, now: boundary - Rational(1, 1_000_000), retention_period: retention,
      )
      assert flow_class.exists?(flow.id)
      assert binding.class.exists?(binding.id)
      assert AuthAdmissionBindingPurger.purge_for_parent!(parent: parent, now: boundary, retention_period: retention)
      assert_not flow_class.exists?(flow.id)
      assert_not flow_class.exists?(replacement.id)
      assert_not binding.class.exists?(binding.id)
      assert parent.class.exists?(parent.id)
      assert AuthAdmissionBindingPurger.purge_for_parent!(
        parent: parent, now: boundary + Rational(1, 1_000_000), retention_period: retention,
      )
    end

    test "#{surface} terminal Flow with unfinished cleanup retains its Binding" do
      own = @contexts.fetch(surface).first
      flow_class = own.fetch(:flow_class)
      now = flow_class.database_now
      flow = flow_class.create!(
        auth_admission_binding: own.fetch(:binding), step: "start", entry_method: "email",
        issued_at: now, expires_at: now + 15.minutes, nonce_digest: flow_class.digest_nonce("owner-browser"),
      )
      # The state axis alone does not prove that artifact cleanup finished.
      flow.cancel_sign_up!
      flow.discard_now!(purge_after: 1.minute)
      before = flow.reload.attributes

      assert_not AuthAdmissionBindingPurger.purge_for_parent!(
        parent: own.fetch(:parent), now: now + 3.hours, retention_period: 1.second,
      )
      assert_equal before, flow.reload.attributes
      assert own.fetch(:binding).class.exists?(own.fetch(:binding).id)
    end

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
