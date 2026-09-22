# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"
# require "helpers/global_test_support"

module Security
  module Invariants
    class ForbiddenPatternsInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      FORBIDDEN_PATTERNS = {
        "mass-assignment permit!" => /\bpermit!/,
        "access policy bypass" => /skip_before_action\s+:enforce_access_policy!/,
        "csrf bypass" => /\bskip_forgery_protection\b/,
        "csrf null_session" => /\bprotect_from_forgery\b.*\bwith:\s*:null_session\b|\bwith:\s*:null_session\b/,
        "unsafe HTML html_safe" => /\bhtml_safe\b/,
        "unsafe HTML raw(...)" => /\braw\s*\(/,
        "thread-local request state" => /\bThread\.current\b/,
        "ignored rescue nil" => /rescue\s+nil\b/,
        "cross-host redirect escape hatch" => /\ballow_other_host:\s*true\b/,
      }.freeze

      SECURITY_LOGGER_PATH_PATTERN =
        %r{\A(?:app|lib)/(?:controllers/concerns/(?:authentication|authorization_audit|sign|oidc)|
                          controllers/sign/|
                          services/(?:chronicle|jit/security|social_auth)|
                          subscribers/jwt_anomaly_subscriber|
                          jit/security)}x

      OIDC_LOGOUT_REDIRECT_RE = Regexp.new(
        'redirect_to\(post_logout_redirect_uri_with_state\(result\), allow_other_host: true, status: :see_other\)',
      )

      # Allowlist entries document existing reviewed exceptions. They are not
      # blanket permission for new uses: the line snippet must still match.
      # Responsibility: owners of the named component must migrate to
      # Rails.logger with JitLogEvent.format or a sanitized audit sink before
      # removing the exception.
      ALLOWLIST = [
        {
          pattern: "access policy bypass",
          path: "app/controllers/concerns/authentication_base.rb",
          line: /skip_before_action :enforce_access_policy! is prohibited/,
          reason: "Policy guard raises on attempts to skip enforce_access_policy!.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/concerns/common_redirect.rb",
          line: /redirect_to\(result\.value, allow_other_host: true/,
          reason: "Only the Jump gateway facade may enable cross-host redirects after token URL validation.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/concerns/sign_oidc_logout.rb",
          line: OIDC_LOGOUT_REDIRECT_RE,
          reason: "OIDC logout must redirect to the RP post-logout URI after state validation.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/concerns/oidc_callback.rb",
          line: /redirect_to\(sign_in_url_with_pt\(nil\), alert: I18n\.t\("errors\.messages\.login_required"\),
                \s*allow_other_host: true\)/,
          reason: "OIDC callback failure must send the browser back to the sign-in surface " \
                  "through the reviewed RP redirect.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/concerns/oidc_rp_logout_launcher.rb",
          line: /allow_other_host: true,/,
          reason: "OIDC RP logout must hand the browser to Acme for the reviewed end-session flow.",
        },
        {
          pattern: "csrf bypass",
          path: "app/controllers/concerns/csp_violation_report.rb",
          line: /skip_forgery_protection\(only: :create\)/,
          reason: "CSP reports are browser sensor inputs, not session form mutations; " \
                  "create still rate limits and reads bounded bodies only.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/acme/app/oauth/protocol_controller.rb",
          line: /with: :null_session/,
          reason: [
            "Acme OAuth token exchange is a server-to-server protocol endpoint",
            "and must not use browser session CSRF handling.",
          ].join(" "),
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/acme/app/oauth/tokens_controller.rb",
          line: /with: :null_session/,
          reason: "Acme OAuth token exchange is a server-to-server protocol endpoint " \
                  "and does not use browser session CSRF.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/sign/app/tokens_controller.rb",
          line: /protect_from_forgery with: :null_session, only: :create/,
          reason: "OIDC token exchange uses client auth and PKCE, not browser session CSRF.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/sign/com/tokens_controller.rb",
          line: /protect_from_forgery with: :null_session, only: :create/,
          reason: "OIDC token exchange uses client auth and PKCE, not browser session CSRF.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/sign/org/tokens_controller.rb",
          line: /protect_from_forgery with: :null_session, only: :create/,
          reason: "OIDC token exchange uses client auth and PKCE, not browser session CSRF.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/sign/app/oauth/base_controller.rb",
          line: /protect_from_forgery with: :null_session/,
          reason: "OAuth protocol endpoints use client auth or bearer tokens and skip Rails browser session state.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/sign/com/oauth/base_controller.rb",
          line: /protect_from_forgery with: :null_session/,
          reason: "OAuth protocol endpoints use client auth or bearer tokens and skip Rails browser session state.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/sign/org/oauth/base_controller.rb",
          line: /protect_from_forgery with: :null_session/,
          reason: "OAuth protocol endpoints use client auth or bearer tokens and skip Rails browser session state.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/sign/app/oidc/backchannel/logouts_controller.rb",
          line: /protect_from_forgery with: :null_session/,
          reason: "OIDC backchannel logout is a server-to-server callback and does not use browser session CSRF.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/sign/com/oidc/backchannel/logouts_controller.rb",
          line: /protect_from_forgery with: :null_session/,
          reason: "OIDC backchannel logout is a server-to-server callback and does not use browser session CSRF.",
        },
        {
          pattern: "csrf null_session",
          path: "app/controllers/sign/org/oidc/backchannel/logouts_controller.rb",
          line: /protect_from_forgery with: :null_session/,
          reason: "OIDC backchannel logout is a server-to-server callback and does not use browser session CSRF.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/auth/app/sign/ins_controller.rb",
          line: /\A\s*allow_other_host: true,\s*\z/,
          reason: "Auth app sign-in sends authenticated browsers to the reviewed Base dashboard host.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/auth/app/sign/outs_controller.rb",
          line: /allow_other_host: true,/,
          reason: "The coordinated sign-out continuation returns the browser to the reviewed " \
                  "Base completion page after the auth-host cleanup hop.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/auth/com/sign/outs_controller.rb",
          line: /allow_other_host: true,/,
          reason: "Auth com sign-out uses only the configured Base com route for the fixed authority handoff.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/auth/app/sign/ups_controller.rb",
          line: /\A\s*allow_other_host: true,\s*\z/,
          reason: "Auth app sign-up sends authenticated browsers to the reviewed Base dashboard host.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/auth/org/sign/in/entra/authorizations_controller.rb",
          line: /allow_other_host: true,/,
          reason: "Org Entra sign-in completion returns through the reviewed RP resume URL.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/auth/org/sign/outs_controller.rb",
          line: /allow_other_host: true,/,
          reason: "Auth org sign-out uses only the configured Base org route for the fixed authority handoff.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/concerns/oidc_callback.rb",
          line: /redirect_to\(sign_in_url_with_pt\(nil\), allow_other_host: true\)/,
          reason: "OIDC callback failure must send the browser back to the sign-in surface.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/concerns/oidc_sso_initiator.rb",
          line: /redirect_to\(url, allow_other_host: true,/,
          reason: "OIDC SSO initiation hands the browser to the reviewed authorization endpoint.",
        },
      ].freeze

      LOGGER_ALLOWLIST = [].freeze

      RAW_ACTOR_CLAIMS_ALLOWLIST = [
        {
          path: "app/controllers/auth/app/application_controller.rb",
          line: /Actor\.authn\.access_claims/,
          reason: "Current auth app controller records assurance metadata from the decoded token boundary.",
        },
        {
          path: "app/controllers/auth/com/application_controller.rb",
          line: /Actor\.authn\.access_claims/,
          reason: "Current auth com controller records assurance metadata from the decoded token boundary.",
        },
        {
          path: "app/controllers/auth/org/application_controller.rb",
          line: /Actor\.authn\.access_claims/,
          reason: "Current auth org controller records assurance metadata from the decoded token boundary.",
        },
        {
          path: "app/controllers/base/app/oauth/authorizations_controller.rb",
          line: /Actor\.authn\.access_claims/,
          reason: "Current OAuth launch code forwards assurance metadata to the protocol boundary.",
        },
        {
          path: "app/controllers/base/com/oauth/authorizations_controller.rb",
          line: /Actor\.authn\.access_claims/,
          reason: "Current OAuth launch code forwards assurance metadata to the protocol boundary.",
        },
        {
          path: "app/controllers/base/org/oauth/authorizations_controller.rb",
          line: /Actor\.authn\.access_claims/,
          reason: "Current OAuth launch code forwards assurance metadata to the protocol boundary.",
        },
        {
          path: "app/controllers/concerns/auth_oidc_result_handoff.rb",
          line: /Actor\.authn\.access_claims/,
          reason: "OIDC result handoff forwards the authenticated ceremony assurance metadata to Base.",
        },
        {
          path: "app/controllers/concerns/actor_support.rb",
          line: /token_claims: authn\.access_claims/,
          reason: "ActorSupport installs the decoded authn snapshot at the request boundary.",
        },
        {
          path: "app/controllers/concerns/authentication_base.rb",
          line: /token_claims: authn\.access_claims/,
          reason: "AuthenticationBase bridges authenticated resource resolution into Actor authz.",
        },
        {
          path: "app/controllers/concerns/sign_out_notice.rb",
          line: /access_expires_at_from_claims\(Actor\.authn\.access_claims\)/,
          reason: "Sign-out notice derives display expiry from the current token snapshot.",
        },
        {
          path: "app/controllers/concerns/sign_up_sequence_controller_support.rb",
          line: /access_claims: Actor\.authn\.access_claims/,
          reason: "Sign-up support passes the authenticated token snapshot through the existing boundary.",
        },
        {
          path: "app/policies/application_policy.rb",
          line: /Actor\.authz\.token_claims/,
          reason: "ApplicationPolicy is the reviewed policy boundary for current raw authz claims.",
        },
        {
          path: "app/services/oidc_end_session_request.rb",
          line: /Actor\.authn\.access_claims/,
          reason: "OIDC end-session uses the current sid claim at the protocol boundary.",
        },
      ].freeze

      test "allowlist entries have explicit reasons" do
        missing_reasons =
          (ALLOWLIST + LOGGER_ALLOWLIST + RAW_ACTOR_CLAIMS_ALLOWLIST).filter_map do |entry|
            "#{entry[:path]} #{entry[:pattern]}" if entry.fetch(:reason).blank?
          end

        assert_empty missing_reasons, "Forbidden-pattern allowlist entries require reasons"
      end

      test "production code does not introduce forbidden security patterns" do
        offenders =
          production_code_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              pattern_name = FORBIDDEN_PATTERNS.find { |_name, pattern| line.match?(pattern) }&.first
              next unless pattern_name
              next if allowlisted?(ALLOWLIST, pattern_name, relative_path, line)

              "#{relative_path}:#{line_number}: #{pattern_name}: #{line.strip}"
            end
          end

        assert_empty offenders, "Forbidden security patterns found:\n#{offenders.join("\n")}"
      end

      test "authentication audit and security code uses structured logger error calls" do
        offenders =
          production_code_paths.filter_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            next unless relative_path.match?(SECURITY_LOGGER_PATH_PATTERN)

            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
            lines = content.lines
            lines.each_with_index.filter_map do |line, index|
              next unless line.match?(/\bRails\.logger\.error\b/)
              next if lines[index, 4].join.include?("JitLogEvent.format(")
              next if allowlisted?(LOGGER_ALLOWLIST, nil, relative_path, line)

              line_number = index + 1
              "#{relative_path}:#{line_number}: direct Rails.logger.error: #{line.strip}"
            end
          end.flatten

        assert_empty offenders,
                     "Use Rails.logger.error(JitLogEvent.format(...)) or a sanitized audit sink instead:\n" \
                     "#{offenders.join("\n")}"
      end

      test "raw Actor token claims access stays inside reviewed boundaries" do
        raw_claims_pattern = /Actor\.(?:authn|authz)\.(?:access_claims|token_claims)\b/
        offenders =
          production_code_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(raw_claims_pattern)
              next if allowlisted?(RAW_ACTOR_CLAIMS_ALLOWLIST, nil, relative_path, line)

              "#{relative_path}:#{line_number}: raw Actor token claims access: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Use typed Actor readers or add an explicit reviewed boundary reason:\n" \
                     "#{offenders.join("\n")}"
      end

      private

      def production_code_paths
        Rails.root.glob("{app,lib}/**/*").select do |path|
          File.file?(path) &&
            path.extname.in?(%w(.rb .erb .rake)) &&
            path.to_s.exclude?("/app/assets/builds/")
        end
      end

      def allowlisted?(entries, pattern_name, path, line)
        entries.any? do |entry|
          (pattern_name.nil? || entry[:pattern] == pattern_name) &&
            entry.fetch(:path) == path &&
            line.match?(entry.fetch(:line))
        end
      end
    end
  end
end
