# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Security
  module Invariants
    class ActorContextInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "app owned current attributes subclass is only Actor" do
        Rails.application.eager_load!

        app_owned =
          ActiveSupport::CurrentAttributes.descendants.filter_map do |klass|
            location = Object.const_source_location(klass.name)&.first
            next unless location&.start_with?(Rails.root.join("app").to_s)

            klass.name
          end

        assert_equal ["Actor"], app_owned.sort
      end

      test "normal application layers do not write Actor directly" do
        offenders =
          normal_application_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(/\bActor\.(?:update\b|[a-zA-Z_]+\s*=)/)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders, "Actor writes must go through lifecycle installer code:\n#{offenders.join("\n")}"
      end

      test "Actor install_context is limited to reviewed lifecycle boundaries" do
        allowlist = [
          "app/controllers/concerns/actor_support.rb",
          "app/controllers/concerns/authentication_base.rb",
          "app/controllers/concerns/authentication_jwt_tokens.rb",
          "app/controllers/concerns/base_step_up_completion.rb",
          "app/controllers/concerns/core_browser_api_boundary.rb",
          "app/controllers/concerns/verification_base.rb",
        ]

        offenders =
          Rails.root.glob("app/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            next [] if allowlist.include?(relative_path)

            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
            content.each_line.with_index(1).filter_map do |line, line_number|
              next if line.lstrip.start_with?("#")
              next unless line.match?(/\bActor\.install_context!/)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Actor.install_context! must stay inside request lifecycle boundaries:\n#{offenders.join("\n")}"
      end

      test "request id is never used as an OpenTelemetry trace id" do
        paths = [
          Rails.root.join("app/controllers/concerns/actor_support.rb"),
          Rails.root.join("app/controllers/concerns/core_browser_api_boundary.rb"),
        ]

        offenders =
          paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            path.read.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(/trace_id\s*[:=]\s*request\.request_id/)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "request_id must never substitute for an OpenTelemetry trace_id:\n#{offenders.join("\n")}"
      end

      test "old Actor authentication and preference APIs are not used" do
        offenders =
          Rails.root.glob("{app,test}/**/*").flat_map do |path|
            next [] unless File.file?(path) && path.extname.in?(%w(.rb .erb))

            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next if relative_path == "test/security/invariants/actor_context_invariant_test.rb"
              next unless line.match?(/\bActor\.(?:authentication|preference)\b/)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders, "Use Actor.authn and Actor.preferences instead:\n#{offenders.join("\n")}"
      end

      test "Actor read paths stay shallow except configuration namespaces" do
        offenders =
          normal_application_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            actor_context_depth_offenses_in_content(relative_path, content)
          end

        assert_empty offenders, "Actor reads must stay shallow:\n#{offenders.join("\n")}"
      end

      test "Actor read path depth rule permits only configuration namespace values" do
        content = <<~RUBY
          Actor.authn.login_public_id
          Actor.configuration.sign.value
          Actor.configuration.sign.value.raw
          Actor.authz.policy.user.account.id
          Actor.step_up.challenge.email.otp.verified_at
        RUBY

        offenders = actor_context_depth_offenses_in_content("sample.rb", content)

        assert_equal(
          [
            "sample.rb:3: Actor.configuration.sign.value.raw",
            "sample.rb:4: Actor.authz.policy.user.account.id",
            "sample.rb:5: Actor.step_up.challenge.email.otp.verified_at",
          ],
          offenders,
        )
      end

      private

      def normal_application_paths
        Rails.root.glob("{app/controllers,app/services,app/policies,app/views}/**/*").select do |path|
          File.file?(path) && path.extname.in?(%w(.rb .erb))
        end
      end

      def actor_context_depth_offenses_in_content(relative_path, content)
        content.each_line.with_index(1).flat_map do |line, line_number|
          line.scan(/\bActor((?:\.[a-zA-Z_]\w*[!?]?)+)/).filter_map do |match|
            chain = match.first
            segments = chain.scan(/\.([a-zA-Z_]\w*[!?]?)/).flatten
            next if allowed_actor_read_path?(segments)

            " #{line.strip}".match(/\s(Actor#{Regexp.escape(chain)})/)[1].then do |read_path|
              "#{relative_path}:#{line_number}: #{read_path}"
            end
          end
        end
      end

      def allowed_actor_read_path?(segments)
        return true if segments.length <= 2

        segments.length == 3 && segments.first == "configuration"
      end
    end
  end
end
