# typed: false
# frozen_string_literal: true

module SignAuthorityRedirect
  extend ActiveSupport::Concern
  include CommonRedirect

  private

  def redirect_to_sign_authority!(path, query: nil)
    redirect_to_surface_url(
      URI::Generic.build(
        scheme: "https",
        host: sign_authority_host,
        path: path,
        query: sign_authority_query(query),
      ).to_s,
      status: :see_other,
    )
  end

  def redirect_to_base_authority!(path, query: nil)
    redirect_to_surface_url(
      URI::Generic.build(
        scheme: "https",
        host: base_authority_host,
        path: path,
        query: sign_authority_query(query),
      ).to_s,
      status: :see_other,
    )
  end

  def sign_authority_query(query_params = nil)
    return query_params.to_query if query_params.present?

    ri = params[:ri].presence
    return if ri.blank?

    { ri: ri }.to_query
  end

  def sign_authority_host
    case self.class.name
    when /\A(Auth::App|Base::App)::/ then ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    when /\A(Auth::Com|Base::Com)::/ then ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    when /\A(Auth::Org|Base::Org)::/ then ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    else
      request.host
    end
  end

  def base_authority_host
    case self.class.name
    when /\AAuth::App::/ then ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    when /\AAuth::Com::/ then ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    when /\AAuth::Org::/ then ENV.fetch("PUBLIC_BASE_STAFF_URL")
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
