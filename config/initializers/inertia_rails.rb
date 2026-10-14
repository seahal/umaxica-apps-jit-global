# typed: false
# frozen_string_literal: true

# Every other option stays at the inertia_rails default. See adr/inertia-rails-thin-adapter.md.
InertiaRails.configure do |config|
  # One value per deployment: it is derived from the Vite sources, never from the request host.
  config.version = ViteRuby.digest
  config.encrypt_history = true
  config.always_include_errors_hash = true
  config.use_data_inertia_head_attribute = true
  config.use_script_element_for_initial_page = true
end
