# frozen_string_literal: true

# Committed-transaction tests delete their own rows in teardown. A sign-out there writes OP
# authority-stop rows that reference its roots and grants ON DELETE RESTRICT, so they go first.
module AuthorityStopCleanup
  CHILDREN = %w(BrowserLogout Participant EpochCutoff GrantTarget RootTarget).freeze

  def delete_authority_stops_for!(realm:, root_ids: [], grant_ids: [], stop_ids: [])
    prefix = "Op#{realm.to_s.capitalize}AuthorityStop"
    affected_stop_ids = Array(stop_ids).compact +
      "#{prefix}RootTarget".constantize.where(root_id: Array(root_ids).compact).pluck(:stop_id) +
      "#{prefix}GrantTarget".constantize.where(grant_id: Array(grant_ids).compact).pluck(:stop_id)
    affected_stop_ids.uniq!
    CHILDREN.each { |suffix| "#{prefix}#{suffix}".constantize.where(stop_id: affected_stop_ids).delete_all }
    prefix.constantize.where(id: affected_stop_ids).delete_all
  end
end
