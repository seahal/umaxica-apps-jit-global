# typed: false
# frozen_string_literal: true

module Notify
  # Base for every notifier in this application.
  #
  # Notifiers answer "which message goes to whom, over which channels". They do
  # not talk to a provider: each delivery method calls the existing transport --
  # the surface mailers or OutboundSms -- so the outbound kill switches and
  # encryption boundaries stay in one place.
  #
  # Noticed::Ephemeral rather than Noticed::Event: this application has no in-app
  # notification records, so there is nothing to persist and no noticed_events or
  # noticed_notifications table exists. Individual notifiers validate their inputs
  # before putting them in delivery parameters.
  #
  # See adr/notification-orchestration-via-noticed.md.
  class ApplicationNotifier < Noticed::Ephemeral
  end
end
