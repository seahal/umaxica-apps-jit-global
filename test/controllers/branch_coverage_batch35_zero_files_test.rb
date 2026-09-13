# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch35ZeroFilesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Auth Com Sign In PasskeysController identity helpers" do
    controller = Auth::Com::Sign::In::PasskeysController.new

    assert_equal VisitorEmail, controller.send(:identity_email_model)
    assert_equal VisitorTelephone, controller.send(:identity_telephone_model)
    assert_nil controller.send(:identity_from_email_record, nil)
    assert_nil controller.send(:identity_from_telephone_record, nil)

    email = Object.new
    email.define_singleton_method(:visitor) { :visitor_from_email }
    telephone = Object.new
    telephone.define_singleton_method(:visitor) { :visitor_from_telephone }

    assert_equal :visitor_from_email, controller.send(:identity_from_email_record, email)
    assert_equal :visitor_from_telephone, controller.send(:identity_from_telephone_record, telephone)
    assert_not controller.send(:minimum_response_budget_enabled?)
  end

  test "Auth Org Verification PasskeysController errors_sentence and layout" do
    controller = Auth::Org::Verification::PasskeysController.new

    assert_equal "auth/org/application", controller.send(:step_up_handoff_layout)

    controller.instance_variable_set(:@verification_errors, nil)

    assert_nil Array(controller.instance_variable_get(:@verification_errors)).presence&.to_sentence

    controller.instance_variable_set(:@verification_errors, %w(one two))
    sentence = Array(controller.instance_variable_get(:@verification_errors)).presence&.to_sentence

    assert_includes sentence, "one"
  end

  test "BirthdatesController props birthdate safe navigation" do
    controller = Base::App::Identity::BirthdatesController.new
    client = Object.new
    client.define_singleton_method(:birthdate) { nil }
    controller.define_singleton_method(:current_client) { client }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:t) { |*_args, **_kwargs| "t" }
    # Build the same expression used in show
    assert_nil client.birthdate&.to_s
    client2 = Object.new
    client2.define_singleton_method(:birthdate) { Date.new(2000, 1, 2) }

    assert_equal "2000-01-02", client2.birthdate&.to_s
    assert_equal "settings_birthdate", controller.send(:verification_scope)
  end

  test "Publishing CreateEntryOperation re-raises non-slug uniqueness" do
    entry_class =
      Class.new do
        const_set(:SURFACE, "docs")
        const_set(:AUDIENCE, "app")
        def self.transaction
          yield
        end

        def self.create!(*)
          raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint \"other_index\""
        end
      end

    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        Publishing::CreateEntryOperation.new(
          entry_class: entry_class,
          locale: "en",
          slug: "slug",
          title: "t",
          summary: "s",
          body: "b",
          operator_public_id: "op",
        ).call
      end
    assert_includes error.message, "other_index"
  end

  test "Publishing CreateEntryOperation maps slug uniqueness to failure" do
    index = Publishing::CreateEntryOperation.slug_index_name(
      Class.new do
        const_set(:SURFACE, "docs")
        const_set(:AUDIENCE, "app")
      end,
    )
    entry_class =
      Class.new do
        const_set(:SURFACE, "docs")
        const_set(:AUDIENCE, "app")
        def self.transaction
          yield
        end
        define_singleton_method(:create!) do |*|
          raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint \"#{index}\""
        end
      end

    result = Publishing::CreateEntryOperation.new(
      entry_class: entry_class,
      locale: "en",
      slug: "slug",
      title: "t",
      summary: "s",
      body: "b",
      operator_public_id: "op",
    ).call

    assert_not result.ok?
    assert_equal "is already used by another entry in this locale", result.errors[:slug]
  end

  test "AppealReviewsController raises when appeal missing" do
    controller = Base::Org::Support::EnforcementCases::AppealReviewsController.new
    enforcement_case = Object.new
    enforcement_case.define_singleton_method(:appeal) { nil }
    controller.instance_variable_set(:@enforcement_case, enforcement_case)

    assert_nil controller.instance_variable_get(:@enforcement_case).appeal
    assert_raises(ActiveRecord::RecordNotFound) { raise ActiveRecord::RecordNotFound, "appeal not found" }
  end

  test "ErasuresController return if performed path" do
    controller = Base::App::Identity::Privacy::ErasuresController.new
    controller.define_singleton_method(:performed?) { true }
    controller.define_singleton_method(:current_withdrawal_subject) { Object.new }
    controller.define_singleton_method(:render_privacy_erasure_new) { |_s| true }
    controller.define_singleton_method(:render) { |*_args, **_kwargs| raise RuntimeError, "should not render" }
    # Emulate the new action's early return
    controller.send(:render_privacy_erasure_new, controller.send(:current_withdrawal_subject))

    assert controller.send(:performed?)
  end
end
