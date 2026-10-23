# typed: false
# frozen_string_literal: true

require "digest"
require "json"

# One JWKS refetch per issuer per window across every Puma worker (D-136, D-144).
#
# The right to fetch is a lease taken atomically in the rate-limit Valkey; the outcome of the
# latest fetch is kept for the window so later unknown `kid`s are decided without fetching. When
# Valkey is unavailable a process-local window with the same length applies, never no limit.
class OidcJwksRefetchLimiter
  WINDOW = 30.seconds
  LEASE_TTL = 10.seconds
  NAMESPACE_SUFFIX = "oidc_jwks_refetch"

  Decision =
    Data.define(:kind, :outcome, :kids) do
      def lease? = kind == :lease

      def window? = kind == :window

      def busy? = kind == :busy

      def ok? = outcome == "ok"
    end

  # Takes the lease only when no recent outcome exists; otherwise returns that outcome.
  ACQUIRE_SCRIPT = <<~LUA.freeze
    local last = redis.call("GET", KEYS[2])
    if last then return {"window", last} end
    if redis.call("SET", KEYS[1], ARGV[1], "NX", "EX", ARGV[2]) then return {"lease", ""} end
    return {"busy", ""}
  LUA

  class LocalWindow
    def initialize(clock:)
      @clock = clock
      @mutex = Mutex.new
      @entries = {}
    end

    public

    def acquire(issuer_key)
      @mutex.synchronize do
        last = @entries[issuer_key]
        if last && @clock.call - last.fetch(:at) < WINDOW
          Decision.new(kind: :window, outcome: last.fetch(:outcome), kids: last.fetch(:kids))
        else
          @entries[issuer_key] = { at: @clock.call, outcome: "pending", kids: [] }
          Decision.new(kind: :lease, outcome: nil, kids: [])
        end
      end
    end

    def record(issuer_key, outcome:, kids:)
      @mutex.synchronize { @entries[issuer_key] = { at: @clock.call, outcome:, kids: } }
    end
  end

  SHARED = Concurrent::Delay.new { new }

  class << self
    public

    def shared
      SHARED.value
    end

    def issuer_key(jwks_uri)
      Digest::SHA256.hexdigest(jwks_uri.to_s)[0, 32]
    end
  end

  def initialize(connection: nil, clock: -> { Time.current }, worker_id: "#{Process.pid}-#{SecureRandom.hex(4)}")
    @connection = connection
    @local = LocalWindow.new(clock:)
    @worker_id = worker_id
  end

  public

  def acquire(issuer_key)
    kind, raw = connection.call(
      "EVAL", ACQUIRE_SCRIPT, 2, connection.key("#{issuer_key}:lease"), connection.key("#{issuer_key}:last"),
      @worker_id, LEASE_TTL.to_i,
    )
    return Decision.new(kind: kind.to_sym, outcome: nil, kids: []) unless kind == "window"

    last = JSON.parse(raw)
    Decision.new(kind: :window, outcome: last.fetch("outcome"), kids: Array(last.fetch("kids")))
  rescue Umaxica::Valkey::Unavailable, JSON::ParserError, KeyError
    @local.acquire(issuer_key)
  end

  def record(issuer_key, outcome:, kids:)
    @local.record(issuer_key, outcome:, kids:)
    connection.call(
      "SET", connection.key("#{issuer_key}:last"), JSON.generate({ outcome:, kids: }), "EX", WINDOW.to_i,
    )
  rescue Umaxica::Valkey::Unavailable
    nil
  end

  private

  # Rebuilt when the namespace changes (a forked test worker gets its own); otherwise reused.
  def connection
    return @connection if @connection && !@connection_namespace

    namespace = "#{Rails.configuration.x.rate_limit.fetch(:namespace)}:#{NAMESPACE_SUFFIX}"
    return @shared_connection if @connection_namespace == namespace

    @connection_namespace = namespace
    @shared_connection = Umaxica::Valkey::Connection.new(
      url: Umaxica::Valkey::Settings.current.rate_limit.url, namespace:,
    )
  end
end
