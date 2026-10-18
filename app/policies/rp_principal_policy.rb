# typed: false
# frozen_string_literal: true

# A cell's local principal (R5-WU17) may see its own signed-in pages and nothing else. The cell
# holds no roles or canonical attributes; every business decision beyond "this is me" belongs to
# an HTTPS owner.
class RpPrincipalPolicy < ApplicationPolicy
  public

  def show?
    user.present? && user == record
  end
end
