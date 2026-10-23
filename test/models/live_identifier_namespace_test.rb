# frozen_string_literal: true

require "test_helper"

# Fact comparisons keep normalized PII and lookup digests out of assertion diagnostics.
class LiveIdentifierNamespaceTest < ActiveSupport::TestCase
  %w(app com org).each do |realm|
    %w(email telephone).each do |channel|
      %i(active retained).each do |lifetime|
        %i(model database).each do |boundary|
          test "#{realm} #{channel} #{lifetime} Source occupies normalized namespace at #{boundary} boundary" do
            model, owner, owner_key, input_key, digest_column, error_attribute =
              case [realm, channel]
              when ["app", "email"]
                [ClientEmail, clients(:one), :user_id, :raw_address, :address_digest, :address]
              when ["app", "telephone"]
                [ClientTelephone, clients(:one), :user_id, :raw_number, :number_digest, :number]
              when ["com", "email"]
                [VisitorEmail, visitors(:reserved_visitor), :visitor_id, :raw_address, :address_digest, :address]
              when ["com", "telephone"]
                [VisitorTelephone, visitors(:reserved_visitor), :visitor_id, :raw_number, :number_digest, :number]
              when ["org", "email"]
                [OperatorEmail, operators(:one), :staff_id, :raw_address, :address_digest, :address]
              when ["org", "telephone"]
                [OperatorTelephone, operators(:one), :staff_id, :raw_number, :number_digest, :number]
              else
                raise ArgumentError, "unsupported test identifier domain"
              end
            identifier =
              (channel == "email") ? "namespace-#{SecureRandom.hex(8)}@example.test" :
                "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
            equivalent =
              (channel == "email") ? " #{identifier.upcase} " :
                "0#{identifier.delete_prefix("+81")[0, 2]}-#{identifier[-8, 4]}-#{identifier[-4, 4]}"
            attributes = { owner_key => owner.id, :confirm_policy => true }
            attributes[:confirm_using_mfa] = true if channel == "telephone"
            original = model.create!(**attributes, input_key => identifier)
            original.finalize_binding! unless realm == "org"
            if lifetime == :retained
              if realm == "org"
                now = owner.class.database_now
                owner.update!(discard_at: now, purge_eligible_at: now + 1.day)
              else
                original.discard_now!(purge_after: 1.day)
              end
            end
            original_facts = original.reload.attributes
            digest =
              case channel
              when "email" then IdentifierBlindIndex.bidx_for_email(equivalent, realm:)
              when "telephone" then IdentifierBlindIndex.bidx_for_telephone(equivalent, realm:)
              end

            assert_not_nil digest
            assert_withheld("Equivalent formatting must select the same realm digest") {
              original[digest_column] == digest
            }
            assert model.unscoped.exists?(original.id), "Live and retained bindings remain physical Source"
            if lifetime == :retained
              retained = (realm == "org") ? owner : original

              assert_not retained.accessible?(model.database_now)
              assert_not retained.purgeable?(model.database_now)
            end
            competing_owner =
              case realm
              when "app" then Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
              when "com" then Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
              when "org" then Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
              end
            competing_attributes = attributes.merge(owner_key => competing_owner.id)
            if boundary == :model
              if realm == "org"
                error =
                  assert_raises(ActiveRecord::RecordInvalid) do
                    model.create!(**competing_attributes, input_key => equivalent)
                  end

                assert error.record.errors.of_kind?(error_attribute, :taken),
                       "Duplicate must be rejected for namespace occupancy, not another validation"
              else
                assert_raises(ActiveRecord::RecordNotUnique) do
                  model.transaction(requires_new: true) do
                    candidate = model.create!(**competing_attributes, input_key => equivalent)
                    candidate.finalize_binding!
                  end
                end
              end
            else
              duplicate = model.new(
                **competing_attributes, input_key => equivalent, digest_column => digest,
              )
              duplicate.binding_finalized_at = model.database_now unless realm == "org"
              # Bypass model validation only to prove the actual DB uniqueness constraint independently.
              # The explicit realm HMAC is authoritative even though normalization callbacks still run.
              assert_raises(ActiveRecord::RecordNotUnique) do
                model.transaction(requires_new: true) { duplicate.save!(validate: false) }
              end
            end

            assert_withheld("Duplicate refusal must preserve the occupying Source") {
              original_facts == original.reload.attributes
            }
            assert_equal 1, model.unscoped.where(digest_column => digest).count,
                         "An unreleased binding occupies the realm namespace across owners throughout retention"
          end
        end
      end
    end
  end

  %w(email telephone).each do |channel|
    test "equivalent #{channel} identifiers occupy independent APP COM and ORG namespaces" do
      identifier =
        (channel == "email") ? "independent-namespace-#{SecureRandom.hex(8)}@example.test" :
          "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
      equivalent =
        (channel == "email") ? " #{identifier.upcase} " :
          "0#{identifier.delete_prefix("+81")[0, 2]}-#{identifier[-8, 4]}-#{identifier[-4, 4]}"
      records = []
      %w(app com org).each do |realm|
        model, owner, owner_key, input_key, digest_column =
          case [realm, channel]
          when ["app", "email"] then [ClientEmail, clients(:one), :user_id, :raw_address, :address_digest]
          when ["app", "telephone"] then [ClientTelephone, clients(:one), :user_id, :raw_number, :number_digest]
          when ["com",
                "email",] then [VisitorEmail, visitors(:reserved_visitor), :visitor_id, :raw_address, :address_digest]
          when ["com", "telephone"]
            [VisitorTelephone, visitors(:reserved_visitor), :visitor_id, :raw_number, :number_digest]
          when ["org", "email"] then [OperatorEmail, operators(:one), :staff_id, :raw_address, :address_digest]
          when ["org", "telephone"] then [OperatorTelephone, operators(:one), :staff_id, :raw_number, :number_digest]
          else raise ArgumentError, "unsupported test identifier domain"
          end
        attributes = { owner_key => owner.id, :confirm_policy => true, input_key => equivalent }
        attributes[:confirm_using_mfa] = true if channel == "telephone"
        record = model.create!(**attributes)
        expected =
          case channel
          when "email" then IdentifierBlindIndex.bidx_for_email(identifier, realm:)
          when "telephone" then IdentifierBlindIndex.bidx_for_telephone(identifier, realm:)
          end

        assert_predicate record, :persisted?
        assert_withheld("Each realm must use its own normalized identifier HMAC") { record[digest_column] == expected }
        records << [record, digest_column]
      end

      assert_equal 3, records.size
      digests = records.map { |record, column| record.reload[column] }

      assert_equal 3, digests.uniq.size, "Independent realm keys must not create a global identifier namespace"
    end
  end
end
