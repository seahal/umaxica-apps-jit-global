# typed: false
# frozen_string_literal: true

module JumpRtReturnVerification
  extend ActiveSupport::Concern

  private

  # Decided from the raw query rather than params[:rt]: Rack collapses repeated and nested rt keys,
  # so params cannot prove the request carries exactly one scalar token.
  def jump_return_rt_request?
    (request.get? || request.head?) && JumpRtReturnUrlValue.carries_return_token?(request.query_string)
  end

  def verify_jump_return_rt!
    return_url = JumpRtReturnUrlValue.parse(request.original_url)
    result =
      if return_url.nil?
        JumpRtReturnVerifier::Result.new(success: false, payload: nil, error: "invalid_url")
      else
        JumpRtReturnVerifier.call(
          token: return_url.return_token,
          request_url: request.original_url,
          request_base_url: request.base_url,
        )
      end

    if result.success?
      Rails.logger.info(
        JitLogEvent.format(
          "jump_return.accepted",
          occurred_at: Time.current.utc.iso8601(3),
          request_id: request.request_id,
          request_path: request.path,
          jump_source: result.payload["src"],
          jump_jti_digest: StepUpObservabilityDigest.jump_jti_ref(result.payload.fetch("jti")),
        ),
      )
      return redirect_to_jump_return_target!(return_url)
    end

    Rails.logger.info(
      JitLogEvent.format(
        "jump_return.rejected",
        reason: result.error,
        request_id: request.request_id,
        request_path: request.path,
      ),
    )
    render plain: I18n.t("errors.messages.invalid_request"),
           status: :bad_request
  end

  # Redirects to the serialization that was just verified, so no lossy re-parse can change the
  # target between verification and navigation.
  def redirect_to_jump_return_target!(return_url)
    response.set_header("Referrer-Policy", "no-referrer")
    response.set_header("Cache-Control", "no-store")
    redirect_to(return_url.request_uri_without_return_token, allow_other_host: false, status: :see_other)
  end
end
