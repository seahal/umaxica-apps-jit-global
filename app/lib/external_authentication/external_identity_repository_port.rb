# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  module ExternalIdentityRepositoryPort
    def find_by_subject(subject, lock:)
      raise NotImplementedError
    end

    def find_for_user(user)
      raise NotImplementedError
    end

    def find_by_subject_for_link(subject, lock:)
      raise NotImplementedError
    end

    def find_for_user_for_link(user)
      raise NotImplementedError
    end

    def build_for_user(user:, principal:, credential_candidate:)
      raise NotImplementedError
    end

    def refresh_credentials!(identity, principal:, credential_candidate:)
      raise NotImplementedError
    end

    def assign_to_user(identity, user)
      raise NotImplementedError
    end

    def activate!(identity)
      raise NotImplementedError
    end

    def destroy!(identity)
      raise NotImplementedError
    end

    def refresh_token_for(identity)
      raise NotImplementedError
    end
  end
end
