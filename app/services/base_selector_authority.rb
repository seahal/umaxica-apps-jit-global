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

  def self.selection_options(surface:, principal:)
    new(surface: surface, principal: principal, session: nil).selection_options
  end

  def initialize(surface:, principal:, session:)
    @config = AcmeSelector.config_for(surface)
    @principal = principal
    @session = session
  end

  def prepare
    candidates = selector_candidates
    if session.instance_of?(RpBaseAppSession) || session.instance_of?(RpBaseOrgSession)
      return selected if session.selected_actor_context?
      return selection_required(candidates) unless candidates.one?

      persist_selection!(candidates.first, once: true)
      return selected
    end
    return selection_required(candidates) unless candidates.one?

    persist_selection!(candidates.first, once: true)
    selected
  rescue AcmeSelectableContext::SelectionAlreadyEstablished
    raise unless session&.selected_actor_context?

    selected
  end

  def selection_options
    candidates = selector_candidates
    {
      status: "selection_required",
      accounts: serialize_candidates(candidates),
    }
  end

  def select(params)
    candidate = candidate_for_public_ids(params)
    raise InvalidSelection, "invalid_selection" if candidate.blank?

    persist_selection!(candidate, once: true)
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

  def selector_candidates
    candidates = selectable_candidates
    return candidates unless config.avatar_mode == :optional

    candidates.select { |candidate| candidate.dig(:public, :avatar_public_id).blank? }
  end
end
