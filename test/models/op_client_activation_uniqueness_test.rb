# frozen_string_literal: true

require "test_helper"

class OpClientActivationUniquenessTest < ActiveSupport::TestCase
  REALMS = [
    [OpAppClientActivation, "core-app-jp", "warp-app-jp"],
    [OpComClientActivation, "core-com-jp", "warp-com-jp"],
    [OpOrgClientActivation, "core-org-jp", "warp-org-jp"],
  ].freeze

  REALMS.each do |activation_class, client_id, other_client_id|
    test "#{activation_class.name} keeps client and epoch partitions with DB uniqueness" do
      attributes = { client_id: client_id,
                     contract_epoch: 1,
                     enabled: true,
                     changed_at: Time.current,
                     actor_ref: "operator",
                     audit_ref: "audit",
                     source_manifest_digest: "a" * 64, }
      first = activation_class.create!(attributes)

      assert_predicate activation_class.create!(attributes.merge(client_id: other_client_id)), :persisted?
      assert_predicate activation_class.create!(attributes.merge(contract_epoch: 2)), :persisted?
      first.update!(enabled: false)

      assert_same false, first.reload.enabled
      assert_raises(ActiveRecord::RecordNotUnique) do
        activation_class.transaction(requires_new: true) { activation_class.new(attributes).save!(validate: false) }
      end
    end

    test "#{activation_class.name} preflights one activation per client and epoch" do
      attributes = { client_id: client_id,
                     contract_epoch: 1,
                     enabled: true,
                     changed_at: Time.current,
                     actor_ref: "operator",
                     audit_ref: "audit",
                     source_manifest_digest: "a" * 64, }
      activation_class.create!(attributes)
      duplicate = activation_class.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:client_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    end
  end
end
