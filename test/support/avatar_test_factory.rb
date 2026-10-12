# frozen_string_literal: true

# The Avatar moniker refactor removes Avatar's writable moniker attribute. Existing model and
# policy tests use this factory to exercise the production temporal writer without duplicating
# setup or reintroducing a test-only application path.
module AvatarTestFactory
  def self.create!(moniker:, create_concrete_owner: true, concrete_owner_public_id: nil, **attributes)
    Avatar.transaction do
      avatar = Avatar.create!(**attributes)
      if create_concrete_owner
        AvatarEnterpriseOwnershipPeriod.create!(
          avatar: avatar,
          enterprise_public_id: concrete_owner_public_id || "test-owner-#{SecureRandom.alphanumeric(12)}",
          valid_from: avatar.created_at,
        )
      end
      result = AvatarMonikerWriterOperation.call(
        avatar: avatar,
        moniker: moniker,
        expected_current: :absent,
      )
      raise ActiveRecord::RecordInvalid.new(result.avatar_moniker) unless result.success?

      avatar.reload
    end
  end
end
