# typed: false
# frozen_string_literal: true

module SignAcmeAuthorityRedirect
  extend ActiveSupport::Concern

  private

  def redirect_to_base_authority!(path, query: nil)
    redirect_to(
      URI::Generic.build(
        scheme: request.scheme,
        host: base_authority_host,
        path: path,
        query: base_authority_query(query),
      ).to_s,
      allow_other_host: cross_host_redirect_allowed?,
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
    when /\A(Auth::App|Sign::App|Acme::App)::/ then ENV.fetch("PRIVATE_BASE_SERVICE_URL")
    when /\A(Auth::Com|Sign::Com|Acme::Com)::/ then ENV.fetch("PRIVATE_BASE_CORPORATE_URL")
    when /\A(Auth::Org|Sign::Org|Acme::Org)::/ then ENV.fetch("PRIVATE_BASE_STAFF_URL")
    else
      request.host
    end
  end

  def redirect_to_acme_authority!(path, query: nil)
    redirect_to_base_authority!(path, query: query)
  end

  def acme_authority_host
    base_authority_host
  end
end
