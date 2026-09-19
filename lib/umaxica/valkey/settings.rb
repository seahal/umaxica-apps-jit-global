# typed: false
# frozen_string_literal: true

require "yaml"
require "active_support/core_ext/object/blank"
require_relative "error"
require_relative "configuration_error"
require_relative "responsibility_urls"

module Umaxica
  module Valkey
    # Loads config/valkey.yml for one Rails environment and resolves each
    # responsibility to a URL or an in-process store. Consumers ask for cache,
    # rate-limit, or auth-state; they do not choose hosts by Rails.env.
    class Settings
      PATH = File.expand_path("../../../config/valkey.yml", __dir__).freeze
      APPLICATION_RESPONSIBILITIES = %i(cache rate_limit auth_state).freeze
      DIAGNOSTIC_RESPONSIBILITIES = %i(performance coverband).freeze
      NONPROD_ENVIRONMENTS = %w(development test).freeze

      Resolved =
        Data.define(:responsibility, :url, :db, :host, :port, :store, :namespace) do
          def memory?
            store == :memory
          end
        end

      class << self
        public

        def load(rails_env: Rails.env, environment: ENV)
          new(rails_env: rails_env.to_s, environment: environment)
        end

        def current
          @current ||= load
        end

        def reset_current!
          @current = nil
        end

        def document
          YAML.safe_load_file(PATH, aliases: true, symbolize_names: true)
        end

        def logical_db(responsibility, rails_env:)
          entry =
            environment_entry(rails_env).fetch(responsibility.to_sym) do
              raise ConfigurationError, "unknown Valkey responsibility: #{responsibility.inspect}"
            end
          entry[:db] || entry[:reserved_db]
        end

        def environment_entry(rails_env)
          document.fetch(rails_env.to_sym) do
            raise ConfigurationError, "unknown Valkey environment: #{rails_env.inspect}"
          end
        end
      end

      public

      def initialize(rails_env:, environment:)
        @rails_env = rails_env.to_s
        @environment = environment
        @raw = self.class.environment_entry(@rails_env)
        validate_environment_shape!
        @resolved = resolve_all
      end

      attr_reader :rails_env

      def cache
        @resolved.fetch(:cache)
      end

      def rate_limit
        @resolved.fetch(:rate_limit)
      end

      def auth_state
        @resolved.fetch(:auth_state)
      end

      def performance
        @resolved.fetch(:performance)
      end

      def coverband
        @resolved.fetch(:coverband)
      end

      def [](responsibility)
        @resolved.fetch(responsibility.to_sym)
      end

      private

      def validate_environment_shape!
        APPLICATION_RESPONSIBILITIES.each do |name|
          raise ConfigurationError, "valkey.yml #{@rails_env} is missing #{name}" unless @raw.key?(name)
        end

        if @rails_env == "production"
          APPLICATION_RESPONSIBILITIES.each do |name|
            entry = @raw.fetch(name)
            unless entry[:url_key].to_s.present? && entry[:db].nil? && entry[:host_key].nil?
              raise ConfigurationError,
                    "production #{name} must use an explicit URL key, not the nonprod DB map"
            end
          end
        elsif @rails_env == "test"
          store = @raw.fetch(:cache)[:store].to_s
          raise ConfigurationError, "test cache must use the memory store" unless store == "memory"
          unless self.class.logical_db(:cache, rails_env: "test") == 2
            raise ConfigurationError, "test cache reserved DB must be 2"
          end
        elsif @rails_env == "development"
          nil
        else
          raise ConfigurationError, "unsupported Valkey environment: #{@rails_env.inspect}"
        end
      end

      def resolve_all
        names = APPLICATION_RESPONSIBILITIES.dup
        names.concat(DIAGNOSTIC_RESPONSIBILITIES) if @raw.key?(:performance) || @raw.key?(:coverband)
        names.index_with { |name| resolve(name) }
      end

      def resolve(name)
        entry = @raw.fetch(name)
        if entry[:store].to_s == "memory"
          return Resolved.new(
            responsibility: name,
            url: nil,
            db: entry[:reserved_db],
            host: nil,
            port: nil,
            store: :memory,
            namespace: entry[:namespace],
          )
        end

        url = constructed_url(name, entry)
        parsed = ResponsibilityUrls.parse(url, responsibility: name)
        if NONPROD_ENVIRONMENTS.include?(@rails_env) && entry[:db]
          expected = entry.fetch(:db)
          if parsed.db != expected
            raise ConfigurationError,
                  "#{name} Valkey URL DB is #{parsed.db}, expected #{expected} in #{@rails_env}"
          end
        end

        Resolved.new(
          responsibility: name,
          url: parsed.url,
          db: parsed.db,
          host: parsed.host,
          port: parsed.port,
          store: :redis,
          namespace: entry[:namespace],
        )
      end

      def constructed_url(name, entry)
        if entry[:url_key].to_s.present?
          fetch_required(entry.fetch(:url_key))
        elsif entry[:host_key].to_s.present?
          host = fetch_required(entry.fetch(:host_key))
          port = parse_port(fetch_required(entry.fetch(:port_key)))
          db = entry.fetch(:db)
          "redis://#{host}:#{port}/#{db}"
        else
          raise ConfigurationError, "#{name} Valkey settings are incomplete in #{@rails_env}"
        end
      end

      def fetch_required(name)
        value = @environment.fetch(name).to_s
        raise ConfigurationError, "#{name} is required" if value.blank?

        value
      rescue KeyError => e
        raise ConfigurationError, "#{name} is required", cause: e
      end

      def parse_port(value)
        port = Integer(value.to_s, 10)
        raise ConfigurationError, "Valkey port must be between 1 and 65535" unless port.between?(1, 65_535)

        port
      rescue ArgumentError, TypeError => e
        raise ConfigurationError, "Valkey port must be an integer", cause: e
      end
    end
  end
end
