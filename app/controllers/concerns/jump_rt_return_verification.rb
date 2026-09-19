# typed: false
# frozen_string_literal: true

module JumpRtReturnVerification
  extend ActiveSupport::Concern

  private

  def jump_return_rt_request?
    (request.get? || request.head?) && params[:rt].present?
  end

  def verify_jump_return_rt!
    result = JumpRtReturnVerifier.call(
      token: params[:rt],
      request_url: request.original_url,
      request_base_url: request.base_url,
    )

    return redirect_to_jump_return_target! if result.success?

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

  def redirect_to_jump_return_target!
    response.set_header("Referrer-Policy", "no-referrer")
    response.set_header("Cache-Control", "no-store")
    redirect_to(jump_return_url_without_rt, allow_other_host: false, status: :see_other)
  end

  def jump_return_url_without_rt
    uri = URI.parse(request.original_url)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query.delete("rt")
    uri.query = query.present? ? Rack::Utils.build_nested_query(query) : nil
    uri.request_uri
  end
end
