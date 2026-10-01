# typed: false
# frozen_string_literal: true

module SignAcmeAuthorityRedirect
  extend ActiveSupport::Concern
  include CommonRedirect

  private

  def redirect_to_base_authority!(path, query: nil)
    redirect_to_jump_url(
      URI::Generic.build(
        scheme: "https",
        host: base_authority_host,
        path: path,
        query: base_authority_query(query),
      ).to_s,
      status: :see_other,
    )
  end

  # The region must survive the hop to Base. Returning a query without `ri` sends the request into
  # Base's own default-region resolution, discarding the region the caller was already browsing in.
  # Controllers reaching here include `Auth::RedirectOnlyController`, which does not run
  # `PreferenceGlobal#set_region`, so `params[:ri]` may be absent or invalid; normalize rather than
  # forward it raw.
  def base_authority_query(query_params = nil)
    query = (query_params || {}).to_h.stringify_keys
    query["ri"] = RequestContextContract.normalize_region(query["ri"].presence || params[:ri])
    query.to_query
  end

  def base_authority_host
    case self.class.name
    when /\AAuth::App::/ then ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    when /\AAuth::Com::/ then ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    when /\AAuth::Org::/ then ENV.fetch("PUBLIC_BASE_STAFF_URL")
    else
      raise JumpRtConfigurationError, "No Base authority is configured for #{self.class.name}"
    end
  end

  def redirect_to_acme_authority!(path, query: nil)
    redirect_to_base_authority!(path, query: query)
  end

  def acme_authority_host
    base_authority_host
  end
end
