# frozen_string_literal: true

require "concurrent/map"

require_relative "object_storage_environment"
require_relative "object_storage_boundary"

module ObjectStorage
  # Builds the Shrine storage set for the current environment.
  #
  # Development and production-shaped staging resolve to an explicitly configured
  # S3-compatible service. Real production resolves to AWS S3 through the platform
  # credential provider, while test stays in memory and performs no network I/O.
  module ShrineConfiguration
    module_function

    S3_COMPATIBLE_VARIABLES = %w(
      OBJECT_STORAGE_ENDPOINT
      OBJECT_STORAGE_REGION
      OBJECT_STORAGE_ACCESS_KEY_ID
      OBJECT_STORAGE_SECRET_ACCESS_KEY
      OBJECT_STORAGE_FORCE_PATH_STYLE
    ).freeze

    # Shrine's cache is upload staging for this application's attachments. It is
    # unrelated to the Rails `cache` database and must never be backed by it.
    ROLE_PREFIXES = { cache: "cache", store: "store" }.freeze

    # Absolute so a process started from another working directory cannot write
    # uploads somewhere unintended. Resolved at call time because Rails.root is
    # not available when this file is first required.
    def local_root
      Rails.root.join("tmp/uploads").to_s
    end

    def mode(rails_env = Rails.env)
      if rails_env.test?
        :memory
      elsif rails_env.development?
        :s3_compatible
      elsif rails_env.production?
        case ENV.fetch("DEPLOYMENT_TIER")
        when "staging"
          :s3_compatible
        when "production"
          :s3
        else
          raise ArgumentError,
                "DEPLOYMENT_TIER must be exactly staging or production, got #{ENV.fetch("DEPLOYMENT_TIER").inspect}"
        end
      else
        raise ArgumentError, "unsupported Rails environment for object storage: #{rails_env}"
      end
    end

    # The eagerly registered storages. Under :s3 and :s3_compatible this is empty
    # on purpose: every boundary storage is resolved lazily by name through
    # `.dynamic` below, so no deployment is asked for a bucket it does not use.
    # An uploader that never selects a boundary therefore finds no storage and
    # fails with Shrine::MissingStorage instead of silently choosing a default.
    def storages(rails_env = Rails.env)
      case mode(rails_env)
      when :memory
        require "shrine/storage/memory"
        { cache: Shrine::Storage::Memory.new, store: Shrine::Storage::Memory.new }
      when :local_filesystem
        require "shrine/storage/file_system"
        {
          cache: Shrine::Storage::FileSystem.new(local_root, prefix: "cache"),
          store: Shrine::Storage::FileSystem.new(local_root, prefix: "store"),
        }
      when :s3, :s3_compatible
        {}
      else
        raise ArgumentError, "unsupported object-storage mode"
      end
    end

    # Resolves every registered boundary so missing configuration fails at boot
    # rather than at the first upload. In test this constructs in-memory storages;
    # under :s3 and :s3_compatible it forces every registered boundary's bucket and
    # credentials to resolve now.
    def verify_registered_boundaries!(rails_env = Rails.env)
      Boundary.keys.each do |boundary|
        ROLE_PREFIXES.each_key { |role| dynamic(boundary, role, rails_env) }
      end
    end

    # Shrine's dynamic_storage plugin calls this resolver on EVERY find_storage
    # lookup and does not memoize. Without this cache each upload, URL, and delete
    # would construct a new storage object -- a new Aws::S3::Client, and its
    # connection pool and credential resolution, every time -- and under the
    # memory and file-system modes each lookup would return a fresh, empty store,
    # silently losing already-uploaded files.
    STORAGE_CACHE = Concurrent::Map.new

    # Resolves a `<boundary>_<role>` storage name, e.g. :avatar_store.
    # Returns nil for anything else so Shrine raises Shrine::MissingStorage.
    def dynamic(boundary, role, rails_env = Rails.env)
      prefix = ROLE_PREFIXES[role.to_sym]
      return nil if prefix.nil?
      return nil unless Boundary.registered?(boundary)

      STORAGE_CACHE.compute_if_absent("#{rails_env}/#{boundary}/#{prefix}") do
        build_storage(boundary: boundary, prefix: prefix, rails_env: rails_env)
      end
    end

    def build_storage(boundary:, prefix:, rails_env:)
      case mode(rails_env)
      when :memory
        require "shrine/storage/memory"
        Shrine::Storage::Memory.new
      when :local_filesystem
        require "shrine/storage/file_system"
        Shrine::Storage::FileSystem.new(local_root, prefix: "#{boundary}/#{prefix}")
      when :s3
        s3_storage(bucket: Boundary.bucket(boundary), prefix: prefix)
      when :s3_compatible
        s3_compatible_storage(bucket: Boundary.bucket(boundary), prefix: prefix)
      else
        raise ArgumentError, "unsupported object-storage mode"
      end
    end

    # Credentials come from the AWS SDK default provider chain so IAM roles and
    # workload identity keep working; they are never read from application config.
    # `public: true` is deliberately not set: objects stay private, and public
    # delivery is expected to run through a CDN over a private origin.
    def s3_storage(bucket:, prefix:)
      require "shrine/storage/s3"

      if Environment.present?("OBJECT_STORAGE_ENDPOINT")
        raise ArgumentError,
              "OBJECT_STORAGE_ENDPOINT must not be set in production; " \
              "production uses AWS S3 through the platform credential provider"
      end

      Shrine::Storage::S3.new(
        bucket: bucket,
        prefix: prefix,
        region: Environment.fetch("OBJECT_STORAGE_REGION"),
      )
    end

    def s3_compatible_storage(bucket:, prefix:)
      require "shrine/storage/s3"

      Shrine::Storage::S3.new(
        bucket: bucket,
        prefix: prefix,
        endpoint: Environment.fetch("OBJECT_STORAGE_ENDPOINT"),
        region: Environment.fetch("OBJECT_STORAGE_REGION"),
        force_path_style: Environment.fetch_boolean("OBJECT_STORAGE_FORCE_PATH_STYLE"),
        access_key_id: Environment.fetch("OBJECT_STORAGE_ACCESS_KEY_ID"),
        secret_access_key: Environment.fetch("OBJECT_STORAGE_SECRET_ACCESS_KEY"),
      )
    end

    private_class_method :s3_compatible_storage
  end
end

# Zeitwerk expects the flat constant matching the file name.
ObjectStorageShrineConfiguration = ObjectStorage::ShrineConfiguration
