# typed: false
# frozen_string_literal: true

# Presentation helpers shared by the org administration screens (Support, Enforcement, IAM):
# the acting-operator/realm context every page states, a bounded exact-identifier search input, a
# bounded page number, and a fresh operation id for each confirmation screen.
#
# It holds no authorization, Step-Up, or persistence. Each including controller declares those
# itself. Contract: the including controller provides `current_operator`.
module OrgAdministrationPage
  extend ActiveSupport::Concern

  PER_PAGE = 25
  MAX_PAGE = 400
  MAX_QUERY_LENGTH = 64
  QUERY_FORMAT = /\A[0-9A-Za-z_-]+\z/

  private

  def admin_context(realm:)
    {
      operator_label: t("base.org.admin.context.operator"),
      operator_public_id: current_operator.public_id,
      realm_label: realm.nil? ? nil : t("base.org.admin.context.realm"),
      realm: realm,
    }
  end

  # An exact public identifier, or nil when absent or empty. Anything else (including surrounding
  # whitespace or a NUL, which String#strip would silently remove) is a malformed request, not a
  # search that quietly matches something else.
  def admin_query
    value = params[:q]
    return nil if value.nil? || value == ""
    raise ActionController::BadRequest, "q must be a string" unless value.is_a?(String)
    raise ActionController::BadRequest, "q is too long" if value.length > MAX_QUERY_LENGTH
    raise ActionController::BadRequest, "q is malformed" unless QUERY_FORMAT.match?(value)

    value
  end

  def admin_page
    value = params[:page]
    return 1 if value.nil? || value == ""
    raise ActionController::BadRequest,
          "page is malformed" unless value.is_a?(String) && value.match?(/\A[1-9]\d{0,3}\z/)

    page = value.to_i
    raise ActionController::BadRequest, "page is out of range" if page > MAX_PAGE

    page
  end

  # Loads one page plus one extra row to learn whether a next page exists without a COUNT.
  def admin_paginate(relation)
    page = admin_page
    rows = relation.offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    [rows.first(PER_PAGE), page, rows.length > PER_PAGE]
  end

  def admin_pagination_links(page:, more:, path_builder:)
    {
      previous: (page > 1) ? { label: t("base.org.admin.pagination.previous"),
                               href: path_builder.call(page - 1), } : nil,
      next: more ? { label: t("base.org.admin.pagination.next"), href: path_builder.call(page + 1) } : nil,
    }
  end

  def admin_operation_id
    SecureRandom.uuid
  end

  def admin_time(value)
    value.nil? ? t("base.org.admin.values.none") : I18n.l(value, format: :long)
  end
end
