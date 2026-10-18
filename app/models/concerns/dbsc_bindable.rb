# typed: false
# frozen_string_literal: true

module DbscBindable
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    validates :dbsc_session_id, uniqueness: true, allow_blank: true
  end

  class_methods do
    def dbsc_binding_method_attribute_name
      return :binding_method_id if attribute_names.include?("binding_method_id")
      return :user_token_binding_method_id if attribute_names.include?("user_token_binding_method_id")
      return :staff_token_binding_method_id if attribute_names.include?("staff_token_binding_method_id")
      return :visitor_token_binding_method_id if attribute_names.include?("visitor_token_binding_method_id")

      raise NoMethodError, "No DBSC binding method attribute for #{name}"
    end

    def dbsc_status_attribute_name
      return :dbsc_status_id if attribute_names.include?("dbsc_status_id")
      return :user_token_dbsc_status_id if attribute_names.include?("user_token_dbsc_status_id")
      return :staff_token_dbsc_status_id if attribute_names.include?("staff_token_dbsc_status_id")
      return :visitor_token_dbsc_status_id if attribute_names.include?("visitor_token_dbsc_status_id")

      raise NoMethodError, "No DBSC status attribute for #{name}"
    end

    def dbsc_binding_method_class
      dbsc_binding_method_classes[name]
    end

    def dbsc_status_class
      dbsc_status_classes[name]
    end

    def dbsc_binding_method_classes
      {
        "AppPreference" => AppPreferenceBindingMethod,
        "ComPreference" => ComPreferenceBindingMethod,
        "OrgPreference" => OrgPreferenceBindingMethod,
        "ClientToken" => ClientTokenBindingMethod,
        "OperatorToken" => OperatorTokenBindingMethod,
        "VisitorToken" => VisitorTokenBindingMethod,
      }
    end

    def dbsc_status_classes
      {
        "AppPreference" => AppPreferenceDbscStatus,
        "ComPreference" => ComPreferenceDbscStatus,
        "OrgPreference" => OrgPreferenceDbscStatus,
        "ClientToken" => ClientTokenDbscStatus,
        "OperatorToken" => OperatorTokenDbscStatus,
        "VisitorToken" => VisitorTokenDbscStatus,
      }
    end
  end

  def binding_method_nothing?
    binding_method_value == 0
  end

  def binding_method_dbsc?
    binding_method_value == 1
  end

  def binding_method_legacy?
    binding_method_value == 2
  end

  def dbsc_status_nothing?
    dbsc_status_value == 0
  end

  def dbsc_status_pending?
    dbsc_status_value == self.class.dbsc_status_class::PENDING
  end

  def dbsc_status_active?
    dbsc_status_value == self.class.dbsc_status_class::ACTIVE
  end

  def dbsc_status_failed?
    dbsc_status_value == self.class.dbsc_status_class::FAILED
  end

  def dbsc_status_revoke?
    dbsc_status_value == self.class.dbsc_status_class::REVOKE
  end

  def dbsc_enabled?
    binding_method_dbsc?
  end

  # Downgrade a DBSC registration that was offered but never completed to an
  # explicit non-DBSC (NOTHING) fallback session. Called when a browser-login
  # token issued as LEGACY + PENDING reaches a refresh after its registration
  # challenge has expired without the browser binding. The binding method stays
  # LEGACY so the row reads as a deliberate fallback session rather than an
  # inconsistent "pending forever" one, and downstream refresh checks accept it.
  def downgrade_dbsc_status_to_nothing!
    return if dbsc_status_nothing?

    update!(dbsc_status_attribute => self.class.dbsc_status_class::NOTHING)
  end

  private

  def binding_method_value
    self[dbsc_binding_method_attribute]
  end

  def dbsc_status_value
    self[dbsc_status_attribute]
  end

  def dbsc_binding_method_attribute
    self.class.dbsc_binding_method_attribute_name
  end

  def dbsc_status_attribute
    self.class.dbsc_status_attribute_name
  end
end
