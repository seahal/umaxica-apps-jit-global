# typed: false
# frozen_string_literal: true

class AppleOnlyCredentialStatus
  def self.call(client)
    new(client).call
  end

  def initialize(client)
    @client = client
  end

  def call
    return false unless client

    AuthenticationCredentialInventory.call(client, reload: true).sign_in_methods == [:apple]
  end

  private

  attr_reader :client
end
