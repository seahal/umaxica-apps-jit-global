# typed: false
# frozen_string_literal: true

class AcmeLogoutTransactionCoordinator < ApplicationService
  Result =
    Data.define(:transaction, :status, :error, :error_description) do
      def success? = error.blank?
    end

  def self.issue!(origin_surface:, initiating_client_id:, completion_url:, actor_ref: nil, session_ref: nil,
                  callback_state: nil, now: Time.current, expires_in: 10.minutes, surface: "app",
                  ri: RequestContextContract.default_region)
    persisted_origin_surface = persisted_origin_surface_for(origin_surface)
    region = RequestContextContract.normalize_region(ri)
    unless allowed_completion_url?(
      origin_surface: origin_surface,
      completion_url: completion_url,
      surface: surface,
      ri: region,
    )
      return Result.new(
        transaction: nil,
        status: :rejected,
        error: "invalid_request",
        error_description: "completion destination is not allowlisted",
      )
    end

    transaction =
      AppTicketRecord.connected_to(role: :writing) do
        AcmeLogoutTransaction.create!(
          origin_surface: persisted_origin_surface,
          initiating_client_id: initiating_client_id.to_s,
          completion_url: completion_url.to_s,
          actor_ref: actor_ref.to_s.presence,
          session_ref: session_ref.to_s.presence,
          callback_state: callback_state.to_s.presence,
          expected_step: AcmeLogoutTransaction.step_sequence_for(persisted_origin_surface).first,
          status: AcmeLogoutTransaction::STATUS_INITIATED,
          expires_at: now + expires_in,
          completed_steps: [],
        )
      end

    Result.new(transaction: transaction, status: :issued, error: nil, error_description: nil)
  end

  def self.find_by_logout_challenge!(logout_challenge)
    AcmeLogoutTransaction.find_by!(public_id: logout_challenge.to_s)
  end

  def self.find_by!(logout_challenge:)
    find_by_logout_challenge!(logout_challenge)
  end

  def self.advance!(logout_challenge:, step:, now: Time.current)
    transaction = nil
    AppTicketRecord.connected_to(role: :writing) do
      transaction = find_by_logout_challenge!(logout_challenge)
      transaction.advance_step!(step, now: now)
    end
    Result.new(transaction: transaction.reload, status: :advanced, error: nil, error_description: nil)
  rescue ActiveRecord::RecordNotFound
    Result.new(transaction: nil, status: :missing, error: "not_found", error_description: "logout challenge not found")
  rescue ArgumentError => e
    Result.new(transaction: transaction, status: :rejected, error: "invalid_request", error_description: e.message)
  end

  def self.finalize!(logout_challenge:, now: Time.current)
    transaction = nil
    AppTicketRecord.connected_to(role: :writing) do
      transaction = find_by_logout_challenge!(logout_challenge)
      transaction.finalize!(now: now)
    end
    Result.new(transaction: transaction.reload, status: :finalized, error: nil, error_description: nil)
  rescue ActiveRecord::RecordNotFound
    Result.new(transaction: nil, status: :missing, error: "not_found", error_description: "logout challenge not found")
  rescue ArgumentError => e
    Result.new(transaction: transaction, status: :rejected, error: "invalid_request", error_description: e.message)
  end

  def self.allowed_completion_url?(origin_surface:, completion_url:, surface: "app",
                                   ri: RequestContextContract.default_region)
    expected = completion_url_for(origin_surface: origin_surface, surface: surface, ri: ri)
    expected == completion_url.to_s
  end

  def self.completion_url_for(origin_surface:, ri: RequestContextContract.default_region, surface: "app")
    route_origin_surface = route_origin_surface_for(origin_surface)
    host = completion_host_for(origin_surface: route_origin_surface, surface: surface)
    region = RequestContextContract.normalize_region(ri)

    helper = Rails.application.routes.url_helpers
    surface_name = surface.to_s
    case route_origin_surface
    when "sign"
      helper.public_send(
        complete_auth_out_helper_name(surface_name),
        ri: region,
        host: host,
        protocol: http_or_https(host),
      )
    when "core"
      helper.public_send(
        complete_core_out_helper_name(surface_name),
        ri: region,
        host: host,
        protocol: http_or_https(host),
      )
    when "warp"
      helper.public_send(
        complete_warp_out_helper_name(surface_name),
        ri: region,
        host: host,
        protocol: http_or_https(host),
      )
    when "base", "acme"
      helper.public_send(
        base_completion_helper_name(surface_name),
        ri: region,
        host: host,
        protocol: http_or_https(host),
      )
    when "palm"
      helper.palm_app_sign_out_url(host: host, protocol: http_or_https(host))
    end
  end

  def self.http_or_https(host)
    return "http" if local_host?(host)

    "https"
  end

  def self.local_host?(host)
    normalized_host = host.to_s.downcase
    normalized_host == "localhost" || normalized_host.end_with?(".localhost")
  end

  def self.completion_host_for(origin_surface:, surface:)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    surface_name = surface.to_s
    route_origin_surface = route_origin_surface_for(origin_surface)

    case route_origin_surface
    when "sign"
      case surface_name
      when "org" then hosts.sign_staff.host
      when "com" then hosts.sign_corporate.host
      else hosts.sign_service.host
      end
    when "acme", "base"
      case surface_name
      when "org" then hosts.base_staff.host
      when "com" then hosts.base_corporate.host
      else hosts.base_service.host
      end
    when "core"
      case surface_name
      when "org" then hosts.core_staff.host
      when "com" then hosts.core_corporate.host
      else hosts.core_service.host
      end
    when "warp"
      case surface_name
      when "org" then hosts.warp_staff.host
      when "com" then hosts.warp_corporate.host
      else hosts.warp_service.host
      end
    when "palm"
      hosts.palm_service.host
    else
      raise ArgumentError, "unsupported logout origin surface: #{origin_surface.inspect}"
    end
  end

  def self.complete_auth_out_helper_name(surface_name)
    "auth_#{surface_name}_sign_out_url"
  end

  def self.complete_core_out_helper_name(surface_name)
    "core_#{surface_name}_sign_out_url"
  end

  def self.complete_warp_out_helper_name(surface_name)
    "warp_#{surface_name}_sign_out_url"
  end

  # `side` is the established database enum on acme_logout_transactions. Translate it only at
  # this persistence boundary; request/controller routing uses the Warp name.
  def self.persisted_origin_surface_for(origin_surface)
    (origin_surface.to_s == "warp") ? "side" : origin_surface.to_s
  end

  # Existing logout rows retain the `side` enum value and can still be completed after deployment.
  def self.route_origin_surface_for(origin_surface)
    (origin_surface.to_s == "side") ? "warp" : origin_surface.to_s
  end

  def self.base_completion_helper_name(surface_name)
    "base_#{surface_name}_sign_out_url"
  end
  private_class_method :find_by_logout_challenge!, :allowed_completion_url?,
                       :complete_auth_out_helper_name, :complete_core_out_helper_name,
                       :complete_warp_out_helper_name, :persisted_origin_surface_for,
                       :route_origin_surface_for, :base_completion_helper_name
end
