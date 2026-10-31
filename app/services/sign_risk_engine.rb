# typed: false
# frozen_string_literal: true

class SignRiskEngine
  WINDOW = 5.minutes

  # Returns integer score 0..100
  def self.score(user_id: nil, staff_id: nil)
    return 0 unless user_id || staff_id

    window_start = WINDOW.ago

    if staff_id
      score_for_staff(staff_id, window_start)
    else
      score_for_user(user_id, window_start)
    end
  end

  def self.score_for_user(user_id, window_start)
    scope = ClientOccurrence
      .where("event_type LIKE ?", "risk.%")
      .where("context @> ?", { user_id: user_id }.to_json)
      .where(created_at: window_start..)

    evaluate_rules(scope)
  end

  def self.score_for_staff(staff_id, window_start)
    scope = OperatorOccurrence
      .where("event_type LIKE ?", "risk.%")
      .where("context @> ?", { staff_id: staff_id }.to_json)
      .where(created_at: window_start..)

    evaluate_rules(scope)
  end

  # IP/ASN-anomaly hard revocation is feature-flagged for staged rollout
  # (see adr/ip-anomaly-session-revocation.md). Default OFF everywhere; opt in
  # explicitly via IP_ANOMALY_REVOKE_ENABLED or config.x.ip_anomaly_revoke.enabled
  # so the mobile-network false-positive rate can be monitored before any
  # default-on decision. While off, ip_change_detected is recorded as a signal
  # only and does not score.
  def self.ip_anomaly_revoke_enabled?
    ENV.fetch("IP_ANOMALY_REVOKE_ENABLED", "false") == "true" ||
      !!Rails.configuration.try(:x).try(:ip_anomaly_revoke).try(:enabled)
  end

  def self.evaluate_rules(scope)
    # Rule 1: Refresh Token Reuse Detected -> 100
    if scope.exists?(event_type: "risk.refresh_reuse_detected")
      return 100
    end

    # Rule 1b: Same-session coarse-network change (possible stolen-cookie
    # replay from another network) -> 100, only when the feature flag is on.
    if ip_anomaly_revoke_enabled? && scope.exists?(event_type: "risk.ip_change_detected")
      return 100
    end

    # Rule 2: Auth Failed 5+ times in window -> 60
    if scope.where(event_type: "risk.auth_failed").count >= 5
      return 60
    end

    # Rule 3: Refresh Failed 5+ times in window -> 40
    if scope.where(event_type: "risk.refresh_failed").count >= 5
      return 40
    end

    0
  end

  private_class_method :score_for_user, :score_for_staff, :evaluate_rules
end
