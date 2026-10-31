# typed: false
# frozen_string_literal: true

# The activity-log controller scopes rows to the current client; this policy gates the actor type.
class ClientChroniclePolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end

  alias_method :show?, :index?
end
