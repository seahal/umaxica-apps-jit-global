# typed: false
# frozen_string_literal: true

require "test_helper"

# Two seams in AuthenticationRedirects resolve where a signed-in person is sent
# next. Both fall back rather than raise, so a wrong answer is a silent
# cross-surface redirect: the checkpoint path picks whichever surface's route
# helper the including controller happens to carry, and the navigation target
# resolves a caller-supplied key that has to be refused when it names nothing.
class AuthenticationCheckpointAndTargetTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class BaseHarness
    include ::CommonRedirect
    include ::AuthenticationRedirects

    attr_accessor :params, :session

    def initialize
      @params = ActionController::Parameters.new(ri: "jp")
      @session = {}
    end

    def invoke(name, ...) = send(name, ...)

    def current_region_identifier = "jp"

    def signed_pt_token(pt) = pt

    def path_from_signed_pt(value) = value

    def path_target_value = "/settings"

    def redirect_target_surface = "app"

    attr_reader :rendered

    def render(**options)
      @rendered = options
    end

    def authentication_pt_flow = "sign_in"

    def authentication_pt_surface = "app"
  end

  class OrgHarness < BaseHarness
    def auth_org_sign_in_check_path(**attrs) = "/org/sign/in/check?#{attrs.to_query}"
  end

  test "the checkpoint path follows whichever surface's route helper the controller carries" do
    assert_equal "/sign/in/check", BaseHarness.new.invoke(:sign_in_checkpoint_path)
    assert_includes OrgHarness.new.invoke(:sign_in_checkpoint_path), "/org/sign/in/check"
  end

  test "the checkpoint path carries the region and a present path target" do
    path = OrgHarness.new.invoke(:sign_in_checkpoint_path, pt: "/settings/sessions")

    assert_includes path, "ri=jp"
    assert_includes path, CGI.escape("/settings/sessions")
  end

  test "a navigation target that names nothing resolves to no destination at all" do
    harness = BaseHarness.new
    harness.params = ActionController::Parameters.new("ri" => "jp", AuthIoKeys::Params::NT => "not-a-target")

    assert_nil harness.invoke(:resolved_path_or_navigation_target)
  end

  test "a navigation target inside the scope resolves to its own path" do
    harness = BaseHarness.new
    harness.params = ActionController::Parameters.new("ri" => "jp", AuthIoKeys::Params::NT => "home")

    assert_equal "/?ri=jp", harness.invoke(:resolved_path_or_navigation_target)
  end

  test "no navigation target falls back to the signed path target" do
    assert_equal "/settings", BaseHarness.new.invoke(:resolved_path_or_navigation_target)
  end

  test "an unparsable candidate is not mistaken for the welcome page" do
    assert_not BaseHarness.new.invoke(:welcome_return_path?, "http://[oops")
  end

  test "an unusable return target is refused with a 422 rather than a redirect" do
    harness = BaseHarness.new

    harness.invoke(:render_invalid_return_target!)

    assert_equal I18n.t("errors.messages.invalid_request"), harness.rendered.fetch(:plain)
    assert_equal :unprocessable_content, harness.rendered.fetch(:status)
  end

  test "a path target with no common claims is refused rather than signed" do
    harness = BaseHarness.new
    harness.define_singleton_method(:signed_target_claims) { |**| {} }

    assert_nil harness.invoke(:issue_authentication_path_target_token, "/settings/sessions")
  end

  test "a path target that is not an internal path is refused rather than signed" do
    assert_nil BaseHarness.new.invoke(:issue_authentication_path_target_token, "https://evil.example.com/")
  end

  test "the return target nonce is the same value under both names" do
    harness = BaseHarness.new
    nonce = harness.invoke(:authentication_pt_session_nonce)

    assert_predicate nonce, :present?
    assert_equal nonce, harness.invoke(:authentication_return_target_nonce)
  end
end
