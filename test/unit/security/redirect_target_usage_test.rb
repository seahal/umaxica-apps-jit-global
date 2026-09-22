# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectTargetUsageTest < ActiveSupport::TestCase
  DIRECT_PARAM_REDIRECT = /redirect_to\s*\(?\s*params\[/.freeze
  DIRECT_ALLOW_OTHER_HOST = /allow_other_host:\s*true/.freeze
  RAW_PT_PARAM = /\bparams\[:pt\]/.freeze
  LEGACY_XT_REDIRECT = /\bredirect_to_xt(?:_url)?\b/.freeze

  ALLOW_OTHER_HOST_ALLOWLIST = %w(
    app/controllers/auth/app/sign/in/sessions_controller.rb
    app/controllers/auth/app/sign/ins_controller.rb
    app/controllers/auth/app/sign/outs_controller.rb
    app/controllers/auth/app/sign/ups_controller.rb
    app/controllers/auth/com/sign/outs_controller.rb
    app/controllers/auth/org/sign/in/entra/authorizations_controller.rb
    app/controllers/auth/org/sign/outs_controller.rb
    app/controllers/concerns/common_redirect.rb
    app/controllers/concerns/oidc_callback.rb
    app/controllers/concerns/oidc_rp_logout_launcher.rb
    app/controllers/concerns/oidc_sso_initiator.rb
    app/controllers/concerns/sign_oidc_logout.rb
    app/controllers/core/app/sign/outs_controller.rb
    app/controllers/sign/app/sign/ins_controller.rb
    app/controllers/sign/app/sign/outs_controller.rb
  ).freeze

  RAW_PT_ALLOWLIST_PATTERNS = [
    %r{\Aapp/controllers/.*/verification/},
    %r{\Aapp/controllers/concerns/verification/},
    %r{\Aapp/controllers/concerns/sign/.*verification},
    %r{\Aapp/views/sign/.*/verification/},
    %r{\Aapp/views/sign/app/verifications/},
  ].freeze

  test "controllers do not redirect directly to params" do
    offenders =
      ruby_files.grep(%r{\Aapp/controllers/}).select do |path|
        File.read(path).match?(DIRECT_PARAM_REDIRECT)
      end

    assert_empty offenders
  end

  test "allow_other_host true is limited to jump facade" do
    offenders =
      ruby_files.select do |path|
        next false if ALLOW_OTHER_HOST_ALLOWLIST.include?(path)

        File.read(path).match?(DIRECT_ALLOW_OTHER_HOST)
      end

    assert_empty offenders
  end

  test "legacy xt redirect facade is not used" do
    offenders =
      ruby_files.select do |path|
        File.read(path).match?(LEGACY_XT_REDIRECT)
      end

    assert_empty offenders
  end

  test "sign in and sign up views do not propagate raw authentication pt" do
    offenders =
      Dir.glob("app/views/sign/**/*.{erb,haml,slim}").select do |path|
        next false if RAW_PT_ALLOWLIST_PATTERNS.any? { |pattern| path.match?(pattern) }

        File.read(path).match?(RAW_PT_PARAM)
      end

    assert_empty offenders
  end

  test "sign in and sign up controllers do not consume raw authentication pt directly" do
    offenders =
      Dir.glob("app/controllers/sign/**/*_controller.rb").select do |path|
        next false if RAW_PT_ALLOWLIST_PATTERNS.any? { |pattern| path.match?(pattern) }

        File.read(path).match?(RAW_PT_PARAM)
      end

    assert_empty offenders
  end

  private

  def ruby_files
    Dir.glob("{app,config,lib}/**/*.rb")
  end
end
