# frozen_string_literal: true

require "faraday"
require "rack/mock"

# In the test environment the OP endpoints are served by this same Rails application, so an RP's
# public-HTTPS call to the OP token endpoint (OidcOpTokenClient, R5-WU05) is delivered in-process
# instead of over the network. Only the registered Base token endpoints are routed here; every
# other outbound request still hits the OutboundHttpGuard and must be stubbed explicitly.
module TestSupport
  module InProcessOpTransport
    # OP endpoints an RP calls server-to-server (token exchange/refresh and delivery query).
    OP_PATHS = %w(/oauth/token /oauth/refresh-deliveries/query /.well-known/jwks.json
                  /api/v0/tech-capability-checks /api/v0/support).freeze

    # Forwards a Faraday request to Rails.application as a Rack request.
    class Adapter < Faraday::Adapter
      def call(env)
        super
        rack_env = Rack::MockRequest.env_for(
          env.url.to_s,
          :method => env.method.to_s.upcase,
          :input => env.body.to_s,
          "CONTENT_TYPE" => env.request_headers["Content-Type"],
          "HTTP_ACCEPT" => "application/json",
          "HTTPS" => (env.url.scheme == "https") ? "on" : "off",
        )
        # Carry the caller's headers (Authorization, X-Client-Assertion, ...) as a real request would.
        env.request_headers.each do |name, value|
          next if name.casecmp?("Content-Type")

          rack_env["HTTP_#{name.upcase.tr("-", "_")}"] = value
        end
        # Dispatch through the router rather than the full middleware stack: the outer test request
        # already owns the executor, and re-entering it would reset that request's execution state.
        # A real OP request starts a fresh database role context; the outer request may be a GET on
        # the reading role, so the OP endpoint runs on the writer as its own POST would.
        # The OP is a different process from an RP cell: a test running as a cell role (R5-WU17)
        # must not have its own role guard answer for the OP, so the OP side runs unrestricted.
        status, headers, body =
          with_op_process_role do
            ActiveRecord::Base.connected_to(role: :writing) do
              Rails.application.routes.call(rack_env)
            end
          end
        text = +""
        body.each { |chunk| text << chunk }
        body.close if body.respond_to?(:close)
        save_response(env, status, text, headers)
        @app.call(env)
      end

      private

      def with_op_process_role
        previous = ENV["UMAXICA_RUNTIME_ROLE"]
        ENV["UMAXICA_RUNTIME_ROLE"] = RuntimeRole::SHARED
        yield
      ensure
        ENV["UMAXICA_RUNTIME_ROLE"] = previous
      end
    end

    # The in-process OP is part of the system under test, not an external service.
    class Connection < Faraday::Connection
      def run_request(...)
        TestSupport::OutboundHttpGuard.allow { super }
      end
    end

    module_function

    def op_token_endpoint?(url)
      uri = URI.parse(url.to_s)
      return false unless OP_PATHS.include?(uri.path) || uri.path.start_with?(
        "/api/v0/publishing/", "/api/v0/avatar/",
        "/api/v0/membership/", "/api/v0/iam/", "/api/v0/support/", "/api/v0/identity/",
      )

      %w(client visitor operator).any? { |type| URI.parse(OidcIssuer.for_resource_type(type)).host == uri.host }
    rescue URI::InvalidURIError
      false
    end

    def connection
      Connection.new do |builder|
        builder.request(:url_encoded)
        builder.adapter(Adapter)
      end
    end
  end
end

# Wrap (not prepend) OutboundHttp::Connection.build so an explicit test stub of `build` still takes
# precedence: Minitest's stub redefines this singleton method for the duration of its block.
OutboundHttp::Connection.singleton_class.alias_method(:build_without_in_process_op, :build)
OutboundHttp::Connection.define_singleton_method(:build) do |url:, **options|
  next TestSupport::InProcessOpTransport.connection if TestSupport::InProcessOpTransport.op_token_endpoint?(url)

  build_without_in_process_op(url:, **options)
end
