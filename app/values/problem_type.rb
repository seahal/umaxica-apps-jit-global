# typed: false
# frozen_string_literal: true

# One registered RFC 9457 problem type.
#
# Each entry in `DEFINITIONS` is a permanent public API contract: the URI identifies the problem to
# clients, and the HTTP status is part of that identity. RFC 9457 3.1.2 requires `title` to be stable
# across occurrences of the same type, which is why the text lives here rather than at each call
# site. Occurrence-specific text belongs in `detail`.
#
# The registry is closed on purpose. `fetch` raises on an unknown slug so an unregistered type cannot
# reach a client, per .agents/harnesses/rules/generic/no-silent-fallback.mdc. Adding a type means
# adding a row here and a row in docs/reference/api-design-standards.md; neither alone is enough.
#
# See adr/api-error-format-problem-details.md.
class ProblemType
  NAMESPACE = "urn:umaxica:problem"

  # Titles are deliberately untranslated. They are part of a machine-facing contract, and RFC 9457
  # 3.1.1 makes `type` the value clients branch on; a client that shows text to a human localizes it
  # from `type`, not from the wire. `detail` is likewise diagnostic, not display copy.
  # rubocop:disable I18n/RailsI18n/DecorateString
  DEFINITIONS = {
    bad_request: { status: :bad_request, title: "Malformed request." },
    authentication_required: { status: :unauthorized, title: "Authentication is required." },
    token_expired: { status: :unauthorized, title: "Token expired." },
    authorization_denied: { status: :forbidden, title: "Authorization denied." },
    csrf_verification_failed: { status: :forbidden, title: "CSRF verification failed." },
    not_found: { status: :not_found, title: "Resource not found." },
    method_not_allowed: { status: :method_not_allowed, title: "Method not allowed." },
    not_acceptable: { status: :not_acceptable, title: "No acceptable representation." },
    unsupported_media_type: { status: :unsupported_media_type, title: "Unsupported media type." },
    content_too_large: { status: :content_too_large, title: "Content too large." },
    validation_failed: { status: :unprocessable_content, title: "Validation failed." },
    rate_limited: { status: :too_many_requests, title: "Rate limit exceeded." },
    server_error: { status: :internal_server_error, title: "Internal server error." },
    service_unavailable: { status: :service_unavailable, title: "Service unavailable." },
  }.freeze
  # rubocop:enable I18n/RailsI18n/DecorateString

  # Used only by ApiProblemExceptionsApp, which is handed an HTTP status by Rails rather than a
  # problem slug and so needs the reverse mapping. Statuses that two types share (401, 403) resolve
  # to the more general of the pair, because a generic error handler cannot know which cause applied;
  # a controller that does know renders the specific type directly.
  STATUS_FALLBACKS = {
    400 => :bad_request,
    401 => :authentication_required,
    403 => :authorization_denied,
    404 => :not_found,
    405 => :method_not_allowed,
    406 => :not_acceptable,
    415 => :unsupported_media_type,
    413 => :content_too_large,
    422 => :validation_failed,
    429 => :rate_limited,
    500 => :server_error,
    503 => :service_unavailable,
  }.freeze

  class << self
    def fetch(slug)
      key = slug.to_sym
      definition =
        DEFINITIONS.fetch(key) do
          raise KeyError, "unregistered problem type: #{slug.inspect}. Register it in " \
                          "ProblemType::DEFINITIONS and in docs/reference/api-design-standards.md."
        end

      new(slug: key, **definition)
    end

    def registered?(slug)
      DEFINITIONS.key?(slug.to_sym)
    end

    # Resolves an HTTP status to a registered type for the generic error path. Unlike `fetch`, this
    # must never raise: it runs while an error is already being rendered, so raising here would
    # replace a reportable failure with an unreportable one. The two-way default is bounded and
    # written down rather than invented per call.
    def for_status(code)
      slug = STATUS_FALLBACKS.fetch(code.to_i) { (code.to_i >= 500) ? :server_error : :bad_request }
      fetch(slug)
    end
  end

  attr_reader :slug, :status, :title

  def initialize(slug:, status:, title:)
    @slug = slug
    @status = status
    @title = title
    freeze
  end

  # Slugs are underscored as Ruby symbols and hyphenated in the URI. The URI form is the published
  # contract; the symbol form is an implementation detail of the registry.
  def uri
    "#{NAMESPACE}:#{slug.to_s.tr("_", "-")}"
  end

  # RFC 9457 3.1.3 requires the `status` member to be the numeric code, and to agree with the
  # response status line. Both are derived from this one value so they cannot disagree.
  def status_code
    Rack::Utils.status_code(status)
  end

  def ==(other)
    other.is_a?(self.class) && other.slug == slug
  end
  alias eql? ==

  def hash
    [self.class, slug].hash
  end
end
