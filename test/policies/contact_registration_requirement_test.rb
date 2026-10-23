# frozen_string_literal: true

require "test_helper"

# Boolean binding assertions keep root references out of diagnostic output.
class ContactRegistrationRequirementTest < ActiveSupport::TestCase
  [
    [Client, ClientToken, ClientEmail, ClientEmailPolicy, :user_id, "app", "settings_email"],
    [Client, ClientToken, ClientTelephone, ClientTelephonePolicy, :user_id, "app", "settings_telephone"],
    [Visitor, VisitorToken, VisitorEmail, VisitorEmailPolicy, :visitor_id, "com", "settings_email"],
    [Visitor, VisitorToken, VisitorTelephone, VisitorTelephonePolicy, :visitor_id, "com", "settings_telephone"],
  ].each do |owner_model, root_model, contact_model, policy_model, owner_key, surface, scope|
    test "#{surface} #{scope} policy owns the complete registration requirement and refuses foreign bindings" do
      owner = owner_model.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: (surface == "app") ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
      )
      root = root_model.create!(:authentication_epoch => 0, owner_key => owner.id, :discard_at => 1.day.from_now)
      root.rotate_refresh_token!
      contact = contact_model.new(owner_key => owner.id)
      policy = policy_model.new(contact, user: owner)
      requirement = policy.credential_registration_requirement(token: root)

      assert_instance_of StepUpRequirement, requirement
      assert_predicate requirement, :step_up_required?
      assert_equal scope, requirement.scope
      assert_equal "step_up:#{surface}", requirement.audience
      assert_equal "step_up", requirement.purpose
      assert_equal %i(email_otp passkey totp), requirement.allowed_methods
      assert_equal 15.minutes, requirement.ttl
      assert_withheld("requirement must bind the actual owner") { requirement.actor_ref == owner.public_id }
      assert_withheld("requirement must bind the actual root") { requirement.session_binding == root.public_id }
      assert_withheld("token binding must name the same root") { requirement.token_binding == root.public_id }
      assert requirement.require_session_binding
      assert_not requirement.phishing_resistant_required?
      assert_not requirement.user_verification_required?
      assert_not requirement.full_reauthentication_required?
      assert_nil requirement.resource_ref
      assert_nil requirement.tenant_ref

      other = owner_model.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: (surface == "app") ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
      )
      foreign_root = root_model.create!(
        :authentication_epoch => 0, owner_key => other.id,
        :discard_at => 1.day.from_now,
      )

      [nil, foreign_root, Object.new].each do |invalid_root|
        assert_raises(ArgumentError) { policy.credential_registration_requirement(token: invalid_root) }
      end
      assert_raises(ArgumentError) do
        policy_model.new(contact_model.new(owner_key => other.id), user: owner)
          .credential_registration_requirement(token: root)
      end
      assert_raises(ArgumentError) do
        policy_model.new(contact, user: nil).credential_registration_requirement(token: root)
      end
    end
  end
end
