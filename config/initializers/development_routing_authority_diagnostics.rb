# typed: false
# frozen_string_literal: true

# TEMPORARY development-only diagnostic for the POST /sign/in RoutingError investigation
# (2026-09-28). Remove once the request authority of the failing request is recorded in evidence/.
#
# Logs only authority/transport metadata. Query strings, bodies, cookies, and tokens are never read.
if Rails.env.development?
  ActionDispatch::DebugExceptions.register_interceptor do |request, exception|
    next unless exception.is_a?(ActionController::RoutingError)

    env = request.env
    probe_host = Rails.configuration.x.boot_config.fetch(:hosts).auth_service.host
    auth_recognizes =
      begin
        Rails.application.routes.recognize_path("https://#{probe_host}#{request.path}", method: request.request_method)
        true
      rescue ActionController::RoutingError
        false
      end

    Rails.logger.warn(
      JitLogEvent.format(
        "diagnostic.routing_error.authority",
        request_id: request.request_id,
        method: request.request_method,
        path: request.path,
        host: request.host,
        authority: request.host_with_port,
        scheme: request.scheme,
        origin_seen: request.base_url,
        server_name: env["SERVER_NAME"],
        server_listen_number: env["SERVER_PORT"],
        http_host: env["HTTP_HOST"],
        x_forwarded_host: env["HTTP_X_FORWARDED_HOST"],
        x_forwarded_scheme: env["HTTP_X_FORWARDED_PROTO"],
        x_forwarded_p: env["HTTP_X_FORWARDED_PORT"],
        forwarded_present: env.key?("HTTP_FORWARDED"),
        origin: env["HTTP_ORIGIN"],
        referer_host: (URI.parse(env["HTTP_REFERER"].to_s).host rescue "unparseable"),
        sec_fetch_site: env["HTTP_SEC_FETCH_SITE"],
        sec_fetch_mode: env["HTTP_SEC_FETCH_MODE"],
        sec_fetch_dest: env["HTTP_SEC_FETCH_DEST"],
        service_worker: env["HTTP_SERVICE_WORKER"],
        content_type: request.content_type,
        route_count: Rails.application.routes.routes.size,
        auth_host_recognizes_same_request: auth_recognizes,
      ),
    )
  end
end
