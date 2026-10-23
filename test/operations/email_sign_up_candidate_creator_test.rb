# frozen_string_literal: true

require "test_helper"

class EmailSignUpCandidateCreatorTest < ActiveSupport::TestCase
  [[Client, ClientEmail, :user, :user_id], [Visitor, VisitorEmail, :visitor, :visitor_id]].each do |
    owner_model, email_model, association, owner_key|
    test "#{email_model.name} signup refuses persisted candidates and preserves their original owner" do
      owner = owner_model.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_model))
      email = email_model.create!(
        association => owner, :raw_address => "persisted-signup-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true,
      )

      assert_no_difference [-> { owner_model.count }, -> { email_model.count }] do
        assert_raises(ArgumentError) { EmailSignUpCandidateCreator.call(email: email) }
      end
      assert_equal owner.id, email.reload[owner_key]
    end

    test "#{email_model.name} signup refuses new candidates already attached to persisted or unsaved owners" do
      [owner_model.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_model)),
       owner_model.new(security_mode_id: SecurityModeTestDefault.id_for(owner_model)),].each do |owner|
        email = email_model.new(
          association => owner, :raw_address => "preowned-signup-#{SecureRandom.hex(8)}@example.test",
          :confirm_policy => true,
        )

        assert_no_difference [-> { owner_model.count }, -> { email_model.count }] do
          assert_raises(ArgumentError) { EmailSignUpCandidateCreator.call(email: email) }
        end
        assert_predicate email, :new_record?
        assert_same owner, (email_model == ClientEmail) ? email.user : email.visitor
      end
    end
  end
end
