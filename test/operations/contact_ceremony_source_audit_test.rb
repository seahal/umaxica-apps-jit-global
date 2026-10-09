# frozen_string_literal: true

require "test_helper"

class ContactCeremonySourceAuditTest < ActiveSupport::TestCase
  uses_transaction :test_concurrent_signed_email_finalization_keeps_one_effective_destination_in_app_and_com
  uses_transaction :test_concurrent_signed_telephone_finalization_keeps_one_effective_destination_in_app_and_com
  uses_transaction :test_concurrent_signed_finalization_keeps_one_effective_Contact_per_actor_in_both_realms

  test "concurrent signed email finalization keeps one effective destination in app and com" do
    [
      [Client, ClientEmail, ClientEmailCeremonyTransaction, ClientContactAuditOutbox, :user_id, "app"],
      [Visitor, VisitorEmail, VisitorEmailCeremonyTransaction, VisitorContactAuditOutbox, :visitor_id, "com"],
    ].each do |actor_class, contact_class, transaction_class, outbox_class, owner_key, surface|
      actors = []
      contacts = []
      transactions = []
      destination = "concurrent-#{surface}-#{SecureRandom.hex(12)}@example.test"
      attempts =
        2.times.map do
          actor = actor_class.create!
          actors << actor
          contact = contact_class.create!(owner_key => actor.id, :address => destination, :confirm_policy => "1")
          contacts << contact
          now = transaction_class.database_now
          transaction = transaction_class.create_transaction!(
            actor_ref: actor.public_id, session_ref: "contact-race-#{SecureRandom.uuid}",
            operation: "registration", email_candidate_ref: contact.public_id,
            normalized_email_digest: contact.address_digest, now: now,
          )
          transactions << transaction
          result = IdentityEmailCeremonyResult.issue(
            { surface: surface,
              actor_ref: actor.public_id,
              session_ref: transaction.session_ref,
              transaction_id: transaction.transaction_id,
              grant_jti: transaction.grant_jti,
              result_jti: SecureRandom.uuid,
              operation: transaction.operation,
              verified_at: now.to_i,
              challenge_id: SecureRandom.uuid,
              expires_at: transaction.expires_at.to_i,
              email_candidate_ref: contact.public_id,
              normalized_email_digest: contact.address_digest, },
            issuer_id: IdentityEmailCeremonyContract.sign_issuer_id(surface), now: now,
          )
          [actor.id, transaction.id, result, now]
        end

      ready = Queue.new
      release = Queue.new
      outcomes = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        attempts.map do |actor_id, transaction_id, result, now|
          Thread.new do
            contact_class.connection_pool.with_connection do |connection|
              backend_pid = connection.select_value("SELECT pg_backend_pid()")
              ready << backend_pid
              release.pop
              actor = actor_class.find(actor_id)
              transaction = transaction_class.find(transaction_id)
              context = ActorValuesContext.empty.with(
                subject: actor, actor_type: (surface == "app") ? :client : :visitor,
                tld: surface.to_sym, surface: :base,
              )
              IdentityEmailCeremonyFinalCommitter.call!(
                result_token: result, actor_context: context, actor: actor,
                session_ref: transaction.session_ref, surface: surface, now: now,
              )
              outcomes << :finalized
            rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
              outcomes << e.class
            rescue StandardError => e
              outcomes << e
            end
          end
        end
      backends = 2.times.map { ready.pop }
      2.times { release << true }
      threads.each(&:join)
      results = 2.times.map { outcomes.pop }

      assert_equal 2, backends.uniq.length, "#{surface}: separate database connections must race"
      assert_equal 1, results.count(:finalized), "#{surface}: #{results.map(&:class).inspect}"
      assert_equal 1, results.count { |result|
        [ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid].include?(result)
      }, "#{surface}: only one signed finalizer may win"
      assert_equal 1, contact_class.effective_binding.where(address_digest: contacts.first.address_digest).count
      assert_equal 1, outbox_class.where(operation_ref: transactions.map(&:transaction_id)).count
      assert_equal 1, contacts.count { |contact| contact.reload.binding_effective? }
    ensure
      outbox_class.where(operation_ref: transactions.map(&:transaction_id)).delete_all if transactions.any?
      transaction_class.where(id: transactions.map(&:id)).delete_all if transactions.any?
      contact_class.where(id: contacts.map(&:id)).delete_all if contacts.any?
      actor_class.where(id: actors.map(&:id)).delete_all if actors.any?
    end
  end

  test "concurrent signed telephone finalization keeps one effective destination in app and com" do
    [
      [Client, ClientTelephone, ClientTelephoneCeremonyTransaction, ClientContactAuditOutbox, :user_id, "app"],
      [Visitor, VisitorTelephone, VisitorTelephoneCeremonyTransaction, VisitorContactAuditOutbox, :visitor_id, "com"],
    ].each do |actor_class, contact_class, transaction_class, outbox_class, owner_key, surface|
      actors = []
      contacts = []
      transactions = []
      destination = "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
      attempts =
        2.times.map do
          actor = actor_class.create!
          actors << actor
          contact = contact_class.create!(owner_key => actor.id, :number => destination, :confirm_policy => "1")
          contacts << contact
          now = transaction_class.database_now
          transaction = transaction_class.create_transaction!(
            actor_ref: actor.public_id, session_ref: "telephone-race-#{SecureRandom.uuid}",
            operation: "registration", telephone_candidate_ref: contact.public_id,
            normalized_number_digest: contact.number_digest, now: now,
          )
          transactions << transaction
          result = IdentityTelephoneCeremonyResult.issue(
            { surface: surface,
              actor_ref: actor.public_id,
              session_ref: transaction.session_ref,
              transaction_id: transaction.transaction_id,
              grant_jti: transaction.grant_jti,
              result_jti: SecureRandom.uuid,
              operation: transaction.operation,
              verified_at: now.to_i,
              challenge_id: SecureRandom.uuid,
              expires_at: transaction.expires_at.to_i,
              telephone_candidate_ref: contact.public_id,
              normalized_number_digest: contact.number_digest, },
            issuer_id: IdentityTelephoneCeremonyContract.sign_issuer_id(surface), now: now,
          )
          [actor.id, transaction.id, result, now]
        end

      ready = Queue.new
      release = Queue.new
      outcomes = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        attempts.map do |actor_id, transaction_id, result, now|
          Thread.new do
            contact_class.connection_pool.with_connection do |connection|
              backend_pid = connection.select_value("SELECT pg_backend_pid()")
              ready << backend_pid
              release.pop
              actor = actor_class.find(actor_id)
              transaction = transaction_class.find(transaction_id)
              context = ActorValuesContext.empty.with(
                subject: actor, actor_type: (surface == "app") ? :client : :visitor,
                tld: surface.to_sym, surface: :base,
              )
              IdentityTelephoneCeremonyFinalCommitter.call!(
                result_token: result, actor_context: context, actor: actor,
                session_ref: transaction.session_ref, surface: surface, now: now,
              )
              outcomes << :finalized
            rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
              outcomes << e.class
            rescue StandardError => e
              outcomes << e
            end
          end
        end
      backends = 2.times.map { ready.pop }
      2.times { release << true }
      threads.each(&:join)
      results = 2.times.map { outcomes.pop }

      assert_equal 2, backends.uniq.length, "#{surface}: separate database connections must race"
      assert_equal 1, results.count(:finalized), "#{surface}: #{results.map(&:class).inspect}"
      assert_equal 1, results.count { |result|
        [ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid].include?(result)
      }, "#{surface}: only one signed finalizer may win"
      assert_equal 1, contact_class.effective_binding.where(number_digest: contacts.first.number_digest).count
      assert_equal 1, outbox_class.where(operation_ref: transactions.map(&:transaction_id)).count
      assert_equal 1, contacts.count { |contact| contact.reload.binding_effective? }
    ensure
      outbox_class.where(operation_ref: transactions.map(&:transaction_id)).delete_all if transactions.any?
      transaction_class.where(id: transactions.map(&:id)).delete_all if transactions.any?
      contact_class.where(id: contacts.map(&:id)).delete_all if contacts.any?
      actor_class.where(id: actors.map(&:id)).delete_all if actors.any?
    end
  end

  test "concurrent signed finalization keeps one effective Contact per actor in both realms" do
    [
      [Client, ClientEmail, ClientEmailCeremonyTransaction, ClientContactAuditOutbox, :user_id, "app", :email],
      [Visitor, VisitorEmail, VisitorEmailCeremonyTransaction, VisitorContactAuditOutbox, :visitor_id, "com", :email],
      [Client, ClientTelephone, ClientTelephoneCeremonyTransaction, ClientContactAuditOutbox, :user_id, "app",
       :telephone,],
      [Visitor, VisitorTelephone, VisitorTelephoneCeremonyTransaction, VisitorContactAuditOutbox, :visitor_id, "com",
       :telephone,],
    ].each do |actor_class, contact_class, transaction_class, outbox_class, owner_key, surface, kind|
      actor = actor_class.create!
      contacts = []
      transactions = []
      attempts =
        2.times.map do |index|
          destination =
            if kind == :email
              "owner-race-#{surface}-#{SecureRandom.hex(12)}-#{index}@example.test"
            else
              "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
            end
          contact_attributes = { owner_key => actor.id,
                                 :confirm_policy => "1",
                                 (kind == :email) ? :address : :number => destination, }
          contact = contact_class.create!(contact_attributes)
          contacts << contact
          now = transaction_class.database_now
          candidate_ref = (kind == :email) ? :email_candidate_ref : :telephone_candidate_ref
          digest_key = (kind == :email) ? :normalized_email_digest : :normalized_number_digest
          digest = (kind == :email) ? contact.address_digest : contact.number_digest
          transaction = transaction_class.create_transaction!(
            :actor_ref => actor.public_id, :session_ref => "owner-race-#{SecureRandom.uuid}",
            :operation => "registration", candidate_ref => contact.public_id, digest_key => digest, :now => now,
          )
          transactions << transaction
          claims = {
            :surface => surface,
            :actor_ref => actor.public_id,
            :session_ref => transaction.session_ref,
            :transaction_id => transaction.transaction_id,
            :grant_jti => transaction.grant_jti,
            :result_jti => SecureRandom.uuid,
            :operation => transaction.operation,
            :verified_at => now.to_i,
            :challenge_id => SecureRandom.uuid,
            :expires_at => transaction.expires_at.to_i,
            candidate_ref => contact.public_id,
            digest_key => digest,
          }
          result =
            if kind == :email
              IdentityEmailCeremonyResult.issue(
                claims, issuer_id: IdentityEmailCeremonyContract.sign_issuer_id(surface), now: now,
              )
            else
              IdentityTelephoneCeremonyResult.issue(
                claims, issuer_id: IdentityTelephoneCeremonyContract.sign_issuer_id(surface), now: now,
              )
            end
          [transaction.id, result, now]
        end

      ready = Queue.new
      release = Queue.new
      outcomes = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        attempts.map do |transaction_id, result, now|
          Thread.new do
            contact_class.connection_pool.with_connection do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              current_actor = actor_class.find(actor.id)
              transaction = transaction_class.find(transaction_id)
              context = ActorValuesContext.empty.with(
                subject: current_actor, actor_type: (surface == "app") ? :client : :visitor,
                tld: surface.to_sym, surface: :base,
              )
              finalizer =
                if kind == :email
                  IdentityEmailCeremonyFinalCommitter
                else
                  IdentityTelephoneCeremonyFinalCommitter
                end
              finalizer.call!(
                result_token: result, actor_context: context, actor: current_actor,
                session_ref: transaction.session_ref, surface: surface, now: now,
              )
              outcomes << :finalized
            rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
              outcomes << e.class
            rescue StandardError => e
              outcomes << e
            end
          end
        end
      backends = 2.times.map { ready.pop }
      2.times { release << true }
      threads.each(&:join)
      results = 2.times.map { outcomes.pop }

      assert_equal 2, backends.uniq.length, "#{surface}/#{kind}: separate database connections must race"
      assert_equal 1, results.count(:finalized), "#{surface}/#{kind}: #{results.map(&:class).inspect}"
      assert_equal 1, results.count { |result|
        [ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid].include?(result)
      }, "#{surface}/#{kind}: only one signed finalizer may win"
      assert_equal 1, contact_class.effective_binding.where(owner_key => actor.id).count
      assert_equal 1, outbox_class.where(operation_ref: transactions.map(&:transaction_id)).count
      assert_equal 1, contacts.count { |contact| contact.reload.binding_effective? }
    ensure
      outbox_class.where(operation_ref: transactions.map(&:transaction_id)).delete_all if transactions.any?
      transaction_class.where(id: transactions.map(&:id)).delete_all if transactions.any?
      contact_class.where(id: contacts.map(&:id)).delete_all if contacts.any?
      actor_class.where(id: actor.id).delete_all if actor
    end
  end

  test "a signed email result cannot substitute another candidate of the same Ticket owner" do
    [
      [Client, ClientEmail, :user_id, ClientEmailCeremonyTransaction, ClientContactAuditOutbox, "app"],
      [Visitor, VisitorEmail, :visitor_id, VisitorEmailCeremonyTransaction, VisitorContactAuditOutbox, "com"],
    ].each do |owner_class, contact_class, owner_key, transaction_class, outbox_class, surface|
      owner = owner_class.create!
      original = contact_class.create!(
        owner_key => owner.id, :address => "original@example.test",
        :confirm_policy => "1",
      )
      substitute = contact_class.create!(
        owner_key => owner.id, :address => "substitute@example.test",
        :confirm_policy => "1",
      )
      context = ActorValuesContext.empty.with(
        subject: owner, actor_type: (surface == "app") ? :client : :visitor, tld: surface.to_sym, surface: :base,
      )
      now = transaction_class.database_now
      parent = transaction_class.create_transaction!(
        actor_ref: owner.public_id, session_ref: "candidate-browser", operation: "registration",
        email_candidate_ref: original.public_id, normalized_email_digest: original.address_digest, now: now,
      )
      signed_result = IdentityEmailCeremonyResult.issue(
        { surface: surface,
          actor_ref: owner.public_id,
          session_ref: parent.session_ref,
          transaction_id: parent.transaction_id,
          grant_jti: parent.grant_jti,
          result_jti: SecureRandom.uuid,
          operation: parent.operation,
          verified_at: now.to_i,
          challenge_id: SecureRandom.uuid,
          expires_at: parent.expires_at.to_i,
          email_candidate_ref: substitute.public_id,
          normalized_email_digest: substitute.address_digest, },
        issuer_id: IdentityEmailCeremonyContract.sign_issuer_id(surface), now: now,
      )
      error =
        assert_raises(IdentityEmailCeremonyContract::Error) do
          IdentityEmailCeremonyFinalCommitter.call!(
            result_token: signed_result, actor_context: context, actor: owner,
            session_ref: parent.session_ref, surface: surface, now: now,
          )
        end
      assert_equal "email result candidate does not match Ticket", error.message
      assert_not parent.reload.consumed?
      assert_not original.reload.binding_effective?
      assert_not substitute.reload.binding_effective?
      assert_not outbox_class.exists?(operation_ref: parent.transaction_id)
    end
  end

  test "a signed telephone result cannot substitute another candidate of the same Ticket owner" do
    [
      [Client, ClientTelephone, :user_id, ClientTelephoneCeremonyTransaction, ClientContactAuditOutbox, "app"],
      [Visitor, VisitorTelephone, :visitor_id, VisitorTelephoneCeremonyTransaction, VisitorContactAuditOutbox, "com"],
    ].each do |owner_class, contact_class, owner_key, transaction_class, outbox_class, surface|
      owner = owner_class.create!
      original = contact_class.create!(owner_key => owner.id, :number => "+819012345684", :confirm_policy => "1")
      substitute = contact_class.create!(owner_key => owner.id, :number => "+819012345685", :confirm_policy => "1")
      context = ActorValuesContext.empty.with(
        subject: owner, actor_type: (surface == "app") ? :client : :visitor, tld: surface.to_sym, surface: :base,
      )
      now = transaction_class.database_now
      parent = transaction_class.create_transaction!(
        actor_ref: owner.public_id, session_ref: "candidate-browser", operation: "registration",
        telephone_candidate_ref: original.public_id, normalized_number_digest: original.number_digest, now: now,
      )
      signed_result = IdentityTelephoneCeremonyResult.issue(
        { surface: surface,
          actor_ref: owner.public_id,
          session_ref: parent.session_ref,
          transaction_id: parent.transaction_id,
          grant_jti: parent.grant_jti,
          result_jti: SecureRandom.uuid,
          operation: parent.operation,
          verified_at: now.to_i,
          challenge_id: SecureRandom.uuid,
          expires_at: parent.expires_at.to_i,
          telephone_candidate_ref: substitute.public_id,
          normalized_number_digest: substitute.number_digest, },
        issuer_id: IdentityTelephoneCeremonyContract.sign_issuer_id(surface), now: now,
      )
      error =
        assert_raises(IdentityTelephoneCeremony::Error) do
          IdentityTelephoneCeremonyFinalCommitter.call!(
            result_token: signed_result, actor_context: context, actor: owner,
            session_ref: parent.session_ref, surface: surface, now: now,
          )
        end
      assert_equal "telephone result candidate does not match Ticket", error.message
      assert_not parent.reload.consumed?
      assert_not original.reload.binding_effective?
      assert_not substitute.reload.binding_effective?
      assert_not outbox_class.exists?(operation_ref: parent.transaction_id)
    end
  end

  test "a consumed email Ticket without a Source commit stays terminal and creates no binding on retry" do
    owner = Client.create!
    contact = ClientEmail.create!(user_id: owner.id, address: "rolled-back-audit@example.test", confirm_policy: "1")
    context = ActorValuesContext.empty.with(subject: owner, actor_type: :client, tld: :app, surface: :base)
    now = ClientEmailCeremonyTransaction.database_now
    parent = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: owner.public_id, session_ref: "source-rollback-browser", operation: "registration",
      email_candidate_ref: contact.public_id, normalized_email_digest: contact.address_digest, now: now,
    )
    signed_result = IdentityEmailCeremonyResult.issue(
      { surface: "app",
        actor_ref: owner.public_id,
        session_ref: parent.session_ref,
        transaction_id: parent.transaction_id,
        grant_jti: parent.grant_jti,
        result_jti: SecureRandom.uuid,
        operation: parent.operation,
        verified_at: now.to_i,
        challenge_id: SecureRandom.uuid,
        expires_at: parent.expires_at.to_i,
        email_candidate_ref: contact.public_id,
        normalized_email_digest: contact.address_digest, },
      issuer_id: IdentityEmailCeremonyContract.sign_issuer_id("app"), now: now,
    )
    ClientEmail.transaction(requires_new: true) do
      IdentityEmailCeremonyFinalCommitter.call!(
        result_token: signed_result, actor_context: context, actor: owner,
        session_ref: parent.session_ref, surface: "app", now: now,
      )
      raise ActiveRecord::Rollback
    end

    assert_predicate parent.reload, :consumed?
    assert_not contact.reload.binding_effective?
    assert_not ClientContactAuditOutbox.exists?(operation_ref: parent.transaction_id)
    error =
      assert_raises(IdentityEmailCeremonyContract::Error) do
        IdentityEmailCeremonyFinalCommitter.call!(
          result_token: signed_result, actor_context: context, actor: owner,
          session_ref: parent.session_ref, surface: "app", now: now,
        )
      end
    assert_equal "transaction is already consumed", error.message
    assert_predicate parent.reload, :consumed?
    assert_not contact.reload.binding_effective?
    assert_not ClientContactAuditOutbox.exists?(operation_ref: parent.transaction_id)
  end

  test "real signed telephone results commit one Source intent and reconcile exact retries in app and com" do
    [
      [Client, ClientTelephone, :user_id, ClientTelephoneCeremonyTransaction, ClientContactAuditOutbox, "app"],
      [Visitor, VisitorTelephone, :visitor_id, VisitorTelephoneCeremonyTransaction, VisitorContactAuditOutbox, "com"],
    ].each do |owner_class, contact_class, owner_key, transaction_class, outbox_class, surface|
      actor = owner_class.create!
      contact = contact_class.create!(owner_key => actor.id, :number => "+819012345683", :confirm_policy => "1")
      context = ActorValuesContext.empty.with(
        subject: actor, actor_type: (surface == "app") ? :client : :visitor, tld: surface.to_sym, surface: :base,
      )
      now = transaction_class.database_now
      parent = transaction_class.create_transaction!(
        actor_ref: actor.public_id, session_ref: "telephone-audit-browser", operation: "registration",
        telephone_candidate_ref: contact.public_id, normalized_number_digest: contact.number_digest, now: now,
      )
      signed_result = IdentityTelephoneCeremonyResult.issue(
        { surface: surface,
          actor_ref: actor.public_id,
          session_ref: parent.session_ref,
          transaction_id: parent.transaction_id,
          grant_jti: parent.grant_jti,
          result_jti: SecureRandom.uuid,
          operation: parent.operation,
          verified_at: now.to_i,
          challenge_id: SecureRandom.uuid,
          expires_at: parent.expires_at.to_i,
          telephone_candidate_ref: contact.public_id,
          normalized_number_digest: contact.number_digest, },
        issuer_id: IdentityTelephoneCeremonyContract.sign_issuer_id(surface), now: now,
      )
      assert_difference -> { outbox_class.where(operation_ref: parent.transaction_id).count }, 1 do
        assert_no_difference "Chronicle.count" do
          IdentityTelephoneCeremonyFinalCommitter.call!(
            result_token: signed_result, actor_context: context, actor: actor,
            session_ref: parent.session_ref, surface: surface, now: now,
          )
        end
      end
      event = outbox_class.find_by!(operation_ref: parent.transaction_id)

      assert_predicate contact.reload, :binding_effective?
      assert_predicate parent.reload, :consumed?
      assert_equal ["telephone", "finalized", actor.public_id, contact.public_id],
                   [event.contact_kind, event.event_name, event.owner_ref, event.contact_ref]
      assert_no_difference -> { outbox_class.where(operation_ref: parent.transaction_id).count } do
        retried = IdentityTelephoneCeremonyFinalCommitter.call!(
          result_token: signed_result, actor_context: context, actor: actor,
          session_ref: parent.session_ref, surface: surface, now: now,
        )

        assert_equal contact, retried.telephone
        assert_equal parent, retried.transaction
        assert_equal event.event_uuid, outbox_class.find_by!(operation_ref: parent.transaction_id).event_uuid
      end
    end
  end

  test "audit refuses a wrong actor role and an event without the corresponding Source binding fact" do
    owner = Client.create!
    contact = ClientEmail.create!(user_id: owner.id, address: "audit-facts@example.test", confirm_policy: "1")
    [
      [ActorValuesContext.empty.with(subject: owner, actor_type: :visitor, tld: :app, surface: :base),
       "actor context does not match Contact audit owner",],
      [ActorValuesContext.empty.with(subject: owner, actor_type: :client, tld: :app, surface: :base),
       "Contact audit does not match its committed binding fact",],
    ].each do |context, message|
      error =
        assert_raises(ArgumentError) do
          ClientEmail.transaction(requires_new: true) do
            ContactBindingAuditRecorder.call!(
              actor_context: context, actor: owner, contact: contact,
              operation_ref: SecureRandom.uuid, event_name: "finalized",
            )
          end
        end
      assert_equal message, error.message
      assert_not ClientContactAuditOutbox.exists?(contact_ref: contact.public_id)
    end
  end

  test "unauthenticated signup audit retains its owner without inventing an authenticated actor" do
    owner = Visitor.create!
    contact = VisitorEmail.create!(visitor_id: owner.id, address: "anonymous-audit@example.test", confirm_policy: "1")
    context = ActorValuesContext.empty.with(tld: :com, surface: :sign)
    event =
      VisitorEmail.transaction do
        contact.finalize_binding!
        ContactBindingAuditRecorder.call!(
          actor_context: context, actor: owner, contact: contact,
          operation_ref: SecureRandom.uuid, event_name: "finalized",
        )
      end

    assert_equal owner.public_id, event.owner_ref
    assert_equal contact.public_id, event.contact_ref
    assert_nil event.actor_ref
  end

  test "audit attribution refuses an actor from a different explicit context before Contact mutation" do
    owner = Client.create!
    foreign = Client.create!
    contact = ClientEmail.create!(user_id: owner.id, address: "wrong-context@example.test", confirm_policy: "1")
    context = ActorValuesContext.empty.with(subject: foreign, actor_type: :client, tld: :app, surface: :base)
    error =
      assert_raises(ArgumentError) do
        ClientEmail.transaction do
          ContactBindingAuditRecorder.call!(
            actor_context: context, actor: owner, contact: contact,
            operation_ref: SecureRandom.uuid, event_name: "finalized",
          )
        end
      end
    assert_equal "actor context does not match Contact audit owner", error.message
    assert_not contact.reload.binding_effective?
    assert_not ClientContactAuditOutbox.exists?(contact_ref: contact.public_id)
  end

  test "real signed email result commits a Source audit intent in app and com without Chronicle delivery" do
    [
      [Client, ClientEmail, :user_id, ClientEmailCeremonyTransaction, ClientContactAuditOutbox, "app"],
      [Visitor, VisitorEmail, :visitor_id, VisitorEmailCeremonyTransaction, VisitorContactAuditOutbox, "com"],
    ].each do |owner_class, contact_class, owner_key, transaction_class, outbox_class, surface|
      actor = owner_class.create!
      contact = contact_class.create!(
        owner_key => actor.id, :address => "#{surface}-audit@example.test",
        :confirm_policy => "1",
      )
      now = transaction_class.database_now
      parent = transaction_class.create_transaction!(
        actor_ref: actor.public_id, session_ref: "audit-browser",
        operation: "registration", email_candidate_ref: contact.public_id,
        normalized_email_digest: contact.address_digest, now: now,
      )
      signed_result = IdentityEmailCeremonyResult.issue(
        { surface: surface,
          actor_ref: actor.public_id,
          session_ref: parent.session_ref,
          transaction_id: parent.transaction_id,
          grant_jti: parent.grant_jti,
          result_jti: SecureRandom.uuid,
          operation: parent.operation,
          verified_at: now.to_i,
          challenge_id: SecureRandom.uuid,
          expires_at: parent.expires_at.to_i,
          email_candidate_ref: contact.public_id,
          normalized_email_digest: contact.address_digest, },
        issuer_id: IdentityEmailCeremonyContract.sign_issuer_id(surface), now: now,
      )
      assert_difference -> { outbox_class.where(operation_ref: parent.transaction_id).count }, 1 do
        assert_no_difference "Chronicle.count" do
          IdentityEmailCeremonyFinalCommitter.call!(
            result_token: signed_result, actor: actor,
            actor_context: ActorValuesContext.empty.with(
              subject: actor, actor_type: (surface == "app") ? :client : :visitor,
              tld: surface.to_sym, surface: :base,
            ),
            session_ref: parent.session_ref, surface: surface, now: now,
          )
        end
      end
      assert_predicate contact.reload, :binding_effective?
      assert_predicate parent.reload, :consumed?
      event = outbox_class.find_by!(operation_ref: parent.transaction_id)

      assert_equal actor.public_id, event.owner_ref
      assert_equal actor.public_id, event.actor_ref
      assert_equal contact.public_id, event.contact_ref
      assert_equal "email", event.contact_kind
      assert_equal "finalized", event.event_name
      assert_nil event.acknowledged_at
      assert_no_difference -> { outbox_class.where(operation_ref: parent.transaction_id).count } do
        retried = IdentityEmailCeremonyFinalCommitter.call!(
          result_token: signed_result, actor: actor,
          actor_context: ActorValuesContext.empty.with(
            subject: actor, actor_type: (surface == "app") ? :client : :visitor,
            tld: surface.to_sym, surface: :base,
          ),
          session_ref: parent.session_ref, surface: surface, now: now,
        )

        assert_equal contact, retried.email
        assert_equal parent, retried.transaction
        assert_equal event.event_uuid, outbox_class.find_by!(operation_ref: parent.transaction_id).event_uuid
      end
      original_result = IdentityEmailCeremonyResult.decode(
        signed_result, issuer_id: IdentityEmailCeremonyContract.sign_issuer_id(surface), now: now,
      )
      swapped_result = IdentityEmailCeremonyResult.issue(
        original_result.payload.merge("result_jti" => SecureRandom.uuid),
        issuer_id: IdentityEmailCeremonyContract.sign_issuer_id(surface), now: now,
      )
      context = ActorValuesContext.empty.with(
        subject: actor, actor_type: (surface == "app") ? :client : :visitor, tld: surface.to_sym, surface: :base,
      )
      error =
        assert_raises(IdentityEmailCeremonyContract::Error) do
          IdentityEmailCeremonyFinalCommitter.call!(
            result_token: swapped_result, actor_context: context, actor: actor,
            session_ref: parent.session_ref, surface: surface, now: now,
          )
        end
      assert_equal "committed Contact result provenance mismatch", error.message
      actor.with_lock { contact.release_binding! }
      released_at = contact.reload.binding_released_at
      error =
        assert_raises(IdentityEmailCeremonyContract::Error) do
          IdentityEmailCeremonyFinalCommitter.call!(
            result_token: signed_result, actor_context: context, actor: actor,
            session_ref: parent.session_ref, surface: surface, now: now,
          )
        end
      assert_equal "committed Contact binding is unavailable", error.message
      assert_equal released_at, contact.reload.binding_released_at
      assert_equal 1, outbox_class.where(operation_ref: parent.transaction_id).count
    end
  end
end
