# typed: false
# frozen_string_literal: true

require "test_helper"
require "timeout"

class RecoverySecretParallelGetTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  fixtures :clients, :visitors

  test "parallel public recovery-secret GETs disclose a receipt once on app and com" do
    surfaces = [
      {
        name: "app",
        actor: clients(:one),
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
        purpose: "client.recovery_secret_credential",
        token_model: ClientToken,
        owner_column: :user_id,
        headers: ->(actor, host) { as_user_headers(actor, host: host) },
        path: ->(token) { base_app_identity_recovery_secret_path(token: token, ri: "jp") },
      },
      {
        name: "com",
        actor: visitors(:reserved_visitor),
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
        purpose: "visitor.recovery_secret_credential",
        token_model: VisitorToken,
        owner_column: :visitor_id,
        headers: ->(actor, host) { as_visitor_headers(actor, host: host) },
        path: ->(token) { base_com_identity_recovery_secret_path(token: token, ri: "jp") },
      },
    ]

    surfaces.each do |surface|
      actor = surface.fetch(:actor)
      host = surface.fetch(:host)
      token_model = surface.fetch(:token_model)
      owner_column = surface.fetch(:owner_column)
      original_token_ids = token_model.where(owner_column => actor.id).pluck(:id)
      original_reveal_ids = SecurityOneTimeReveal.where(
        actor_type: actor.class.name,
        actor_id: actor.id,
        purpose: surface.fetch(:purpose),
      ).pluck(:id)
      session_headers = surface.fetch(:headers).call(actor, host)
      reveal = IdentityOneTimeReveal.issue!(
        actor: actor,
        session_nonce: actor.public_id,
        value: "parallel-#{surface.fetch(:name)}-passcode",
        purpose: surface.fetch(:purpose),
      )
      path = surface.fetch(:path).call(reveal.token)
      ready = Queue.new
      start = Queue.new
      outcomes = Queue.new
      browsers = Array.new(2) { open_session }
      threads =
        browsers.map do |browser|
          # Independent workers are required to exercise the concurrent database boundary.
          Thread.new do # rubocop:disable ThreadSafety/NewThread
            browser.host!(host)
            ready << true
            start.pop
            browser.get(path, headers: session_headers)
            page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")
            props = JSON.parse(page.text).fetch("props")
            outcomes << { status: browser.response.status, passcodes: props.fetch("passcodes") }
          end
        end

      begin
        Timeout.timeout(5) do
          2.times { ready.pop }
          2.times { start << true }
          threads.each(&:value)
        end

        responses = 2.times.map { outcomes.pop }

        assert_equal [200, 200], responses.map { |response| response.fetch(:status) }.sort,
                     "#{surface.fetch(:name)} parallel reveal requests must render successfully"
        assert_equal 1, responses.count { |response|
          response.fetch(:passcodes) == ["parallel-#{surface.fetch(:name)}-passcode"]
        },
                     "#{surface.fetch(:name)} parallel GETs may disclose the receipt once"
        assert_equal 1, responses.count { |response| response.fetch(:passcodes).empty? },
                     "#{surface.fetch(:name)} losing the consume race must disclose no passcode"
      ensure
        threads.each { |thread| thread.kill if thread.alive? }
        threads.each(&:join)
        SecurityOneTimeReveal.where(
          actor_type: actor.class.name,
          actor_id: actor.id,
          purpose: surface.fetch(:purpose),
        ).where.not(id: original_reveal_ids).delete_all
        token_model.where(owner_column => actor.id).where.not(id: original_token_ids).delete_all
      end
    end
  end
end
