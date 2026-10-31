# typed: false
# frozen_string_literal: true

module OidcSubject
  PREFIXES = {
    "client" => "cli",
    "operator" => "opr",
  }.freeze

  module_function

  def for(resource, resource_type: nil)
    normalized_type = normalize_resource_type(resource_type.nil? ? infer_resource_type(resource) : resource_type)
    raw_subject =
      if resource.respond_to?(:oidc_subject) && resource.oidc_subject.present?
        resource.oidc_subject
      elsif resource.respond_to?(:public_id) && resource.public_id.present?
        resource.public_id
      else
        raise ArgumentError, "OIDC subject requires oidc_subject or public_id"
      end

    "#{prefix_for(normalized_type)}_#{raw_subject}"
  end

  def public_id_from(subject, resource_type:)
    normalized_type = normalize_resource_type(resource_type)
    prefix = "#{prefix_for(normalized_type)}_"
    subject = subject.to_s
    return nil unless subject.start_with?(prefix)

    subject.delete_prefix(prefix).presence
  end

  def normalize_resource_type(resource_type)
    case resource_type.to_s
    when "operator", "staff" then "operator"
    when "client" then "client"
    else raise ArgumentError, "unsupported OIDC resource type"
    end
  end

  def prefix_for(resource_type)
    PREFIXES.fetch(normalize_resource_type(resource_type))
  end

  def infer_resource_type(resource)
    case resource
    when ::Operator then "operator"
    when ::Client then "client"
    else raise ArgumentError, "unsupported OIDC resource"
    end
  end
end
