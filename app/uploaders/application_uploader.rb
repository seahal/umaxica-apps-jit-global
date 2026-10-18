# typed: false
# frozen_string_literal: true

require "digest"
require "securerandom"

# Base class for every Shrine uploader in this application.
#
# Subclasses declare the storage boundary that owns their attachment:
#
#   class SomeUploader < ApplicationUploader
#     def self.storage_boundary
#       :some_boundary
#     end
#   end
#
# No validation is declared here. Each subclass declares its own MIME type and
# size limits from its resource's actual specification; this base deliberately
# invents no limits. Active content such as SVG must not be allow-listed casually,
# and validate_mime_type is only trustworthy because determine_mime_type
# (analyzer: :marcel) reads the file content rather than the client-supplied type.
#
# Attachment metadata stays in the owner model's own table, on the owner's
# canonical database connection. This class never switches connections and never
# writes to a central attachment table.
class ApplicationUploader < Shrine
  class BoundaryNotDeclaredError < StandardError; end

  class MissingPublicIdError < StandardError; end

  # Declared by each uploader subclass:
  #
  #   def self.storage_boundary
  #     :some_boundary
  #   end
  #
  # An override rather than a writable class attribute, so the boundary is fixed
  # at class-definition time and cannot be mutated at runtime by one request in a
  # way another request would observe.
  def self.storage_boundary
    nil
  end

  def self.storage_boundary!
    storage_boundary ||
      raise(
        BoundaryNotDeclaredError,
        "#{name} must declare self.storage_boundary before it can select a storage",
      )
  end

  # Storage is selected from the uploader's declared boundary alone. It is never
  # derived from Current, Actor, the request host, the session, or cookies, so
  # promotion, deletion, retries, background jobs, and CLI tasks all resolve the
  # same storage as the original request.
  plugin :default_storage,
         cache: -> { :"#{shrine_class.storage_boundary!}_cache" },
         store: -> { :"#{shrine_class.storage_boundary!}_store" }

  plugin :add_metadata

  add_metadata :sha256 do |io, **|
    digest = Digest::SHA256.new
    io.binmode if io.respond_to?(:binmode)
    loop do
      chunk = io.read(16 * 1024)
      break unless chunk

      digest.update(chunk)
    end
    io.rewind if io.respond_to?(:rewind)
    digest.hexdigest
  end

  # Object key layout. This is an internal implementation detail and NOT a public
  # URL contract: it may change, and nothing may treat a generated key as a
  # permanent address. Public delivery URLs are a separate, still-undecided layer.
  #
  # The key is built from the owner's immutable public_id (a 21-character Nanoid
  # assigned once on create) plus a random component. It therefore avoids
  # database-local bigint ids, mutable display names, the original filename, and
  # predictable sequential paths. The random component is also required by Shrine
  # so ORM dirty tracking detects the change.
  #
  # The original filename is deliberately not used, not even for its extension;
  # content type is recorded in metadata instead.
  def generate_location(_io, record: nil, name: nil, **)
    raise ArgumentError, "cannot generate an attachment location without a record" if record.nil?

    if record.public_id.blank? && record.respond_to?(:generate_public_id, true)
      record.send(:generate_public_id)
    end

    public_id = record.try(:public_id)
    if public_id.blank?
      raise MissingPublicIdError,
            "#{record.class.name} must have a public_id before an attachment location " \
            "can be generated; refusing to fall back to a shared namespace"
    end

    [owner_key(record), public_id, name, SecureRandom.hex(16)].compact.join("/")
  end

  private

  def owner_key(record)
    record.class.name.underscore.tr("/", "_")
  end
end
