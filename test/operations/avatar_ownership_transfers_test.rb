# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarOwnershipTransfersTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @source_actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @source = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @source_actor)
    @avatar = @source.avatar

    @target_actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    @target = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @target_actor)
  end

  test "request creates one pending five-day transfer without changing ownership" do
    step_up_now = OpBaseAppRecord.database_now
    step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch,
      user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: step_up_now + 1.hour,
    )
    step_up_token.update!(root_login_established_at: step_up_now, established_authentication_method: "passkey")
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.device_session_record!
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_auth_time = step_up_now.to_i - 1
    step_up_grant = OpAppGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      client_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 1.hour,
    )
    step_up_grant.issue_refresh_token!(now: step_up_now)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: step_up_grant.oidc_acr,
      amr: ["passkey"],
      auth_time: step_up_auth_time,
      sid: step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: step_up_client.client_id,
      aud: [step_up_client.aud],
      jti: step_up_grant.oidc_jti,
    )
    transfer =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RequestOperation.call(
            actor: @source_actor,
            surface: "app",
            subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id,
            target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            step_up_token: step_up_token,
            step_up_evidence: step_up_evidence,
          )
        end
      end

    assert_equal "pending", transfer.state
    assert_equal transfer.requested_at.to_i + 5.days.to_i, transfer.expires_at.to_i
    assert_equal "app", transfer.from_owner_surface
    assert_equal @source.collective.public_id, transfer.from_owner_collective_public_id
    assert_equal "org", transfer.to_owner_surface
    assert_equal @target.collective.public_id, transfer.to_owner_collective_public_id
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
  end

  test "registry request reserves a concrete operation and replays by idempotency key" do
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39"
    step_up_now = OpBaseAppRecord.database_now
    step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch,
      user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: step_up_now + 1.hour,
    )
    step_up_token.update!(root_login_established_at: step_up_now, established_authentication_method: "passkey")
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.device_session_record!
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_auth_time = step_up_now.to_i - 1
    step_up_grant = OpAppGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch, client_token: step_up_token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 1.hour,
    )
    step_up_grant.issue_refresh_token!(now: step_up_now)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
      sid: step_up_grant.public_id, sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: step_up_client.client_id, aud: [step_up_client.aud], jti: step_up_grant.oidc_jti,
    )
    attributes = {
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      avatar_public_id: @avatar.public_id,
      target_surface: "org",
      target_collective_public_id: @target.collective.public_id,
      idempotency_key: key,
      request_fingerprint: Digest::SHA256.hexdigest(
        ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
         @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
      ),
      step_up_token: step_up_token,
      step_up_evidence: step_up_evidence,
    }

    first, second =
      OpBaseAppRecord.connected_to(role: :writing) do
      ClientToken.transaction do
        [
          AvatarOwnershipTransfers::RegistryRequestOperation.call(**attributes),
          AvatarOwnershipTransfers::RegistryRequestOperation.call(**attributes),
        ]
      end
    end

    assert_equal first.id, second.id
    assert_equal "pending", first.state
    assert_equal "enterprise_to_bureau", first.operation_kind
    assert_equal @avatar.id, first.avatar_id
    assert_equal @avatar.enterprise_ownership_periods.current.first.id,
                 first.enterprise_to_bureau_detail.source_ownership_period_id
    assert_equal @source.collective.public_id, first.enterprise_to_bureau_detail.source_enterprise_public_id
    assert_equal @target.collective.public_id, first.enterprise_to_bureau_detail.destination_bureau_public_id
    assert_equal @source_actor.public_id, first.enterprise_to_bureau_detail.request_actor_public_id
    assert_equal 1, AvatarTransferReservation.where(id: first.id).count
  end

  test "registry idempotency key is bound to the authenticated initiator" do
    step_up_now = OpBaseAppRecord.database_now
    step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: step_up_now + 1.hour,
    )
    step_up_token.update!(root_login_established_at: step_up_now, established_authentication_method: "passkey")
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.device_session_record!
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_auth_time = step_up_now.to_i - 1
    step_up_grant = OpAppGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch, client_token: step_up_token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 1.hour,
    )
    step_up_grant.issue_refresh_token!(now: step_up_now)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
      sid: step_up_grant.public_id, sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: step_up_client.client_id, aud: [step_up_client.aud], jti: step_up_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: step_up_token, step_up_evidence: step_up_evidence,
          )
        end
      end
    other_actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    other_step_up_now = OpBaseAppRecord.database_now
    other_step_up_token = ClientToken.create!(
      authentication_epoch: other_actor.authentication_epoch, user: other_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: other_step_up_now + 1.hour,
    )
    other_step_up_token.update!(
      root_login_established_at: other_step_up_now, established_authentication_method: "passkey",
    )
    other_step_up_token.rotate_refresh_token!(now: other_step_up_now)
    other_step_up_token.device_session_record!
    other_step_up_auth_time = other_step_up_now.to_i - 1
    other_step_up_grant = OpAppGrant.create!(
      authentication_epoch: other_step_up_token.authentication_epoch, client_token: other_step_up_token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(other_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: other_step_up_now + 1.hour,
    )
    other_step_up_grant.issue_refresh_token!(now: other_step_up_now)
    other_step_up_evidence = StepUpEvidenceValue.new(
      acr: other_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: other_step_up_auth_time,
      sid: other_step_up_grant.public_id,
      sub: OidcSubject.for(other_actor, resource_type: "client"), client_id: step_up_client.client_id,
      aud: [step_up_client.aud], jti: other_step_up_grant.oidc_jti,
    )

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: other_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: reservation.idempotency_key,
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: other_step_up_token, step_up_evidence: other_step_up_evidence,
          )
        end
      end
    end
  end

  test "registry request rejects a caller supplied fingerprint that is not derived from the request" do
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a46"
    step_up_now = OpBaseAppRecord.database_now
    step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: step_up_now + 1.hour,
    )
    step_up_token.update!(root_login_established_at: step_up_now, established_authentication_method: "passkey")
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.device_session_record!
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_auth_time = step_up_now.to_i - 1
    step_up_grant = OpAppGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch, client_token: step_up_token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 1.hour,
    )
    step_up_grant.issue_refresh_token!(now: step_up_now)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
      sid: step_up_grant.public_id, sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: step_up_client.client_id, aud: [step_up_client.aud], jti: step_up_grant.oidc_jti,
    )
    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id, idempotency_key: key,
            request_fingerprint: Digest::SHA256.hexdigest("attacker-controlled-input"),
            step_up_token: step_up_token, step_up_evidence: step_up_evidence,
          )
        end
      end
    end

    assert_not AvatarTransferReservation.exists?(idempotency_key: key)
  end

  test "source owner cancels a pending registry reservation without changing ownership" do
    step_up_now = OpBaseAppRecord.database_now
    step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: step_up_now + 1.hour,
    )
    step_up_token.update!(root_login_established_at: step_up_now, established_authentication_method: "passkey")
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.device_session_record!
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_auth_time = step_up_now.to_i - 1
    step_up_grant = OpAppGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch, client_token: step_up_token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 1.hour,
    )
    step_up_grant.issue_refresh_token!(now: step_up_now)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
      sid: step_up_grant.public_id, sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: step_up_client.client_id, aud: [step_up_client.aud], jti: step_up_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: step_up_token, step_up_evidence: step_up_evidence,
          )
        end
      end

    cancelled =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryCancelOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            reservation_public_id: reservation.public_id,
            step_up_token: step_up_token, step_up_evidence: step_up_evidence,
          )
        end
      end

    assert_equal "cancelled", cancelled.state
    assert_predicate cancelled.completed_at, :present?
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
    assert_equal @source.collective.public_id, @avatar.current_ownership_period.owner_collective_public_id

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryCancelOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            reservation_public_id: reservation.public_id,
            step_up_token: step_up_token, step_up_evidence: step_up_evidence,
          )
        end
      end
    end
  end

  test "target owner accepts a registry reservation and advances the concrete ownership generation" do
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
          )
        end
      end
    source_period = @avatar.enterprise_ownership_periods.current.first

    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    accepted =
      OpBaseOrgRecord.connected_to(role: :writing) do
        OperatorToken.transaction do
          AvatarOwnershipTransfers::RegistryAcceptOperation.call(
            actor: @target_actor, surface: "org", subject_public_id: @target.account.public_id,
            reservation_public_id: reservation.public_id,
            step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
          )
        end
      end

    assert_equal "accepted", accepted.state
    assert_predicate accepted.completed_at, :present?
    assert_equal "org", @avatar.reload.current_ownership_period.owner_surface
    assert_equal @target.collective.public_id, @avatar.current_ownership_period.owner_collective_public_id
    assert_not_equal Float::INFINITY, source_period.reload.valid_to
    bureau_periods = AvatarBureauOwnershipPeriod.where(avatar_id: @avatar.id).current

    assert_equal source_period.valid_to, bureau_periods.first.valid_from
    assert_equal @target.collective.public_id,
                 bureau_periods.first.bureau_public_id
    assert_equal accepted.completed_at,
                 AvatarEnterpriseToBureauTransferDetail.find_by!(transfer_reservation_id: accepted.id).accepted_at
    assert_equal @target_actor.public_id,
                 AvatarEnterpriseToBureauTransferDetail.find_by!(transfer_reservation_id: accepted.id)
                   .accept_actor_public_id
    assert_equal @target_actor.public_id,
                 bureau_periods.first.transferred_by_actor_public_id
  end

  test "registry acceptance after cutover writes only the concrete ownership source" do
    # This slice commits through the Avatar connection, which is intentionally outside the
    # ordinary fixture transaction. Build a private source actor/avatar so a pending reservation
    # from another committed test cannot make the one-pending-per-Avatar invariant collide here.
    source_actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    source = BaseSelectorBootstrapAuthority.call(surface: :app, principal: source_actor)
    avatar = source.avatar

    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: source_actor.authentication_epoch, user: source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    AvatarRecord.transaction(joinable: false) do
      reservation =
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: source_actor,
            surface: "app",
            subject_public_id: source.account.public_id,
            avatar_public_id: avatar.public_id,
            target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: SecureRandom.uuid,
            request_fingerprint: registry_request_fingerprint(
              actor: source_actor,
              subject_public_id: source.account.public_id,
              avatar_public_id: avatar.public_id,
              target_collective_public_id: @target.collective.public_id,
            ),
            step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
          )
        end
      legacy_period_count = avatar.avatar_ownership_periods.count

      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )

      target_group = GroupManagement::Create.call(
        account_surface: "org",
        account_public_id: @target.account.public_id,
        owner_surface: "org",
        owner_collective_public_id: @target.collective.public_id,
        actor: @target_actor,
        subject_public_id: @target.account.public_id,
        name: "Concrete destination group",
      )
      source_group = GroupManagement::Create.call(
        account_surface: "app",
        account_public_id: source.account.public_id,
        owner_surface: "app",
        owner_collective_public_id: source.collective.public_id,
        actor: source_actor,
        subject_public_id: source.account.public_id,
        name: "Concrete former-owner group",
      )
      target_membership = GroupAvatarMembership.create!(
        avatar_group: target_group,
        avatar: avatar,
        role: GroupAvatarMembership::ROLE,
        position: 0,
        state: "active",
      )
      source_membership = GroupAvatarMembership.create!(
        avatar_group: source_group,
        avatar: avatar,
        role: GroupAvatarMembership::ROLE,
        position: 0,
        state: "active",
      )

      accepted =
        OperatorToken.transaction do
          AvatarOwnershipTransfers::RegistryAcceptOperation.call(
            actor: @target_actor,
            surface: "org",
            subject_public_id: @target.account.public_id,
            reservation_public_id: reservation.public_id,
            step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
          )
        end

      assert_equal "accepted", accepted.state
      assert_equal legacy_period_count, AvatarOwnershipPeriod.where(avatar_id: avatar.id).count
      assert_equal "org", avatar.current_ownership_period.owner_surface
      assert_equal @target.collective.public_id, avatar.current_ownership_period.owner_collective_public_id
      assert_equal "active", target_membership.reload.state
      assert_equal "removed", source_membership.reload.state
      assert_equal @target.account.public_id, target_group.reload.account_public_id
      assert_equal source.account.public_id, source_group.reload.account_public_id
      raise ActiveRecord::Rollback
    end
  end

  test "a completed registry request replays its recorded result for the same request" do
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
          )
        end
      end
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    OperatorToken.transaction do
      AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: @target_actor,
        surface: "org",
        subject_public_id: @target.account.public_id,
        reservation_public_id: reservation.public_id,
        step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
      )
    end

    replay =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
          )
        end
      end

    assert_equal reservation.id, replay.id
    assert_equal "accepted", replay.state
    assert_equal reservation.public_id, replay.public_id
  end

  test "registry accept replay returns the recorded result without changing history" do
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
          )
        end
      end
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    accepted =
      OperatorToken.transaction do
        AvatarOwnershipTransfers::RegistryAcceptOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          reservation_public_id: reservation.public_id,
          step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
        )
      end
    legacy_period_count = @avatar.avatar_ownership_periods.count
    bureau_period_count = @avatar.bureau_ownership_periods.count

    replayed =
      OperatorToken.transaction do
        AvatarOwnershipTransfers::RegistryAcceptOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          reservation_public_id: reservation.public_id,
          step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
        )
      end

    assert_equal accepted.id, replayed.id
    assert_equal "accepted", replayed.state
    assert_equal accepted.completed_at, replayed.completed_at
    assert_equal legacy_period_count, AvatarOwnershipPeriod.where(avatar_id: @avatar.id).count
    assert_equal bureau_period_count, AvatarBureauOwnershipPeriod.where(avatar_id: @avatar.id).count
    accepted_detail = AvatarEnterpriseToBureauTransferDetail.find_by!(transfer_reservation_id: accepted.id)
    replayed_detail = AvatarEnterpriseToBureauTransferDetail.find_by!(transfer_reservation_id: replayed.id)

    assert_equal accepted_detail.accepted_at, replayed_detail.accepted_at
  end

  test "registry transfer removes owner-mismatched group membership and preserves target membership" do
    source_group = group_for(@source, surface: "app")
    target_group = group_for(@target, surface: "org")
    stale_membership = membership_for(source_group)
    matching_membership = membership_for(target_group)
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
          )
        end
      end
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    OperatorToken.transaction do
      AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: @target_actor,
        surface: "org",
        subject_public_id: @target.account.public_id,
        reservation_public_id: reservation.public_id,
        step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
      )
    end

    assert_equal "removed", stale_membership.reload.state
    assert_predicate stale_membership.removed_at, :present?
    assert_equal "active", matching_membership.reload.state
    assert_nil matching_membership.removed_at
  end

  test "registry transfer accepts a Bureau-owned Avatar into an Enterprise" do
    result = AvatarProvisioning::Create.call(
      actor: @target_actor,
      subject_type: :agent,
      subject: @target.account,
      avatar_params: { moniker: "Bureau source" },
      handle_params: { handle: "registry-bureau-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: @target.collective.public_id,
    )

    assert_predicate result, :success?, result.errors.inspect
    avatar = result.avatar

    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    reservation =
      OperatorToken.transaction do
        AvatarOwnershipTransfers::RegistryRequestOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          avatar_public_id: avatar.public_id,
          target_surface: "app",
          target_collective_public_id: @source.collective.public_id,
          idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a40",
          request_fingerprint: registry_request_fingerprint(
            actor: @target_actor, surface: "org", subject_public_id: @target.account.public_id,
            avatar_public_id: avatar.public_id, target_surface: "app",
            target_collective_public_id: @source.collective.public_id,
          ),
          step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
        )
      end

    accepted =
      ClientToken.transaction do
        AvatarOwnershipTransfers::RegistryAcceptOperation.call(
          actor: @source_actor,
          surface: "app",
          subject_public_id: @source.account.public_id,
          reservation_public_id: reservation.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end

    assert_equal "accepted", accepted.state
    assert_equal "app", avatar.reload.current_ownership_period.owner_surface
    assert_equal @source.collective.public_id, avatar.current_ownership_period.owner_collective_public_id
    assert_empty avatar.bureau_ownership_periods.current
    assert_equal @source.collective.public_id, avatar.enterprise_ownership_periods.current.first.enterprise_public_id
  end

  test "registry transfer accepts an Enterprise-owned Avatar into another Enterprise" do
    target_actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    target = BaseSelectorBootstrapAuthority.call(surface: :app, principal: target_actor)
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    extra_step_up_now = OpBaseAppRecord.database_now
    extra_step_up_token = ClientToken.create!(
      authentication_epoch: target_actor.authentication_epoch, user: target_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: extra_step_up_now + 1.hour,
    )
    extra_step_up_token.update!(
      root_login_established_at: extra_step_up_now, established_authentication_method: "passkey",
    )
    extra_step_up_token.rotate_refresh_token!(now: extra_step_up_now)
    extra_step_up_token.device_session_record!
    extra_step_up_client = OidcClientRegistry.find!("base-app-ww")
    extra_step_up_auth_time = extra_step_up_now.to_i - 1
    extra_step_up_grant = OpAppGrant.create!(
      authentication_epoch: extra_step_up_token.authentication_epoch, client_token: extra_step_up_token,
      oidc_client_id: extra_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(extra_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: extra_step_up_now + 1.hour,
    )
    extra_step_up_grant.issue_refresh_token!(now: extra_step_up_now)
    extra_step_up_evidence = StepUpEvidenceValue.new(
      acr: extra_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: extra_step_up_auth_time,
      sid: extra_step_up_grant.public_id,
      sub: OidcSubject.for(target_actor, resource_type: "client"),
      client_id: extra_step_up_client.client_id, aud: [extra_step_up_client.aud],
      jti: extra_step_up_grant.oidc_jti,
    )
    reservation =
      ClientToken.transaction do
        AvatarOwnershipTransfers::RegistryRequestOperation.call(
          actor: @source_actor,
          surface: "app",
          subject_public_id: @source.account.public_id,
          avatar_public_id: @avatar.public_id,
          target_surface: "app",
          target_collective_public_id: target.collective.public_id,
          idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a43",
          request_fingerprint: registry_request_fingerprint(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "app",
            target_collective_public_id: target.collective.public_id,
          ),
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end

    accepted =
      ClientToken.transaction do
        AvatarOwnershipTransfers::RegistryAcceptOperation.call(
          actor: target_actor,
          surface: "app",
          subject_public_id: target.account.public_id,
          reservation_public_id: reservation.public_id,
          step_up_token: extra_step_up_token, step_up_evidence: extra_step_up_evidence,
        )
      end

    assert_equal "accepted", accepted.state
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
    assert_equal target.collective.public_id, @avatar.current_ownership_period.owner_collective_public_id
    assert_equal target.collective.public_id, @avatar.enterprise_ownership_periods.current.first.enterprise_public_id
    assert_empty @avatar.bureau_ownership_periods.current
  end

  test "returning to the original owner does not reactivate its historical grant" do
    original_period = @avatar.enterprise_ownership_periods.current.first
    historical_grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: original_period,
      subject: @source.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @source_actor.public_id,
      granting_subject_public_id: @source.account.public_id,
    )

    assert AvatarAccessGrantResolver.call(
      avatar: @avatar,
      ownership_period: original_period,
      subject: @source.account,
      capability: "avatar.view",
    )

    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    to_bureau =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          ClientToken.transaction do
            AvatarOwnershipTransfers::RegistryRequestOperation.call(
              actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
              avatar_public_id: @avatar.public_id, target_surface: "org",
              target_collective_public_id: @target.collective.public_id,
              idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
              request_fingerprint: Digest::SHA256.hexdigest(
                ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
                 @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
              ),
              step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
            )
          end
        end
      end
    OperatorToken.transaction do
      AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: @target_actor,
        surface: "org",
        subject_public_id: @target.account.public_id,
        reservation_public_id: to_bureau.public_id,
        step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
      )
    end

    back_to_enterprise =
      OperatorToken.transaction do
        AvatarOwnershipTransfers::RegistryRequestOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          avatar_public_id: @avatar.public_id,
          target_surface: "app",
          target_collective_public_id: @source.collective.public_id,
          idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a45",
          request_fingerprint: registry_request_fingerprint(
            actor: @target_actor,
            surface: "org",
            subject_public_id: @target.account.public_id,
            avatar_public_id: @avatar.public_id,
            target_surface: "app",
            target_collective_public_id: @source.collective.public_id,
          ),
          step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
        )
      end

    ClientToken.transaction do
      AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: @source_actor,
        surface: "app",
        subject_public_id: @source.account.public_id,
        reservation_public_id: back_to_enterprise.public_id,
        step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
      )
    end

    current_period = @avatar.reload.enterprise_ownership_periods.current.first

    assert_not_equal original_period.id, current_period.id
    assert_not AvatarAccessGrantResolver.call(
      avatar: @avatar,
      ownership_period: original_period,
      subject: @source.account,
      capability: "avatar.view",
    )
    assert_not AvatarAccessGrantResolver.call(
      avatar: @avatar,
      ownership_period: current_period,
      subject: @source.account,
      capability: "avatar.view",
    )
    assert_nil historical_grant.reload.revoked_at

    fresh_grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: current_period,
      subject: @source.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @source_actor.public_id,
      granting_subject_public_id: @source.account.public_id,
    )

    assert AvatarAccessGrantResolver.call(
      avatar: @avatar,
      ownership_period: current_period,
      subject: @source.account,
      capability: "avatar.view",
    )
    assert_not_equal historical_grant.id, fresh_grant.id
  end

  test "registry transfer accepts a Bureau-owned Avatar into another Bureau" do
    target_actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    target = BaseSelectorBootstrapAuthority.call(surface: :org, principal: target_actor)
    result = AvatarProvisioning::Create.call(
      actor: @target_actor,
      subject_type: :agent,
      subject: @target.account,
      avatar_params: { moniker: "Bureau 2" },
      handle_params: { handle: "registry-bureau-to-bureau-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: @target.collective.public_id,
    )

    assert_predicate result, :success?, result.errors.inspect

    avatar = result.avatar

    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    extra_step_up_now = OpBaseOrgRecord.database_now
    extra_step_up_token = OperatorToken.create!(
      authentication_epoch: target_actor.authentication_epoch, staff: target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: extra_step_up_now + 1.hour,
    )
    extra_step_up_token.update!(
      root_login_established_at: extra_step_up_now, established_authentication_method: "passkey",
    )
    extra_step_up_token.rotate_refresh_token!(now: extra_step_up_now)
    extra_step_up_token.device_session_record!
    extra_step_up_client = OidcClientRegistry.find!("base-org-ww")
    extra_step_up_auth_time = extra_step_up_now.to_i - 1
    extra_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: extra_step_up_token.authentication_epoch, operator_token: extra_step_up_token,
      oidc_client_id: extra_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(extra_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: extra_step_up_now + 1.hour,
    )
    extra_step_up_grant.issue_refresh_token!(now: extra_step_up_now)
    extra_step_up_evidence = StepUpEvidenceValue.new(
      acr: extra_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: extra_step_up_auth_time,
      sid: extra_step_up_grant.public_id,
      sub: OidcSubject.for(target_actor, resource_type: "operator"),
      client_id: extra_step_up_client.client_id, aud: [extra_step_up_client.aud],
      jti: extra_step_up_grant.oidc_jti,
    )

    reservation =
      OperatorToken.transaction do
        AvatarOwnershipTransfers::RegistryRequestOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          avatar_public_id: avatar.public_id,
          target_surface: "org",
          target_collective_public_id: target.collective.public_id,
          idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a44",
          request_fingerprint: registry_request_fingerprint(
            actor: @target_actor, surface: "org", subject_public_id: @target.account.public_id,
            avatar_public_id: avatar.public_id, target_surface: "org",
            target_collective_public_id: target.collective.public_id,
          ),
          step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
        )
      end

    accepted =
      OperatorToken.transaction do
        AvatarOwnershipTransfers::RegistryAcceptOperation.call(
          actor: target_actor,
          surface: "org",
          subject_public_id: target.account.public_id,
          reservation_public_id: reservation.public_id,
          step_up_token: extra_step_up_token, step_up_evidence: extra_step_up_evidence,
        )
      end

    assert_equal "accepted", accepted.state
    assert_equal "org", avatar.reload.current_ownership_period.owner_surface
    assert_equal target.collective.public_id, avatar.current_ownership_period.owner_collective_public_id
    assert_equal target.collective.public_id, avatar.bureau_ownership_periods.current.first.bureau_public_id
    assert_empty avatar.enterprise_ownership_periods.current
  end

  test "registry accept rejects a non-advancing transfer instant without changing history" do
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
          )
        end
      end
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    source_period = @avatar.enterprise_ownership_periods.current.first

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      Avatar.stub(:database_now, source_period.valid_from) do
        OperatorToken.transaction do
          AvatarOwnershipTransfers::RegistryAcceptOperation.call(
            step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
            actor: @target_actor,
            surface: "org",
            subject_public_id: @target.account.public_id,
            reservation_public_id: reservation.public_id,
          )
        end
      end
    end

    assert_equal "pending", reservation.reload.state
    assert_equal Float::INFINITY, source_period.reload.valid_to
    assert_empty AvatarBureauOwnershipPeriod.where(avatar_id: @avatar.id).current
  end

  test "registry accept rejects an instant that does not advance either ownership history" do
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
          )
        end
      end
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    source_period = @avatar.enterprise_ownership_periods.current.first
    legacy_period = @avatar.current_ownership_period
    legacy_period.update!(valid_from: source_period.valid_from + 1.second)

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      Avatar.stub(:database_now, legacy_period.valid_from) do
        OperatorToken.transaction do
          AvatarOwnershipTransfers::RegistryAcceptOperation.call(
            step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
            actor: @target_actor,
            surface: "org",
            subject_public_id: @target.account.public_id,
            reservation_public_id: reservation.public_id,
          )
        end
      end
    end

    assert_equal "pending", reservation.reload.state
    assert_equal Float::INFINITY, source_period.reload.valid_to
    assert_equal Float::INFINITY, legacy_period.reload.valid_to
    assert_empty AvatarBureauOwnershipPeriod.where(avatar_id: @avatar.id).current
  end

  test "target owner accepts once and source selection no longer resolves the Avatar" do
    source_token = client_token_for(@source_actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: @source_actor, session: source_token)
    BaseSwitcherAuthority.switch(
      surface: :app,
      principal: @source_actor,
      session: source_token,
      params: selector_ids(@source, @avatar),
    )
    target_token = operator_token_for(@target_actor)
    BaseSelectorAuthority.prepare(surface: :org, principal: @target_actor, session: target_token)
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    transfer =
      ClientToken.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
          avatar_public_id: @avatar.public_id, target_surface: "org",
          target_collective_public_id: @target.collective.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end

    accepted =
      OperatorToken.transaction do
        AvatarOwnershipTransfers::AcceptOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          transfer_public_id: transfer.public_id,
          step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
        )
      end

    assert_equal "accepted", accepted.state
    assert_equal "org", @avatar.reload.current_ownership_period.owner_surface
    assert_empty @avatar.enterprise_ownership_periods.current
    assert_equal @target.collective.public_id, @avatar.bureau_ownership_periods.current.first.bureau_public_id
    assert_equal @target.collective.public_id, @avatar.current_ownership_period.owner_collective_public_id
    assert_equal accepted.accepted_at, @avatar.avatar_ownership_periods.order(:valid_from).last.valid_from
    assert_nil target_token.reload.selected_avatar_public_id
    assert_equal [], BaseSwitcherAuthority.current(
      surface: :app,
      principal: @source_actor,
      session: source_token,
    ).fetch(:candidates).select { |candidate| candidate.dig(:avatar, :public_id) == @avatar.public_id }

    candidates = BaseSwitcherAuthority.current(
      surface: :org,
      principal: @target_actor,
      session: target_token,
    ).fetch(:candidates)
    candidate = candidates.find { |entry| entry.dig(:avatar, :public_id) == @avatar.public_id }

    assert candidate

    BaseSwitcherAuthority.switch(
      surface: :org,
      principal: @target_actor,
      session: target_token,
      params: {
        account_public_id: candidate.fetch(:public_id),
        organization_public_id: candidate.dig(:organization, :public_id),
        organization_unit_public_id: candidate.dig(:organization, :unit_public_id),
        avatar_public_id: candidate.dig(:avatar, :public_id),
      },
    )

    assert_equal @avatar.public_id, target_token.reload.selected_avatar_public_id

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      OperatorToken.transaction do
        AvatarOwnershipTransfers::AcceptOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          transfer_public_id: transfer.public_id,
          step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
        )
      end
    end
  end

  test "org owner can transfer to app and target can subsequently select the Avatar" do
    @client_token_for_source = ClientToken.create!(
      authentication_epoch: 0,
      user: @source_actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    BaseSelectorAuthority.prepare(surface: :app, principal: @source_actor, session: @client_token_for_source)
    prior_selected_avatar_id = @client_token_for_source.reload.selected_avatar_public_id
    @source.avatar.current_avatar_persona_binding.revoke!(force: true)
    org_avatar_result = AvatarProvisioning::Create.call(
      actor: @target_actor,
      subject_type: :agent,
      subject: @target.account,
      avatar_params: { moniker: "Org owned Avatar" },
      handle_params: { handle: "org-owned-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: @target.collective.public_id,
    )

    assert_predicate org_avatar_result, :success?, org_avatar_result.errors.inspect
    avatar = org_avatar_result.avatar

    assert_equal @target.collective.public_id,
                 avatar.reload.bureau_ownership_periods.current.first.bureau_public_id
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    transfer =
      OperatorToken.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          avatar_public_id: avatar.public_id,
          target_surface: "app",
          target_collective_public_id: @source.collective.public_id,
          step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
        )
      end

    accepted =
      ClientToken.transaction do
        AvatarOwnershipTransfers::AcceptOperation.call(
          actor: @source_actor,
          surface: "app",
          subject_public_id: @source.account.public_id,
          transfer_public_id: transfer.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end

    assert_equal "accepted", accepted.state
    assert_equal "app", avatar.reload.current_ownership_period.owner_surface
    assert_empty avatar.bureau_ownership_periods.current
    assert_equal @source.collective.public_id, avatar.enterprise_ownership_periods.current.first.enterprise_public_id
    assert_equal @source.collective.public_id, avatar.current_ownership_period.owner_collective_public_id
    assert_equal prior_selected_avatar_id, @client_token_for_source.reload.selected_avatar_public_id
    candidate =
      BaseSwitcherAuthority.current(
        surface: :app,
        principal: @source_actor,
        session: @client_token_for_source,
      ).fetch(:candidates).find { |entry| entry.dig(:avatar, :public_id) == avatar.public_id }

    assert candidate
  end

  test "request rejects same owner, unsupported surface, and a member without permission" do
    step_up_now = OpBaseAppRecord.database_now
    step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: step_up_now + 1.hour,
    )
    step_up_token.update!(root_login_established_at: step_up_now, established_authentication_method: "passkey")
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.device_session_record!
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_auth_time = step_up_now.to_i - 1
    step_up_grant = OpAppGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch, client_token: step_up_token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 1.hour,
    )
    step_up_grant.issue_refresh_token!(now: step_up_now)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
      sid: step_up_grant.public_id, sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: step_up_client.client_id, aud: [step_up_client.aud], jti: step_up_grant.oidc_jti,
    )
    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "app",
            target_collective_public_id: @source.collective.public_id,
            step_up_token: step_up_token, step_up_evidence: step_up_evidence,
          )
        end
      end
    end

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "com",
            target_collective_public_id: @source.collective.public_id,
            step_up_token: step_up_token, step_up_evidence: step_up_evidence,
          )
        end
      end
    end

    membership = @source.account.persona_memberships.find_by!(enterprise: @source.collective)
    membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert_raises(AvatarOwnershipTransfers::Unauthorized) do
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            step_up_token: step_up_token, step_up_evidence: step_up_evidence,
          )
        end
      end
    end
    assert_equal 0, AvatarOwnershipTransfer.where(avatar: @avatar).count
  end

  test "expiry at the boundary is materialized and cannot transfer ownership" do
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    transfer =
      ClientToken.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
          avatar_public_id: @avatar.public_id, target_surface: "org",
          target_collective_public_id: @target.collective.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end

    travel_to transfer.expires_at, with_usec: true do
      assert_raises(AvatarOwnershipTransfers::Expired) do
        OperatorToken.transaction do
          AvatarOwnershipTransfers::AcceptOperation.call(
            actor: @target_actor,
            surface: "org",
            subject_public_id: @target.account.public_id,
            transfer_public_id: transfer.public_id,
            step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
          )
        end
      end
    end

    assert_equal "expired", transfer.reload.state
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
  end

  test "accept immediately before expiry remains valid" do
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    transfer =
      ClientToken.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
          avatar_public_id: @avatar.public_id, target_surface: "org",
          target_collective_public_id: @target.collective.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end
    travel_to(transfer.expires_at - 1.second, with_usec: true) do
      accepted =
        OperatorToken.transaction do
          AvatarOwnershipTransfers::AcceptOperation.call(
            actor: @target_actor,
            surface: "org",
            subject_public_id: @target.account.public_id,
            transfer_public_id: transfer.public_id,
            step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
          )
        end

      assert_equal "accepted", accepted.state
    end
    assert_equal "org", @avatar.reload.current_ownership_period.owner_surface
  end

  test "accept immediately after expiry records expired state and denies ownership change" do
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    transfer =
      ClientToken.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
          avatar_public_id: @avatar.public_id, target_surface: "org",
          target_collective_public_id: @target.collective.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end

    travel_to(transfer.expires_at + 1.second, with_usec: true) do
      assert_raises(AvatarOwnershipTransfers::Expired) do
        OperatorToken.transaction do
          AvatarOwnershipTransfers::AcceptOperation.call(
            actor: @target_actor,
            surface: "org",
            subject_public_id: @target.account.public_id,
            transfer_public_id: transfer.public_id,
            step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
          )
        end
      end
    end
    assert_equal "expired", transfer.reload.state
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
  end

  test "source owner can cancel but cannot replay a terminal transfer" do
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    transfer =
      ClientToken.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
          avatar_public_id: @avatar.public_id, target_surface: "org",
          target_collective_public_id: @target.collective.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end

    cancelled =
      ClientToken.transaction do
        AvatarOwnershipTransfers::CancelOperation.call(
          actor: @source_actor,
          surface: "app",
          subject_public_id: @source.account.public_id,
          transfer_public_id: transfer.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end

    assert_equal "cancelled", cancelled.state
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      ClientToken.transaction do
        AvatarOwnershipTransfers::CancelOperation.call(
          actor: @source_actor,
          surface: "app",
          subject_public_id: @source.account.public_id,
          transfer_public_id: transfer.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end
    end
  end

  test "transfer removes owner-mismatched group membership and preserves target-matched membership" do
    source_group = group_for(@source, surface: "app")
    target_group = group_for(@target, surface: "org")
    stale_membership = membership_for(source_group)
    matching_membership = membership_for(target_group)
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    transfer =
      ClientToken.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
          avatar_public_id: @avatar.public_id, target_surface: "org",
          target_collective_public_id: @target.collective.public_id,
          step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
        )
      end

    OperatorToken.transaction do
      AvatarOwnershipTransfers::AcceptOperation.call(
        actor: @target_actor,
        surface: "org",
        subject_public_id: @target.account.public_id,
        transfer_public_id: transfer.public_id,
        step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
      )
    end

    assert_equal "removed", stale_membership.reload.state
    assert_predicate stale_membership.removed_at, :present?
    assert_equal "active", matching_membership.reload.state
    assert_nil matching_membership.removed_at
  end

  test "transfer does not reinterpret a group's account context as Avatar ownership" do
    source_group = group_for(@source, surface: "app")
    target_group = group_for(@target, surface: "org")
    membership_for(source_group)
    membership_for(target_group)
    source_account = [source_group.account_surface, source_group.account_public_id]
    target_account = [target_group.account_surface, target_group.account_public_id]
    source_step_up_now = OpBaseAppRecord.database_now
    source_step_up_token = ClientToken.create!(
      authentication_epoch: @source_actor.authentication_epoch, user: @source_actor,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_step_up_now + 1.hour,
    )
    source_step_up_token.update!(
      root_login_established_at: source_step_up_now, established_authentication_method: "passkey",
    )
    source_step_up_token.rotate_refresh_token!(now: source_step_up_now)
    source_step_up_token.device_session_record!
    source_step_up_client = OidcClientRegistry.find!("base-app-ww")
    source_step_up_auth_time = source_step_up_now.to_i - 1
    source_step_up_grant = OpAppGrant.create!(
      authentication_epoch: source_step_up_token.authentication_epoch, client_token: source_step_up_token,
      oidc_client_id: source_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(source_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_step_up_now + 1.hour,
    )
    source_step_up_grant.issue_refresh_token!(now: source_step_up_now)
    source_step_up_evidence = StepUpEvidenceValue.new(
      acr: source_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: source_step_up_auth_time,
      sid: source_step_up_grant.public_id,
      sub: OidcSubject.for(@source_actor, resource_type: "client"),
      client_id: source_step_up_client.client_id, aud: [source_step_up_client.aud],
      jti: source_step_up_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar.public_id, target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
            request_fingerprint: Digest::SHA256.hexdigest(
              ["avatar_transfer", "app", @source_actor.public_id, @source.account.public_id,
               @avatar.public_id, "org", @target.collective.public_id,].join("\0"),
            ),
            step_up_token: source_step_up_token, step_up_evidence: source_step_up_evidence,
          )
        end
      end
    target_step_up_now = OpBaseOrgRecord.database_now
    target_step_up_token = OperatorToken.create!(
      authentication_epoch: @target_actor.authentication_epoch, staff: @target_actor,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: target_step_up_now + 1.hour,
    )
    target_step_up_token.update!(
      root_login_established_at: target_step_up_now, established_authentication_method: "passkey",
    )
    target_step_up_token.rotate_refresh_token!(now: target_step_up_now)
    target_step_up_token.device_session_record!
    target_step_up_client = OidcClientRegistry.find!("base-org-ww")
    target_step_up_auth_time = target_step_up_now.to_i - 1
    target_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: target_step_up_token.authentication_epoch, operator_token: target_step_up_token,
      oidc_client_id: target_step_up_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(target_step_up_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: target_step_up_now + 1.hour,
    )
    target_step_up_grant.issue_refresh_token!(now: target_step_up_now)
    target_step_up_evidence = StepUpEvidenceValue.new(
      acr: target_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: target_step_up_auth_time,
      sid: target_step_up_grant.public_id,
      sub: OidcSubject.for(@target_actor, resource_type: "operator"),
      client_id: target_step_up_client.client_id, aud: [target_step_up_client.aud],
      jti: target_step_up_grant.oidc_jti,
    )

    OperatorToken.transaction do
      AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: @target_actor,
        surface: "org",
        subject_public_id: @target.account.public_id,
        reservation_public_id: reservation.public_id,
        step_up_token: target_step_up_token, step_up_evidence: target_step_up_evidence,
      )
    end

    assert_equal source_account, [source_group.reload.account_surface, source_group.account_public_id]
    assert_equal target_account, [target_group.reload.account_surface, target_group.account_public_id]
    assert_equal "org", @avatar.reload.current_ownership_period.owner_surface
    assert_equal "removed", source_group.group_avatar_memberships.first.reload.state
    assert_equal "active", target_group.group_avatar_memberships.first.reload.state
  end

  private

  def registry_request_fingerprint(actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
                                   avatar_public_id: @avatar.public_id, target_surface: "org",
                                   target_collective_public_id: @target.collective.public_id)
    Digest::SHA256.hexdigest(
      [
        "avatar_transfer", surface, actor.public_id, subject_public_id, avatar_public_id,
        target_surface, target_collective_public_id,
      ].join("\0"),
    )
  end

  def group_for(bootstrap, surface:)
    group = AvatarGroup.create!(
      account_surface: surface,
      account_public_id: bootstrap.account.public_id,
      name: "#{surface}-group-#{SecureRandom.hex(4)}",
      state: "active",
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: surface,
      owner_collective_public_id: bootstrap.collective.public_id,
      valid_from: Time.current,
    )
    group
  end

  def membership_for(group)
    GroupAvatarMembership.create!(
      avatar_group: group,
      avatar: @avatar,
      role: GroupAvatarMembership::ROLE,
      position: 0,
      state: "active",
    )
  end

  def client_token_for(actor)
    ClientToken.create!(authentication_epoch: 0, user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  def operator_token_for(actor)
    OperatorToken.create!(authentication_epoch: 0, staff: actor, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  def selector_ids(bootstrap, avatar)
    {
      account_public_id: bootstrap.account.public_id,
      organization_public_id: bootstrap.collective.public_id,
      organization_unit_public_id: bootstrap.unit.public_id,
      avatar_public_id: avatar.public_id,
    }
  end
end
