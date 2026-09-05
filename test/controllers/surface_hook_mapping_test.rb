# typed: false
# frozen_string_literal: true

require "test_helper"

# Every surface answers the same set of seams with its own models, columns and
# copy keys. A wrong answer here is a cross-surface leak -- a com request reading
# a client record, say -- so the mapping is asserted per surface rather than left
# to whichever ceremony happens to walk through it.
class SurfaceHookMappingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # The seams are pure; allocate skips the controller's request lifecycle so they
  # can be read without standing a request up.
  def self.bare(controller_class)
    controller_class.allocate
  end

  # A request double carrying only what the preference hooks read off it.
  def preference_request(host:)
    Struct.new(:host, :ssl?, :path, :query_parameters, :format) do
      def get? = true

      def head? = false
    end.new(host, false, "/preference", {}, Struct.new(:html?).new(true))
  end

  # Swaps the ancestor `super` resolves to for a recorder, so an override can be run for real and
  # still be asked whether it delegated, without standing up the request lifecycle the ancestor
  # needs. Restored on the way out so no other test sees the replacement.
  def record_super(owner, name)
    reached = []
    original = owner.instance_method(name)
    owner.send(:define_method, name) { reached << :super_reached }
    yield
    reached
  ensure
    owner.send(:define_method, name, original)
  end

  test "the com verification base controller answers every seam with visitor models" do
    c = self.class.bare(Auth::Com::Verification::BaseController)

    assert_equal VisitorVerification, c.send(:verification_model)
    assert_equal :visitor_token_id, c.send(:verification_token_foreign_key)
    assert_equal VisitorPasskey, c.send(:verification_passkey_model)
    assert_equal ClientChronicleEvent::STEP_UP_VERIFIED, c.send(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", c.send(:verification_success_notice_key)
    assert_equal "sign.app.verification.errors.no_passkey", c.send(:verification_no_passkey_i18n_key)
    assert_equal %i(email_otp passkey), c.send(:step_up_supported_methods)
  end

  test "the com verification base controller scopes passkeys to the signed-in visitor" do
    c = self.class.bare(Auth::Com::Verification::BaseController)
    visitor = Visitor.new
    visitor.id = 77
    c.define_singleton_method(:current_visitor) { visitor }

    assert c.send(:passkey_actor_matches?, Struct.new(:visitor_id).new(77))
    assert_not c.send(:passkey_actor_matches?, Struct.new(:visitor_id).new(78))
    assert_equal visitor.visitor_passkeys.to_sql, c.send(:verification_passkeys_scope).to_sql
  end

  test "the com verification base controller clears only its own step-up state" do
    c = self.class.bare(Auth::Com::Verification::BaseController)
    session = { email_otp: "state", other: "kept" }
    c.define_singleton_method(:session) { session }
    c.define_singleton_method(:email_otp_session_key) { :email_otp }
    c.define_singleton_method(:step_up_session_storage_available?) { true }

    c.send(:clear_step_up_state!)

    assert_equal({ other: "kept" }, session)
  end

  test "the com verification base controller rejects a step-up session bound elsewhere" do
    c = self.class.bare(Auth::Com::Verification::BaseController)
    c.define_singleton_method(:actor_token) { Struct.new(:id).new(5) }
    live = Struct.new(:discarded_at, :visitor_token_id, :status, :scope, :return_to)

    assert c.send(:valid_step_up_session?, live.new(1.hour.from_now, 5, "PENDING", "settings_email", "/back"))
    assert_not c.send(:valid_step_up_session?, live.new(1.hour.from_now, 6, "PENDING", "settings_email", "/back"))
    assert_not c.send(:valid_step_up_session?, live.new(1.hour.ago, 5, "PENDING", "settings_email", "/back"))
    assert_not c.send(:valid_step_up_session?, nil)
  end

  test "the com application controller answers its identity seams with visitor models" do
    c = self.class.bare(Auth::Com::ApplicationController)

    assert_not c.send(:actor_staff?)
    assert_equal VisitorVerification, c.send(:verification_model)
    assert_equal :visitor_token_id, c.send(:verification_token_foreign_key)
    assert_equal VisitorEmail, c.send(:identity_email_model)
    assert_equal VisitorTelephone, c.send(:identity_telephone_model)
    assert_nil c.send(:identity_from_email_record, nil)
    assert_nil c.send(:identity_from_telephone_record, nil)
    assert_equal :the_visitor, c.send(:identity_from_email_record, Struct.new(:visitor).new(:the_visitor))
    assert_equal :the_visitor, c.send(:identity_from_telephone_record, Struct.new(:visitor).new(:the_visitor))
  end

  test "the app verification base controller answers every seam with client models" do
    c = self.class.bare(Auth::App::Verification::BaseController)
    client = Client.new
    client.id = 91
    c.define_singleton_method(:current_client) { client }
    c.define_singleton_method(:params) { { ri: "jp" }.with_indifferent_access }

    assert_equal ClientVerification, c.send(:verification_model)
    assert_equal ClientPasskey, c.send(:verification_passkey_model)
    assert_equal "sign.app.verification.success.complete", c.send(:verification_success_notice_key)
    assert_equal "sign.app.verification.errors.no_passkey", c.send(:verification_no_passkey_i18n_key)
    assert c.send(:passkey_actor_matches?, Struct.new(:user_id).new(91))
    assert_not c.send(:passkey_actor_matches?, Struct.new(:user_id).new(92))
  end

  test "the org and app application controllers answer their identity seams per surface" do
    org = self.class.bare(Auth::Org::ApplicationController)
    app = self.class.bare(Auth::App::ApplicationController)

    assert_equal OperatorVerification, org.send(:verification_model)
    assert_equal ClientVerification, app.send(:verification_model)
    assert_equal :staff_token_id, org.send(:verification_token_foreign_key)
    assert_equal :user_token_id, app.send(:verification_token_foreign_key)
  end

  test "the preference controllers skip the cookie on localhost and only refresh on an edit entry" do
    [Auth::App::PreferencesBaseController,
     Auth::Com::PreferencesBaseController,
     Auth::Org::PreferencesBaseController,].each do |controller_class|
      c = self.class.bare(controller_class)
      req = preference_request(host: "auth.app.localhost")
      c.define_singleton_method(:request) { req }
      c.define_singleton_method(:action_name) { "edit" }

      assert_predicate c, :preference_edit_entry_request?

      redirected = []
      c.define_singleton_method(:redirect_to_acme_authority!) { |path, **| redirected << path }
      c.send(:redirect_localhost_preference_authority!)

      assert_equal ["/preference"], redirected, controller_class.name
    end
  end

  # The cookie override exists to keep the preference cookie off `.localhost`, where the surface
  # hosts are not the cookie's domain. Both arms are driven through the real method: the previous
  # version of this test replaced `set_preferences_cookie` with a singleton before calling it, so
  # the override's own body never ran and the skip it exists to perform was never asserted.
  test "the preference controllers hand the cookie to the transport unless the host is localhost" do
    [Auth::App::PreferencesBaseController,
     Auth::Com::PreferencesBaseController,
     Auth::Org::PreferencesBaseController,].each do |controller_class|
      { "auth.app.localhost" => [], "auth.umaxica.app" => [:super_reached] }.each do |host, expected|
        c = self.class.bare(controller_class)
        req = preference_request(host: host)
        c.define_singleton_method(:request) { req }

        reached = record_super(PreferenceTransport, :set_preferences_cookie) { c.send(:set_preferences_cookie) }

        assert_equal expected, reached, "#{controller_class.name} on #{host}"
      end
    end
  end

  # The actor override refreshes the preference token from the database before the actor is
  # hydrated, but only on the GET that opens an edit form -- doing it on every request would put a
  # write on the read path.
  test "the preference controllers refresh the preference token only when entering an edit form" do
    [Auth::App::PreferencesBaseController,
     Auth::Com::PreferencesBaseController,
     Auth::Org::PreferencesBaseController,].each do |controller_class|
      { "edit" => 1, "show" => 0 }.each do |action, expected_refreshes|
        c = self.class.bare(controller_class)
        req = preference_request(host: "auth.umaxica.app")
        c.define_singleton_method(:request) { req }
        c.define_singleton_method(:action_name) { action }
        refreshes = 0
        c.define_singleton_method(:refresh_preference_token_from_db_for_edit_entry!) { refreshes += 1 }

        reached = record_super(ActorSupport, :set_current_actor) { c.send(:set_current_actor) }

        assert_equal expected_refreshes, refreshes, "#{controller_class.name} on #{action}"
        assert_equal [:super_reached], reached, "#{controller_class.name} must always hydrate the actor"
      end
    end
  end
end
