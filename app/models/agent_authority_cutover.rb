# typed: false
# frozen_string_literal: true

class AgentAuthorityCutover < OrgRpRecord
  CUTOVER_ID = 1

  self.table_name = "agent_authority_cutovers"

  public

  def self.established?
    exists?(id: CUTOVER_ID)
  end

  def self.establish!
    create_or_find_by!(id: CUTOVER_ID)
  end
  public_class_method :established?, :establish!

  def readonly?
    persisted?
  end
end
