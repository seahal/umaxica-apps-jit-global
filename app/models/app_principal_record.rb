# typed: false
# frozen_string_literal: true

# Semantic principal/actor base backed by the consolidated app zenith database.
class AppPrincipalRecord < AppZenithRecord
  self.abstract_class = true
  self.strict_loading_by_default = true
end
