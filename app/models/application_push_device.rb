# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: action_push_native_devices
# Database name: com_zenith
#
#  id         :bigint           not null, primary key
#  name       :string
#  owner_type :string
#  platform   :string           not null
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  owner_id   :bigint
#
# Indexes
#
#  index_action_push_native_devices_on_owner  (owner_type,owner_id)
#
require "action_push_native"
require File.join(
  Gem.loaded_specs.fetch("action_push_native").full_gem_path,
  "app/models/action_push_native/record.rb",
)
require File.join(
  Gem.loaded_specs.fetch("action_push_native").full_gem_path,
  "app/models/action_push_native/device.rb",
)

class ApplicationPushDevice < ActionPushNative::Device
  # Customize TokenError handling (default: destroy!)
  # rescue_from (ActionPushNative::TokenError) { Rails.logger.error("Device #{id} token is invalid") }

  validates :token, exclusion: { in: [nil] }
end
