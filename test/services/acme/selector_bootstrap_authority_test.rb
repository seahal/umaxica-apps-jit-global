# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseSelectorBootstrapAuthorityTest < ActiveSupport::TestCase
  setup do
    ensure_reference_rows!
  end

  test "app bootstrap creates account organization membership and avatar idempotently" do
    user = create_client!
    result = nil

    assert_difference -> { ClientAccount.count }, 1 do
      assert_difference -> { ClientIdentity.count }, 1 do
        assert_difference -> { ClientPersona.count }, 1 do
          assert_difference -> { PersonaAssignment.count }, 1 do
            assert_difference -> { Enterprise.count }, 1 do
              assert_difference -> { Avatar.count }, 1 do
                result = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
              end
            end
          end
        end
      end
    end

    assert_no_difference -> {
      ClientAccount.count + ClientPersona.count + PersonaAssignment.count +
        Enterprise.count + Avatar.count
    } do
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    end
    assert_equal "Persona01", result.account.title
    assert_equal "Org01", result.collective.title
    assert_equal 1, AvatarPersonaBinding.where(persona_id: result.account.id).count
    assert_equal 1, AvatarAssignment.where(user_id: user.id, role: "owner").count
    assert_equal 1, result.account.current_memberships.count
    assert_predicate result.avatar, :present?
    assert_equal "active", result.avatar.lifecycle_state.key
    assert_equal user.id, result.avatar.client_id
    assert_equal result.account, result.avatar.current_persona
    assert_equal result.avatar, result.account.current_avatar
  end

  test "app bootstrap delegates avatar creation to AvatarProvisioning Create" do
    user = create_client!
    original_call = AvatarProvisioning::Create.method(:call)
    observed_arguments = nil
    result = nil

    AvatarProvisioning::Create.stub(
      :call,
      lambda do |**arguments|
        observed_arguments = arguments
        original_call.call(**arguments)
      end,
    ) do
      result = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)

      assert_predicate result.avatar, :present?
    end

    assert_equal user, observed_arguments.fetch(:actor)
    assert_equal :persona, observed_arguments.fetch(:subject_type)
    assert_equal "Default Avatar", observed_arguments.fetch(:avatar_params).fetch(:moniker)
    assert_equal result.collective.public_id, observed_arguments.fetch(:organization_public_id)
  end

  test "app bootstrap leaves no partial avatar graph when provisioning fails" do
    user = create_client!
    conflicting_handle = "user-#{user.public_id.downcase}".parameterize + "-aaaaaaaa"
    Handle.create!(handle: conflicting_handle, handle_status_id: HandleStatus::ACTIVE, cooldown_until: Time.current)

    SecureRandom.stub(:alphanumeric, "AAAAAAAA") do
      assert_no_difference -> {
        Avatar.count + AvatarPersonaBinding.count + AvatarAssignment.count + Handle.count
      } do
        assert_raises(ActiveRecord::RecordInvalid) do
          BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
        end
      end
    end
  end

  test "com and org bootstrap do not create app avatars" do
    visitor = create_visitor!
    operator = create_operator!

    com_result = nil
    org_result = nil

    assert_no_difference -> { Avatar.count } do
      com_result = BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
      org_result = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    end

    assert_equal 1, VisitorAccount.where(visitor_id: visitor.id).count
    assert_equal 1, OperatorAccount.where(staff_id: operator.id).count
    assert_equal "Indiv01", com_result.account.title
    assert_equal "Agent01", org_result.account.title
    assert_equal "Org01", com_result.collective.title
    assert_equal "Org01", org_result.collective.title
    assert_nil com_result.avatar
    assert_nil org_result.avatar
    assert_equal 1, IndividualAssignment.count
    assert_equal 1, AgentAssignment.count
  end

  test "rolls back zenith rows when account creation fails after identity creation" do
    user = create_client!

    failing_authority = Class.new(BaseSelectorBootstrapAuthority) do
      def ensure_account!(_identity)
        raise StandardError, "boom"
      end
    end.new(surface: :app, principal: user)

    assert_raises(StandardError) do
      failing_authority.call
    end

    assert_nil ClientIdentity.find_by(source_record_id: user.id)
    assert_nil ClientAccount.find_by(user_id: user.id)
  end

  private

  def ensure_reference_rows!
    [
      ClientStatus, ClientVisibility, ClientMfaLevel, ClientMfaStatus,
      VisitorStatus, VisitorVisibility, VisitorMfaLevel, VisitorMfaStatus,
      OperatorStatus, OperatorVisibility, OperatorMfaLevel, OperatorMfaStatus,
      ClientIdentityState, VisitorIdentityState, OperatorIdentityState,
      PersonaMembershipKind, PersonaMembershipState,
      IndividualMembershipKind, IndividualMembershipState,
      AgentMembershipKind, AgentMembershipState,
      HandleStatus,
    ].each { |klass| klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!) }
    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
  end

  def create_client!
    Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  def create_visitor!
    Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
  end

  def create_operator!
    Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
  end
end
