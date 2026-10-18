# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"
require_relative "../object_storage_environment"
require_relative "../object_storage_boundary"

module ObjectStorageTasks
  module_function

  REQUIRED_ENVIRONMENT = %w(
    OBJECT_STORAGE_ENDPOINT
    OBJECT_STORAGE_REGION
    OBJECT_STORAGE_ACCESS_KEY_ID
    OBJECT_STORAGE_SECRET_ACCESS_KEY
    OBJECT_STORAGE_FORCE_PATH_STYLE
  ).freeze

  def configuration
    values = REQUIRED_ENVIRONMENT.index_with { |name| ObjectStorage::Environment.fetch(name) }

    values.merge(
      "OBJECT_STORAGE_FORCE_PATH_STYLE" =>
        ObjectStorage::Environment.fetch_boolean("OBJECT_STORAGE_FORCE_PATH_STYLE"),
    )
  end

  def client(configuration)
    require "aws-sdk-s3"

    Aws::S3::Client.new(
      endpoint: configuration.fetch("OBJECT_STORAGE_ENDPOINT"),
      region: configuration.fetch("OBJECT_STORAGE_REGION"),
      force_path_style: configuration.fetch("OBJECT_STORAGE_FORCE_PATH_STYLE"),
      credentials: Aws::Credentials.new(
        configuration.fetch("OBJECT_STORAGE_ACCESS_KEY_ID"),
        configuration.fetch("OBJECT_STORAGE_SECRET_ACCESS_KEY"),
      ),
    )
  end

  def boundary_buckets
    ObjectStorage::Boundary.keys.index_with do |boundary|
      ObjectStorage::Boundary.bucket(boundary)
    end
  end

  def ensure_bucket!(client, bucket)
    client.head_bucket(bucket: bucket)
    puts "Object storage bucket exists: #{bucket}"
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
    begin
      client.create_bucket(bucket: bucket)
      puts "Created object storage bucket: #{bucket}"
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou
      client.head_bucket(bucket: bucket)
      puts "Object storage bucket already exists: #{bucket}"
    end
  end

  def smoke!(client, bucket)
    key = "smoke/#{SecureRandom.uuid}"
    expected_body = "Umaxica object storage smoke test: #{key}"
    uploaded = false

    begin
      client.put_object(bucket: bucket, key: key, body: expected_body)
      uploaded = true

      head = client.head_object(bucket: bucket, key: key)
      unless head.content_length == expected_body.bytesize
        raise RuntimeError, "Object size mismatch: expected #{expected_body.bytesize}, got #{head.content_length}"
      end

      response = client.get_object(bucket: bucket, key: key)
      begin
        actual_body = response.body.read
      ensure
        response.body.close
      end
      raise RuntimeError, "Object body mismatch for #{key}" unless actual_body == expected_body

      puts "Object storage PUT, HEAD, and GET succeeded: #{bucket}/#{key}"
    ensure
      if uploaded
        client.delete_object(bucket: bucket, key: key)
        puts "Deleted smoke-test object: #{bucket}/#{key}"
      end
    end

    begin
      client.head_object(bucket: bucket, key: key)
      raise RuntimeError, "Smoke-test object still exists after DELETE: #{bucket}/#{key}"
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      puts "Object storage DELETE verified: #{bucket}/#{key}"
    end
  end

  def ping_endpoint!(endpoint)
    uri = URI.parse(endpoint)
    health = uri.dup
    health.path = "/_fakecloud/health"
    response = Net::HTTP.get_response(health)
    unless response.is_a?(Net::HTTPSuccess)
      raise RuntimeError, "FakeCloud health check failed: #{response.code} #{health}"
    end

    body = JSON.parse(response.body)
    status = body.fetch("status")
    raise RuntimeError, "FakeCloud health status was #{status.inspect}" unless status == "ok"

    puts "FakeCloud reachable: #{health} version=#{body["version"]}"
  end
end

namespace :object_storage do
  desc "Create the configured per-boundary object-storage buckets if they do not exist"
  task prepare: :environment do
    configuration = ObjectStorageTasks.configuration
    client = ObjectStorageTasks.client(configuration)
    ObjectStorageTasks.boundary_buckets.each_value do |bucket|
      ObjectStorageTasks.ensure_bucket!(client, bucket)
    end
  end

  desc "Run a destructive temporary-object smoke test against each boundary bucket"
  task smoke: :environment do
    configuration = ObjectStorageTasks.configuration
    client = ObjectStorageTasks.client(configuration)
    ObjectStorageTasks.boundary_buckets.each_value do |bucket|
      ObjectStorageTasks.ensure_bucket!(client, bucket)
      ObjectStorageTasks.smoke!(client, bucket)
    end
  end

  desc "Verify FakeCloud reachability, buckets, and Shrine attachment persistence"
  task verify: :environment do
    configuration = ObjectStorageTasks.configuration
    ObjectStorageTasks.ping_endpoint!(configuration.fetch("OBJECT_STORAGE_ENDPOINT"))
    client = ObjectStorageTasks.client(configuration)
    buckets = ObjectStorageTasks.boundary_buckets
    buckets.each_value { |bucket| ObjectStorageTasks.ensure_bucket!(client, bucket) }

    png_hex = "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de" \
              "0000000c4944415408d763f80f00000101000518d84e0000000049454e44ae426082"
    png = [png_hex].pack("H*")

    avatar_capability = AvatarCapability.find(AvatarCapability::NORMAL)
    handle = Handle.create!(handle: "verify-#{SecureRandom.hex(6)}", cooldown_until: Time.current)
    avatar = Avatar.create!(
      capability: avatar_capability,
      active_handle: handle,
      moniker: "Object Storage Verify",
    )
    avatar.image = StringIO.new(png)
    avatar.save!
    avatar_key = avatar.image.id
    client.head_object(bucket: buckets.fetch(:avatar), key: "store/#{avatar_key}")
    avatar_row = Avatar.lease_connection.select_one(
      # rubocop:disable I18n/RailsI18n/DecorateString -- sanitize_sql_array is SQL, not an i18n string
      Avatar.sanitize_sql_array(["SELECT image_data FROM avatars WHERE id = ?", avatar.id]),
      # rubocop:enable I18n/RailsI18n/DecorateString
    )
    raise RuntimeError, "Avatar image_data missing in avatar database" if avatar_row["image_data"].blank?

    leaked = PublishingRecord.lease_connection.select_value(
      "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'avatars' AND column_name = 'image_data'",
    )
    raise RuntimeError, "avatars.image_data must not exist on the publishing database" if leaked.to_i.positive?

    media = Publishing::MediaFile.new
    media.file = StringIO.new(png)
    media.save!
    media_key = media.file.id
    client.head_object(bucket: buckets.fetch(:publishing), key: "store/#{media_key}")
    media_row = PublishingRecord.lease_connection.select_one(
      # rubocop:disable I18n/RailsI18n/DecorateString -- sanitize_sql_array is SQL, not an i18n string
      Publishing::MediaFile.sanitize_sql_array(
        ["SELECT file_data FROM publishing_media_files WHERE id = ?", media.id],
      ),
      # rubocop:enable I18n/RailsI18n/DecorateString
    )
    raise RuntimeError, "Publishing file_data missing in publishing database" if media_row["file_data"].blank?

    puts "Avatar upload persisted in avatar DB and #{buckets.fetch(:avatar)}"
    puts "Publishing upload persisted in publishing DB and #{buckets.fetch(:publishing)}"
  end
end
