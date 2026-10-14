# typed: false
# frozen_string_literal: true

class AcmeLogoutTransactionCoordinator < ApplicationService
  Result =
    Data.define(:transaction, :status, :error, :error_description) do
      def success? = error.blank?
    end

  def self.issue!(origin_surface:, initiating_client_id:, completion_url:, actor_ref: nil, session_ref: nil,
                  callback_state: nil, now: Time.current, expires_in: 10.minutes, surface: "app",
                  ri: RequestContextContract.default_region,
                  workflow: AcmeLogoutTransaction::LEGACY_WORKFLOW, binding_version: nil, realm: nil,
                  parent_session_ref: nil, captured_root_ref: nil, root_refresh_family_ref: nil,
                  captured_root_generation: nil, origin_intent_digest: nil)
    persisted_origin_surface = origin_surface.to_s
    persisted_workflow = workflow.to_s
    region = RequestContextContract.normalize_region(ri)
    issue_rejection = issue_rejection_for(
      origin_surface: origin_surface,
      persisted_origin_surface: persisted_origin_surface,
      persisted_workflow: persisted_workflow,
      completion_url: completion_url,
      surface: surface,
      ri: region,
    )
    return rejected_result(issue_rejection) if issue_rejection

    binding_attributes = browser_rp_binding_attributes(
      workflow: persisted_workflow,
      binding_version: binding_version,
      realm: realm,
      parent_session_ref: parent_session_ref,
      captured_root_ref: captured_root_ref,
      root_refresh_family_ref: root_refresh_family_ref,
      captured_root_generation: captured_root_generation,
      origin_intent_digest: origin_intent_digest,
    )
    return rejected_result("Browser RP authority binding is required") if binding_attributes.nil?

    transaction_attributes = {
      origin_surface: persisted_origin_surface,
      workflow: persisted_workflow,
      initiating_client_id: initiating_client_id.to_s,
      completion_url: completion_url.to_s,
      actor_ref: actor_ref.to_s.presence,
      session_ref: session_ref.to_s.presence,
      callback_state: callback_state.to_s.presence,
      **binding_attributes,
      expected_step: AcmeLogoutTransaction.step_sequence_for(
        persisted_origin_surface,
        workflow: persisted_workflow,
      ).first,
    }
    transaction = persist_transaction!(transaction_attributes, now:, expires_in:)

    Result.new(transaction: transaction, status: :issued, error: nil, error_description: nil)
  end

  def self.browser_rp_binding_for(session_record:, resource_type:, origin_intent_digest:)
    device_session = session_record.parent_device_session
    root_token = session_record.parent_token
    raise RpSession::IssuanceRejected, "Browser Session device session is missing" unless device_session
    raise RpSession::IssuanceRejected, "Browser Session current root token is missing" unless root_token

    refresh_family_ref = root_token.refresh_token_family_id.presence || device_session.refresh_token_family_id.presence
    raise RpSession::IssuanceRejected, "Browser Session refresh family is missing" if refresh_family_ref.blank?

    {
      binding_version: AcmeLogoutTransaction::BINDING_VERSION_BROWSER_RP,
      realm: { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(resource_type.to_s),
      parent_session_ref: device_session.public_id,
      captured_root_ref: root_token.public_id,
      root_refresh_family_ref: refresh_family_ref,
      captured_root_generation: Integer(root_token.refresh_token_generation),
      origin_intent_digest: origin_intent_digest.to_s.b,
    }
  rescue KeyError
    raise RpSession::IssuanceRejected, "unsupported Browser RP resource type"
  rescue ArgumentError, TypeError
    raise RpSession::IssuanceRejected, "Browser Session root generation is invalid"
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
    route_origin_surface = origin_surface.to_s
    host = completion_host_for(origin_surface: route_origin_surface, surface: surface)
    region = RequestContextContract.normalize_region(ri)
    completion_route_url(
      origin_surface: route_origin_surface,
      surface: surface.to_s,
      region: region,
      host: host,
    )
  end

  def self.completion_route_url(origin_surface:, surface:, region:, host:)
    helper = Rails.application.routes.url_helpers
    options = { ri: region, host: host, protocol: http_or_https(host) }
    case [origin_surface, surface]
    when ["sign", "app"] then helper.auth_app_sign_out_url(**options)
    when ["sign", "com"] then helper.auth_com_sign_out_url(**options)
    when ["sign", "org"] then helper.auth_org_sign_out_url(**options)
    when ["core", "app"] then helper.core_app_sign_out_completion_url(**options)
    when ["core", "com"] then helper.core_com_sign_out_completion_url(**options)
    when ["core", "org"] then helper.core_org_sign_out_completion_url(**options)
    when ["warp", "app"] then helper.warp_app_sign_out_completion_url(**options)
    when ["warp", "com"] then helper.warp_com_sign_out_completion_url(**options)
    when ["warp", "org"] then helper.warp_org_sign_out_completion_url(**options)
    when ["edit", "org"]
      helper.edit_org_sign_out_completion_url(**options)
    when ["tech", "org"]
      helper.tech_org_sign_out_completion_url(**options)
    when ["base", "app"], ["acme", "app"]
      helper.base_app_sign_out_completion_url(**options)
    when ["base", "com"], ["acme", "com"]
      helper.base_com_sign_out_completion_url(**options)
    when ["base", "org"], ["acme", "org"]
      helper.base_org_sign_out_completion_url(**options)
    when ["palm", "app"]
      helper.palm_app_sign_out_completion_url(**options)
    else
      raise ArgumentError, "unsupported logout completion route: #{origin_surface.inspect}/#{surface.inspect}"
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
    route_origin_surface = origin_surface.to_s

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
    when "edit"
      hosts.edit_staff.host
    when "palm"
      hosts.palm_service.host
    when "tech"
      hosts.tech_staff.host
    else
      raise ArgumentError, "unsupported logout origin surface: #{origin_surface.inspect}"
    end
  end

  def self.rejected_result(description)
    Result.new(
      transaction: nil,
      status: :rejected,
      error: "invalid_request",
      error_description: description,
    )
  end

  def self.browser_rp_binding_attributes(workflow:, binding_version:, realm:, parent_session_ref:, captured_root_ref:,
                                         root_refresh_family_ref:, captured_root_generation:, origin_intent_digest:)
    return { binding_version: AcmeLogoutTransaction::BINDING_VERSION_LEGACY } unless
      workflow == AcmeLogoutTransaction::BROWSER_RP_WORKFLOW

    return if binding_version.to_i != AcmeLogoutTransaction::BINDING_VERSION_BROWSER_RP
    return if realm.blank? || parent_session_ref.blank? || captured_root_ref.blank?
    return if root_refresh_family_ref.blank? || captured_root_generation.nil? || origin_intent_digest.blank?

    {
      binding_version: AcmeLogoutTransaction::BINDING_VERSION_BROWSER_RP,
      realm: realm.to_s,
      parent_session_ref: parent_session_ref.to_s,
      captured_root_ref: captured_root_ref.to_s,
      root_refresh_family_ref: root_refresh_family_ref.to_s,
      captured_root_generation: Integer(captured_root_generation),
      origin_intent_digest: origin_intent_digest.to_s.b,
    }
  rescue ArgumentError, TypeError
    nil
  end

  def self.issue_rejection_for(origin_surface:, persisted_origin_surface:, persisted_workflow:, completion_url:,
                               surface:, ri:)
    return "unsupported logout workflow" unless AcmeLogoutTransaction::WORKFLOWS.include?(persisted_workflow)
    if persisted_workflow == AcmeLogoutTransaction::BROWSER_RP_WORKFLOW &&
        AcmeLogoutTransaction::BROWSER_RP_ORIGIN_SURFACES.exclude?(persisted_origin_surface)
      return "unsupported Browser RP logout origin"
    end

    "completion destination is not allowlisted" unless allowed_completion_url?(
      origin_surface:,
      completion_url:,
      surface:,
      ri:,
    )
  end

  def self.persist_transaction!(attributes, now:, expires_in:)
    AppTicketRecord.connected_to(role: :writing) do
      AcmeLogoutTransaction.create!(
        **attributes,
        status: AcmeLogoutTransaction::STATUS_INITIATED,
        expires_at: now + expires_in,
        completed_steps: [],
      )
    end
  end

  public_class_method :browser_rp_binding_for
  private_class_method :completion_route_url, :find_by_logout_challenge!, :allowed_completion_url?, :rejected_result,
                       :browser_rp_binding_attributes, :issue_rejection_for, :persist_transaction!
end
