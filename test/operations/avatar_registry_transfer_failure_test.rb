# frozen_string_literal: true

require "test_helper"

class AvatarRegistryTransferFailureTest < ActiveSupport::TestCase
  [["app", "app"], ["app", "org"], ["org", "app"], ["org", "org"]].each do |source_surface, target_surface|
    test "#{source_surface} to #{target_surface} transfer rolls back a destination write failure and retries once" do
      source_actor =
        case source_surface
        when "app" then Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
        )
        when "org" then Operator.create!(
          security_mode_id: SecurityModeConfigurable::ADVANCED,
          status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
        )
        else raise ArgumentError, "unsupported source"
        end
      target_actor =
        case target_surface
        when "app" then Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
        )
        when "org" then Operator.create!(
          security_mode_id: SecurityModeConfigurable::ADVANCED,
          status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
        )
        else raise ArgumentError, "unsupported destination"
        end
      source = BaseSelectorBootstrapAuthority.call(surface: source_surface.to_sym, principal: source_actor)
      target = BaseSelectorBootstrapAuthority.call(surface: target_surface.to_sym, principal: target_actor)
      source_token, source_evidence = step_up_for(source_actor, source_surface)
      target_token, target_evidence = step_up_for(target_actor, target_surface)
      avatar =
        case source_surface
        when "app" then source.avatar
        when "org"
          provision = AvatarProvisioning::Create.call(
            actor: source_actor, subject_type: :agent, subject: source.account,
            avatar_params: { moniker: "Failure source" },
            handle_params: { handle: "transfer-failure-#{SecureRandom.hex(4)}" },
            owner_surface: "org", owner_collective_public_id: source.collective.public_id,
          )

          assert_predicate provision, :success?, provision.errors.inspect
          provision.avatar
        else raise ArgumentError, "unsupported source"
        end
      reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
        actor: source_actor, surface: source_surface, subject_public_id: source.account.public_id,
        avatar_public_id: avatar.public_id, target_surface: target_surface,
        target_collective_public_id: target.collective.public_id, idempotency_key: SecureRandom.uuid,
        request_fingerprint: Digest::SHA256.hexdigest(
          ["avatar_transfer", source_surface, source_actor.public_id, source.account.public_id,
           avatar.public_id, target_surface, target.collective.public_id,].join("\0"),
        ),
        step_up_token: source_token,
        step_up_evidence: source_evidence,
      )
      before_reservation = reservation.attributes
      before_legacy = avatar.avatar_ownership_periods.order(:id).map(&:attributes)
      before_enterprise = avatar.enterprise_ownership_periods.order(:id).map(&:attributes)
      before_bureau = avatar.bureau_ownership_periods.order(:id).map(&:attributes)
      destination_model =
        case target_surface
        when "app" then AvatarEnterpriseOwnershipPeriod
        when "org" then AvatarBureauOwnershipPeriod
        else raise ArgumentError, "unsupported destination"
        end

      # The public persistence boundary fails after the operation has closed the old periods.
      # The operation and every earlier SQL write execute normally inside the real transaction.
      destination_model.stub(
        :create!, ->(**) {
                    raise ActiveRecord::StatementInvalid, "synthetic destination failure"
                  },
      ) do
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarOwnershipTransfers::RegistryAcceptOperation.call(
            actor: target_actor, surface: target_surface, subject_public_id: target.account.public_id,
            reservation_public_id: reservation.public_id,
            step_up_token: target_token, step_up_evidence: target_evidence,
          )
        end
      end

      assert_equal before_reservation, reservation.reload.attributes
      assert_equal before_legacy, AvatarOwnershipPeriod.where(avatar_id: avatar.id).order(:id).map(&:attributes)
      assert_equal before_enterprise,
                   AvatarEnterpriseOwnershipPeriod.where(avatar_id: avatar.id).order(:id).map(&:attributes)
      assert_equal before_bureau,
                   AvatarBureauOwnershipPeriod.where(avatar_id: avatar.id).order(:id).map(&:attributes)
      assert_equal source.collective.public_id, avatar.reload.current_ownership_period.owner_collective_public_id

      accepted = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: target_actor, surface: target_surface, subject_public_id: target.account.public_id,
        reservation_public_id: reservation.public_id,
        step_up_token: target_token, step_up_evidence: target_evidence,
      )

      assert_equal "accepted", accepted.state
      assert_equal target.collective.public_id, avatar.reload.current_ownership_period.owner_collective_public_id
      committed = accepted.attributes
      period_counts = [avatar.enterprise_ownership_periods.count, avatar.bureau_ownership_periods.count]

      replay = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: target_actor, surface: target_surface, subject_public_id: target.account.public_id,
        reservation_public_id: reservation.public_id,
      )

      assert_equal committed, replay.attributes
      assert_equal period_counts, [avatar.enterprise_ownership_periods.count, avatar.bureau_ownership_periods.count]
    end
  end

  private

  def step_up_for(actor, surface)
    app = surface == "app"
    token_class = app ? ClientToken : OperatorToken
    grant_class = app ? OpAppGrant : OpOrgGrant
    record_class = app ? OpBaseAppRecord : OpBaseOrgRecord
    client = OidcClientRegistry.find!("base-#{surface}-ww")
    now = record_class.database_now
    owner_key = app ? :user : :staff
    token = token_class.create!(
      :authentication_epoch => actor.authentication_epoch,
      owner_key => actor,
      :root_login_established_at => now,
      :discard_at => now + 1.hour,
      **(app ? {} : { authentication_context: AuthenticationContextValue::NORMAL_KEY }),
    )
    token.rotate_refresh_token!(now:)
    device = token.device_session_record!
    auth_time = now.to_time.to_i - 1
    grant_owner = app ? :client_token : :operator_token
    grant = grant_class.create!(
      :authentication_epoch => token.authentication_epoch, grant_owner => token,
      :device_session_id => device.id, :oidc_client_id => client.client_id, :oidc_scope => "openid profile",
      :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
      :oidc_auth_time => Time.at(auth_time).utc, :oidc_acr => StepUpEvidenceResolver::STEP_UP_ACR,
      :oidc_amr => JSON.generate(["passkey"]), :refresh_token_expires_at => now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time:, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: app ? "client" : "operator"),
      client_id: client.client_id, aud: [client.aud], jti: grant.oidc_jti,
    )
    [token, evidence]
  end
end
