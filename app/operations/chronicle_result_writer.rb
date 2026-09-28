# typed: false
# frozen_string_literal: true

class ChronicleResultWriter < ChronicleApplicationService
  def initialize(chronicle:, result:, event_uuid:, request_id:, action:, actor: nil, subject: nil, error: nil,
                 changeset: nil)
    super()
    @chronicle = chronicle
    @changeset = changeset
    @result = result
    @event_uuid = event_uuid
    @request_id = request_id
    @action = action
    @actor = actor
    @subject = subject
    @error = error
  end

  def call
    # The intent row carries the pre-operation state; a completed operation may add what it observed
    # (for example how many sessions it revoked) under the same sanitized changeset.
    attributes = { result: result }
    attributes[:changeset] = chronicle.changeset.merge(changeset.deep_stringify_keys) if changeset.present?
    chronicle.update!(attributes)
    chronicle
  rescue StandardError => e
    ChronicleFallbackRecorder.call(
      event: "chronicle.result_write_failed",
      event_uuid: event_uuid,
      request_id: request_id,
      action: action,
      actor: actor,
      subject: subject,
      error: e,
    )
    raise
  end

  private

  attr_reader :chronicle, :result, :event_uuid, :request_id, :action, :actor, :subject, :error, :changeset
end
