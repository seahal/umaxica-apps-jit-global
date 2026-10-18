# typed: false
# frozen_string_literal: true

module FlowWithdrawal
  extend ActiveSupport::Concern

  include FlowBase

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    cycle_status_column :status_id
  end

  def withdrawal_requested?
    cycle_status?(status_id_for("REQUESTED"))
  end

  def withdrawal_closing?
    cycle_status?(status_id_for("CLOSING"))
  end

  def withdrawal_discarded?
    cycle_status?(status_id_for("DISCARDED"))
  end

  def withdrawal_recovered?
    cycle_status?(status_id_for("RECOVERED"))
  end

  def withdrawal_terminated?
    cycle_status?(status_id_for("TERMINATED"))
  end

  def withdrawal_failed?
    cycle_status?(status_id_for("FAILED"))
  end

  def request_withdrawal!(now: Time.current, **event_attrs)
    transition_withdrawal_to!("REQUESTED", allowed_from: ["NOTHING"], now: now, **event_attrs)
  end

  def confirm_withdrawal!(now: Time.current, **event_attrs)
    transition_withdrawal_to!("CLOSING", allowed_from: ["REQUESTED"], now: now, **event_attrs)
  end

  def discard_withdrawal!(now: Time.current, **event_attrs)
    transition_withdrawal_to!("DISCARDED", allowed_from: ["CLOSING"], now: now, **event_attrs)
  end

  def recover_withdrawal!(now: Time.current, **event_attrs)
    transition_withdrawal_to!(
      "RECOVERED",
      allowed_from: ["DISCARDED"],
      changes: { completed_at: now },
      now: now,
      **event_attrs,
    )
  end

  def terminate_withdrawal!(now: Time.current, **event_attrs)
    transition_withdrawal_to!(
      "TERMINATED",
      allowed_from: ["DISCARDED"],
      changes: { completed_at: now },
      now: now,
      **event_attrs,
    )
  end

  def fail_withdrawal!(now: Time.current, **event_attrs)
    transition_withdrawal_to!(
      "FAILED",
      allowed_from: %w(REQUESTED CLOSING DISCARDED),
      changes: { failed_at: now },
      now: now,
      **event_attrs,
    )
  end

  private

  def transition_withdrawal_to!(next_status_name, allowed_from:, now:, changes: {}, **event_attrs)
    to_status_id = status_id_for(next_status_name)

    with_cycle_lock do
      from_status_id = status_id
      ensure_cycle_transition_allowed!(to_status_id, allowed_from: status_ids_for(*allowed_from), now: now)
      update!(changes.merge(status_id: to_status_id))
      record_withdrawal_event!(
        from_status_id: from_status_id,
        to_status_id: to_status_id,
        occurred_at: now,
        **event_attrs,
      )
    end
  end
end
