# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# The cache is Valkey, and Valkey is allowed to evict. That is only safe while
# two properties hold, and neither is enforced by the type system:
#
#   1. every cache entry expires on purpose, so a write cannot outlive the
#      reason it was made and turn the cache into de facto storage; and
#   2. nothing whose loss would change correctness, security, or history is
#      written there in the first place.
#
# Both were violated while `Rails.cache` was Solid Cache and therefore durable in
# practice -- client-assertion replay state lived in it. These assertions pin the
# boundary shut now that eviction is real.
class CacheBoundaryInvariantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # `Rails.cache.write` and `Rails.cache.fetch` are the entry points that create
  # an entry. `read`, `delete`, and `clear` cannot.
  WRITING_CALL = /Rails\.cache\.(write|fetch)\b/
  EXPLICIT_TTL = /\bexpires_in:/

  test "every Rails.cache write declares an explicit TTL" do
    offenders =
      cached_source_files.flat_map do |path|
        relative = path.relative_path_from(Rails.root).to_s

        writing_call_statements(path).filter_map do |statement, line_number|
          next if statement.match?(EXPLICIT_TTL)

          "#{relative}:#{line_number}: #{statement.strip}"
        end
      end

    assert_empty offenders,
                 "Rails.cache writes must expire on purpose. An entry without expires_in outlives " \
                 "the reason it was written and makes the cache behave like storage:\n" \
                 "#{offenders.join("\n")}"
  end

  test "no application code depends on Solid Cache" do
    offenders =
      (cached_source_files + Rails.root.glob("config/**/*.rb")).filter_map do |path|
        content = read_source(path)
        next unless content.match?(/\bSolidCache\b|:solid_cache_store|\bsolid_cache\b/)

        path.relative_path_from(Rails.root).to_s
      end

    assert_empty offenders,
                 "Solid Cache was removed from the runtime architecture; the cache is Valkey:\n" \
                 "#{offenders.join("\n")}"
  end

  test "the rate limit store is never Rails.cache" do
    offenders =
      Rails.root.glob("config/environments/*.rb").filter_map do |path|
        content = read_source(path)
        next unless content.match?(/x\.rate_limit\.store\s*=\s*Rails\.cache/)

        path.relative_path_from(Rails.root).to_s
      end

    assert_empty offenders,
                 "Rate-limit counters and the application cache are separate stores. Sharing them " \
                 "lets a cache flush reset every open rate-limit window:\n#{offenders.join("\n")}"
  end

  test "cache and rate limit URLs have no fallback value" do
    content = Rails.root.glob("config/environments/*.rb").map(&:read).join("\n")

    # A two-argument ENV.fetch would boot with a default instead of reporting the
    # gap, which for these two means silently running per-process stores that
    # neither share counters nor share cache entries across the fleet.
    %w(CACHE_REDIS_URL RATE_LIMIT_REDIS_URL).each do |name|
      assert_no_match(
        /#{name}["']\s*,/, content,
        "#{name} must use one-argument ENV.fetch so a missing URL stops the boot",
      )
    end
  end

  test "development and production resolve both Valkey stores" do
    %w(development production).each do |environment|
      content = Rails.root.join("config/environments/#{environment}.rb").read

      assert_match(
        /ENV\.fetch\("CACHE_REDIS_URL"\)/, content,
        "#{environment} must back Rails.cache with the Valkey cache store",
      )
      assert_match(
        /ENV\.fetch\("RATE_LIMIT_REDIS_URL"\)/, content,
        "#{environment} must back rate limiting with the Valkey rate-limit store",
      )
    end
  end

  # RedisCacheStore turns a connection error into nil, and Rails' rate_limit acts
  # only `if count && count > to` -- so an unreachable Valkey removes every rate
  # limit, and does it silently. Whether that should fail closed instead is an
  # open availability question; that it must be observable is not.
  test "both Valkey stores report their own unavailability" do
    %w(development production).each do |environment|
      content = Rails.root.join("config/environments/#{environment}.rb").read

      assert_equal 2, content.scan(/error_handler:/).length,
                   "#{environment} must give both the cache and the rate-limit store an " \
                   "error_handler, or a Valkey outage degrades them without a trace"
    end
  end

  private

  def cached_source_files
    Rails.root.glob("app/**/*.rb") + Rails.root.glob("lib/**/*.rb")
  end

  def read_source(path)
    File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
  end

  # A `Rails.cache.fetch` argument list often wraps, so `expires_in:` can sit
  # several lines below the call. Join each call to the end of its argument list
  # before checking, or every multi-line write reads as a violation.
  def writing_call_statements(path)
    lines = read_source(path).lines

    lines.each_with_index.filter_map do |line, index|
      next unless line.match?(WRITING_CALL)

      [statement_from(lines, index), index + 1]
    end
  end

  def statement_from(lines, index)
    statement = +""

    lines[index..].each do |line|
      statement << line
      break if balanced?(statement)
    end

    statement
  end

  def balanced?(text)
    %w({ } ( ) [ ]).each_slice(2).all? { |open, close| text.count(open) == text.count(close) } &&
      !text.rstrip.end_with?(",")
  end
end
