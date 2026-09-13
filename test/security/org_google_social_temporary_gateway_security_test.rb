# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgComNoSocialCleanupSecurityTest < ActiveSupport::TestCase
  RUNTIME_PATTERNS = [
    /TEMP\((?:org|com)-google-social-gateway\): remove before production cleanup/,
    /\b(?:ORG|COM)_GOOGLE_[A-Z_]+\b/,
    /\bgoogle_(?:org|com)\b/,
    /\bOperator#{"Google"}Identity\b/,
    /\bVisitor#{"Google"}Identity\b/,
    /\bVisitorOauth#{"Callback"}State\b/,
  ].freeze

  TEST_AND_CONFIG_PATTERNS = [
    /TEMP\((?:org|com)-google-social-gateway\): remove before production cleanup/,
    /\b(?:ORG|COM)_GOOGLE_[A-Z_]+\b/,
    /\bgoogle_(?:org|com)\b/,
  ].freeze

  test "runtime has no org or com google social gateway code" do
    offenders = scan_paths(runtime_files, RUNTIME_PATTERNS)

    assert_empty offenders, "org/com Google social gateway runtime remains:\n#{offenders.join("\n")}"
  end

  test "config and docker do not preserve temporary gateway flags or providers" do
    offenders = scan_paths(config_files, TEST_AND_CONFIG_PATTERNS)

    assert_empty offenders, "org/com Google social gateway references remain:\n#{offenders.join("\n")}"
  end

  test "org sign in page exposes only local verifier entrypoints" do
    # The page is an Inertia component fed by the controller, so the entrypoints it can offer are
    # exactly the ones this controller puts in its props.
    source = read("app/controllers/auth/org/sign/ins_controller.rb")

    assert_match(/auth_org_social_entra_session_path/, source)
    assert_match(/new_auth_org_sign_in_emergency_passkey_path/, source)
    assert_no_match(/google|apple/i, source)
  end

  test "org routes expose local sign in and passkey verification only" do
    source = read("config/routes/auth.rb")
    org_block = surface_block(source, "# Staff credential gateway host")

    assert_match(/resource :passkey, only: :new/, org_block)
    assert_match(/resource :secret, only: %i\(new create\)/, org_block)
    assert_match(/resource :passkey, only: %i\(new create\)/, org_block)
    assert_no_match(/namespace :social|resource :totp|resources :totps/, org_block)
  end

  test "com pages do not expose social auth helpers" do
    # Both the controllers that build these pages\' props and the components that render them.
    source = [
      "app/controllers/auth/com/sign/ins_controller.rb",
      "app/controllers/auth/com/sign/ups_controller.rb",
      "src/pages/auth/com/sign_ins/new.tsx",
      "src/pages/auth/com/sign_ups/new.tsx",
    ].map { |path| read(path) }.join("\n")

    assert_no_match(/social_authentication|google|apple|microsoft/i, source)
  end

  test "com routes expose no social provider callback" do
    source = read("config/routes/auth.rb")
    com_block = surface_block(source, "# Corporate credential gateway host", "# Staff credential gateway host")

    assert_match(/resource :email, only: %i\(new create edit update\)/, com_block)
    assert_match(/resource :secret, only: %i\(new create\)/, com_block)
    assert_no_match(/namespace :social|google|apple|microsoft/i, com_block)
  end

  test "app routes and omniauth config keep app social providers" do
    routes = surface_block(
      read("config/routes/auth.rb"), "# User credential gateway host",
      "# Corporate credential gateway host",
    )
    omniauth = read("config/initializers/omniauth.rb")

    # The ceremony entry is POST only: a GET entry would let a link start an
    # authentication ceremony (login CSRF), so there is no `new` action.
    assert_match(/resource :session, only: :create, controller: :sessions/, routes)
    assert_no_match(/resource :session, only: %i\([^)]*new[^)]*\), controller: :sessions/, routes)
    assert_match(%r{omniauth/omniauth_callbacks#omniauth}, routes)
    assert_match(/apple/, routes)
    assert_match(/google/, omniauth)
    assert_match(/apple/, omniauth)
  end

  test "social identifiable maps only app provider scope" do
    source = read("app/models/concerns/social_identifiable.rb")

    assert_match(/google_app google_oauth2/, source)
    assert_match(/normalized/, source)
    assert_no_match(/google_(?:org|com)|microsoft/i, source)
  end

  private

  def runtime_files
    Rails.root.glob("{app,config/initializers}/**/*").select(&:file?).map { |path| relative(path) }
  end

  def config_files
    Rails.root.glob("{config,docker}/**/*").select(&:file?).map { |path| relative(path) }
  end

  def scan_paths(paths, patterns)
    paths.flat_map do |path|
      source = read(path)
      patterns.filter_map do |pattern|
        "#{path}: #{pattern.source}" if source.match?(pattern)
      end
    end
  end

  def read(path)
    Rails.root.join(path).binread.force_encoding(Encoding::UTF_8).scrub
  end

  def read_if_present(path)
    full_path = Rails.root.join(path)
    return nil unless full_path.file?

    full_path.read
  end

  def surface_block(source, start_marker, end_marker = nil)
    start_index = source.index(start_marker)

    assert start_index, "Could not find #{start_marker.inspect}"

    end_index = end_marker && source.index(end_marker, start_index + start_marker.length)
    source[start_index...(end_index || source.length)]
  end

  def relative(path)
    Pathname(path).relative_path_from(Rails.root).to_s
  end
end
