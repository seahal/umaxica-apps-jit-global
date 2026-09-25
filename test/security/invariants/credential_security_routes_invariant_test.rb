# typed: false
# frozen_string_literal: true

require "test_helper"

class CredentialSecurityRoutesInvariantTest < ActiveSupport::TestCase
  SECURITY_CONTROLLER_GLOBS = [
    "app/controllers/base/*/identity/**/*_controller.rb",
    "app/controllers/auth/*/verification/**/*_controller.rb",
  ].freeze

  test "production identity security controllers do not expose not implemented responses" do
    offenders =
      SECURITY_CONTROLLER_GLOBS.flat_map { |glob| Rails.root.glob(glob) }
        .select { |path| File.read(path).include?("head(:not_implemented)") }

    assert_empty offenders.map { |path| path.delete_prefix("#{Rails.root.join}") }
  end

  test "credential changing app controllers call the shared security transition" do
    required = {
      "app/controllers/base/app/identity/mfa/challenges_controller.rb" => "CredentialSecurityTransition.call",
      "app/controllers/base/app/identity/emails/registrations_controller.rb" => "CredentialSecurityTransition.call",
      "app/services/client_secret_credentials_destroy.rb" => "CredentialSecurityTransition.call",
    }

    missing =
      required.filter_map do |relative_path, expected|
        relative_path unless Rails.root.join(relative_path).read.include?(expected)
      end

    assert_empty missing
  end

  test "base app generic identity secret management route is absent" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL")}/identity/secrets",
        method: :get,
      )
    end
  end

  test "legacy permanent secret credentials expose no sign-in eligibility interface" do
    models = [
      [ClientSecretCredential, ClientSecretCredentialKind],
      [VisitorSecretCredential, VisitorSecretCredentialKind],
      [OperatorSecretCredential, OperatorSecretCredentialKind],
    ]

    models.each do |credential_class, kind_class|
      assert_not credential_class.respond_to?(:allowed_for_secret_credential_sign_in)
      assert_not credential_class.const_defined?(:SIGN_IN_ALLOWED_KIND_IDS, false)
      assert_not credential_class.const_defined?(:SIGN_IN_ALLOWED_STATUS_IDS, false)
      assert_not credential_class.new.respond_to?(:verify_for_secret_credential_sign_in!)
      assert_not credential_class.new.respond_to?(:usable_for_secret_credential_sign_in?)
      assert_not credential_class.new.respond_to?(:verify_and_consume!)
      assert_not credential_class.new.respond_to?(:permanent_secret_credential?)
      assert_not kind_class.const_defined?(:PERMANENT, false)
      assert_not kind_class.const_defined?(:ALLOWED_FOR_SECRET_SIGN_IN, false)
    end

    assert_equal 1, ClientSecretCredentialKind::LOGIN
    assert_equal 1, VisitorSecretCredentialKind::LOGIN
    assert_equal 2, OperatorSecretCredentialKind::LOGIN
  end

  test "app MFA challenge update route reaches credential transition controller action" do
    recognized = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL")}/identity/mfa/challenge",
      method: :patch,
    )

    assert_equal "base/app/identity/mfa/challenges", recognized[:controller]
    assert_equal "update", recognized[:action]
  end

  test "org identity telephones use required id parameter extraction" do
    source = Rails.root.join("app/controllers/base/org/identity/telephones_controller.rb").read

    assert_includes source, "params.expect(:id)"
    assert_not_includes source, "params(:id)"
  end
end
