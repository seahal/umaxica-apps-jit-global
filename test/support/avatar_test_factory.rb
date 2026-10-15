# frozen_string_literal: true

# The Avatar moniker refactor removes Avatar's writable moniker attribute. Existing model and
# policy tests use this factory to exercise the production temporal writer without duplicating
# setup or reintroducing a test-only application path.
module AvatarTestFactory
  # Public ID of the `enterprises(:avatar_owner)` fixture.
  STANDARD_OWNER_PUBLIC_ID = "AvatarOwnerFixture001"
  STANDARD_MONIKER = "Moniker One"

  # Avatars, their monikers and their ownership periods have no fixture files on purpose. Ownership
  # periods are append-only (a trigger rejects DELETE), and Rails reloads every fixture table with
  # DELETE, which fails once a committed test has left an owned Avatar behind. Tests that need one
  # ordinary Avatar create it here inside their own transaction.
  def self.create_standard!(active_handle:)
    create!(
      moniker: STANDARD_MONIKER,
      concrete_owner_public_id: STANDARD_OWNER_PUBLIC_ID,
      active_handle: active_handle,
      capability_id: AvatarCapability::NORMAL,
      lifecycle_state: AvatarLifecycleState.find_by!(key: "active"),
    )
  end

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
