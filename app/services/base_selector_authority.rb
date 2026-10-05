# typed: false
# frozen_string_literal: true

# Login-time context selector authority.
#
# Runs during the credential ceremony / first context selection (:private tier, before a
# context is committed). It either auto-selects when the principal has exactly one candidate
# (`prepare`) or validates an explicit choice (`select`). Candidate resolution and persistence
# are shared with the post-login switcher via AcmeSelectableContext.
class BaseSelectorAuthority
  include AcmeSelectableContext

  # Preserve the public error contract: callers rescue BaseSelectorAuthority::InvalidSelection.
  InvalidSelection = AcmeSelectableContext::InvalidSelection

  def self.prepare(surface:, principal:, session:)
    new(surface: surface, principal: principal, session: session).prepare
  end

  def self.select(surface:, principal:, session:, params:)
    new(surface: surface, principal: principal, session: session).select(params)
  end

  def initialize(surface:, principal:, session:)
    @config = AcmeSelector.config_for(surface)
    @principal = principal
    @session = session
  end

  def prepare
    candidates = selectable_candidates
    return selection_required(candidates) unless candidates.one?

    persist_selection!(candidates.first)
    selected
  end

  def select(params)
    candidate = candidate_for_public_ids(params)
    raise InvalidSelection, "invalid_selection" if candidate.blank?

    persist_selection!(candidate)
    selected
  end

  private

  attr_reader :config, :principal, :session

  def selected
    { status: "selected", next: "/dashboard" }
  end

  def selection_required(candidates)
    {
      status: "selection_required",
      accounts: serialize_candidates(candidates),
    }
  end
end
