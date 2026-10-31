# frozen_string_literal: true

require "test_helper"

class OpIdentityEventInvalidatorTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @client = clients(:one)
    @client.update_columns(authentication_epoch: 0)
  end

  test "recording a stop advances the actor epoch and appends one Zenith event in the actor transaction" do
    event = record_stop

    assert_equal 1, @client.reload.authentication_epoch
    assert_equal [@client.id.to_s, "app", 1, "withdrawal_suspend", "all_sessions"],
                 [event.actor_ref, event.realm, event.cutoff_epoch, event.reason, event.scope]
  end

  test "unsupported stop scope is refused before recording or advancing the actor" do
    old_epoch = @client.reload.authentication_epoch

    [nil, "", "one_session", 0, false].each do |scope|
      assert_no_difference -> { AppIdentityAuthenticationEvent.count } do
        assert_raises(ArgumentError) do
          Client.transaction do
            @client.lock!
            IdentityAuthenticationStopRecorder.call(actor: @client, reason: "withdrawal_suspend", scope:)
          end
        end
      end

      assert_equal old_epoch, @client.reload.authentication_epoch
    end
  end

  test "unsupported stop reason is refused before recording or advancing the actor" do
    old_epoch = @client.reload.authentication_epoch

    [nil, "", "unregistered_reason", 0, false, :access_lock].each do |reason|
      assert_no_difference -> { AppIdentityAuthenticationEvent.count } do
        Client.transaction do
          @client.lock!
          assert_raises(ArgumentError) do
            IdentityAuthenticationStopRecorder.call(actor: @client, reason:)
          end
        end
      end

      assert_equal old_epoch, @client.reload.authentication_epoch
    end
  end

  test "unsupported APP stop scope cannot revoke all roots" do
    root = ClientToken.create!(user: @client, authentication_epoch: 0)
    event = record_stop
    event.update!(scope: "one_session")

    assert_raises(ArgumentError) { OpIdentityEventInvalidator.call(event:) }
    assert_not_predicate root.reload, :revoked?
    assert_not OpAppInboundEventReceipt.exists?(event_id: event.event_id)
    assert_not OpAppAuthorityStop.exists?(authority_evidence_ref: event.event_id)
  end

  test "an APP stop claiming the ORG realm is refused before writing" do
    root = ClientToken.create!(user: @client, authentication_epoch: 0)
    event = record_stop
    event.realm = "org"

    assert_raises(ArgumentError) { OpIdentityEventInvalidator.call(event:) }
    assert_not_predicate root.reload, :revoked?
    assert_not OpAppInboundEventReceipt.exists?(event_id: event.event_id)
    assert_not OpAppAuthorityStop.exists?(authority_evidence_ref: event.event_id)
  end

  test "unsupported ORG stop scope cannot revoke all roots" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    root = OperatorToken.create!(staff: operator, authentication_epoch: 0)
    event =
      Operator.transaction do
        operator.lock!
        IdentityAuthenticationStopRecorder.call(actor: operator, reason: "administrative_access_lock")
      end
    event.update!(scope: "one_session")

    assert_raises(ArgumentError) { OpIdentityEventInvalidator.call(event:) }
    assert_not_predicate root.reload, :revoked?
    assert_not OpOrgInboundEventReceipt.exists?(event_id: event.event_id)
    assert_not OpOrgAuthorityStop.exists?(authority_evidence_ref: event.event_id)
  end

  test "applying the event revokes roots issued before the cutoff, including unrecorded ones" do
    old_root = ClientToken.create!(user: @client, authentication_epoch: 0)
    legacy_root = ClientToken.create!(authentication_epoch: 0, user: @client)
    event = record_stop

    assert_equal :applied, OpIdentityEventInvalidator.call(event:)
    assert_predicate old_root.reload, :revoked?
    assert_predicate legacy_root.reload, :revoked?
  end

  test "identity invalidation repairs live grants under an already revoked legacy root" do
    legacy_root = ClientToken.create!(user: @client, authentication_epoch: 0)
    grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: legacy_root,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid",
      refresh_token_expires_at: 1.hour.from_now,
    )
    legacy_root.revoke!
    event = record_stop

    assert_equal :applied, OpIdentityEventInvalidator.call(event:)

    stop = OpAppAuthorityStop.find_by!(authority_evidence_ref: event.event_id)

    assert_predicate legacy_root.reload, :revoked?
    assert_predicate grant.reload, :revoked?
    assert OpAppAuthorityStopRootTarget.exists?(stop:, root: legacy_root)
    assert OpAppAuthorityStopGrantTarget.exists?(stop:, grant:)
    assert_equal 1, OpAppAuthorityStopParticipant.where(stop:).count
  end

  test "a delayed stop event never revokes a root established after recovery under a newer epoch" do
    event = record_stop
    recovered_root = ClientToken.create!(user: @client, authentication_epoch: 1)

    OpIdentityEventInvalidator.call(event:)

    assert_not_predicate recovered_root.reload, :revoked?
  end

  test "the same event is applied once; a redelivery is a duplicate" do
    event = record_stop

    assert_equal :applied, OpIdentityEventInvalidator.call(event:)
    assert_equal :duplicate, OpIdentityEventInvalidator.call(event:)
    assert_equal 1, OpAppInboundEventReceipt.where(event_id: event.event_id).count
  end

  %i(issuer client_id).each do |different_field|
    test "a different #{different_field} receipt cannot suppress an identity stop" do
      root = ClientToken.create!(user: @client, authentication_epoch: 0)
      event = record_stop
      sender = {
        event_id: event.event_id,
        issuer: OidcIssuer.for_resource_type("client"),
        realm: "app",
        client_id: "base-app-ww",
        event_type: "identity_authentication_stop",
        committed_at: event.committed_at,
      }
      sender[different_field] = (different_field == :issuer) ? "https://other-issuer.example.test" : "other-client"
      foreign = OpAppInboundEventReceipt.create!(sender)

      assert_equal :applied, OpIdentityEventInvalidator.call(event:)
      assert_predicate root.reload, :revoked?
      assert_predicate foreign.reload, :persisted?
      assert_equal 2, OpAppInboundEventReceipt.where(event_id: event.event_id).count
    end
  end

  %i(event_type committed_at).each do |different_field|
    test "a same-sender receipt with conflicting #{different_field} is not a duplicate" do
      root = ClientToken.create!(user: @client, authentication_epoch: 0)
      event = record_stop
      sender = {
        event_id: event.event_id,
        issuer: OidcIssuer.for_resource_type("client"),
        realm: "app",
        client_id: "base-app-ww",
        event_type: "identity_authentication_stop",
        committed_at: event.committed_at,
      }
      sender[different_field] = (different_field == :event_type) ? "other_event" : event.committed_at - 1.second
      OpAppInboundEventReceipt.create!(sender)

      assert_raises(ArgumentError) { OpIdentityEventInvalidator.call(event:) }
      assert_not_predicate root.reload, :revoked?
      assert_equal 1, OpAppInboundEventReceipt.where(event_id: event.event_id).count
    end
  end

  test "a different ORG sender cannot suppress an operator stop" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    root = OperatorToken.create!(staff: operator, authentication_epoch: 0)
    event =
      Operator.transaction do
        operator.lock!
        IdentityAuthenticationStopRecorder.call(actor: operator, reason: "administrative_access_lock")
      end
    foreign = OpOrgInboundEventReceipt.create!(
      event_id: event.event_id, issuer: OidcIssuer.for_resource_type("operator"), realm: "org",
      client_id: "other-client", event_type: "identity_authentication_stop", committed_at: event.committed_at,
    )

    assert_equal :applied, OpIdentityEventInvalidator.call(event:)
    assert_predicate root.reload, :revoked?
    assert_predicate foreign.reload, :persisted?
    assert_equal 2, OpOrgInboundEventReceipt.where(event_id: event.event_id).count
  end

  %i(actor cutoff reason scope).each do |fact|
    test "a duplicate receipt cannot hide a changed source #{fact}" do
      event = record_stop

      assert_equal :applied, OpIdentityEventInvalidator.call(event:)
      replacement = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      case fact
      when :actor then event.update!(actor_ref: replacement.id.to_s)
      when :cutoff then event.update!(cutoff_epoch: event.cutoff_epoch + 1)
      when :reason then event.update!(reason: "sign_risk")
      when :scope then event.update!(scope: "other_scope")
      end

      assert_raises(ArgumentError) { OpIdentityEventInvalidator.call(event:) }
    end
  end

  test "an ORG duplicate receipt cannot hide a changed cutoff" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    event =
      Operator.transaction do
        operator.lock!
        IdentityAuthenticationStopRecorder.call(actor: operator, reason: "administrative_access_lock")
      end

    assert_equal :applied, OpIdentityEventInvalidator.call(event:)
    event.update!(cutoff_epoch: event.cutoff_epoch + 1)

    assert_raises(ArgumentError) { OpIdentityEventInvalidator.call(event:) }
  end

  test "an unsupported persisted event reason fails before recording an OP receipt or revoking roots" do
    root = ClientToken.create!(user: @client, authentication_epoch: 0)
    event = record_stop
    event.update!(reason: "unsupported_reason")

    assert_raises(ArgumentError) { OpIdentityEventInvalidator.call(event:) }
    assert_not_predicate root.reload, :revoked?
    assert_equal 0, OpAppInboundEventReceipt.where(event_id: event.event_id).count
  end

  test "an unavailable OP leaves a durable retry instead of losing the stop" do
    event = record_stop

    OpIdentityEventInvalidator.stub(:call, ->(**) { raise ActiveRecord::ConnectionNotEstablished }) do
      assert_enqueued_with(job: OpIdentityEventDeliveryJob, args: [event.class.name, event.id]) do
        assert_equal :enqueued, OpIdentityEventInvalidator.deliver(event:)
      end
    end
  end

  test "a refused retry enqueue is not reported as enqueued" do
    root = ClientToken.create!(user: @client, authentication_epoch: 0)
    event = record_stop

    OpIdentityEventInvalidator.stub(:call, ->(**) { raise ActiveRecord::ConnectionNotEstablished }) do
      OpIdentityEventDeliveryJob.stub(:perform_later, false) do
        assert_raises(ActiveJob::EnqueueError) { OpIdentityEventInvalidator.deliver(event:) }
      end
    end

    assert AppIdentityAuthenticationEvent.exists?(id: event.id)
    assert_not OpAppInboundEventReceipt.exists?(event_id: event.event_id)

    OpIdentityEventSweepJob.perform_now

    assert OpAppInboundEventReceipt.exists?(event_id: event.event_id)
    assert_predicate root.reload, :revoked?
  end

  private

  include ActiveJob::TestHelper

  def record_stop
    Client.transaction do
      @client.lock!
      IdentityAuthenticationStopRecorder.call(actor: @client, reason: "withdrawal_suspend")
    end
  end
end
