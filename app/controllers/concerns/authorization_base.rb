# typed: false
# frozen_string_literal: true

# Authorization for this app is handled entirely by Action Policy (see
# ApplicationPolicy and app/policies). This concern is retained only as the
# shared base that Authorization::{AuthorizationClient,AuthorizationOperator} include; it holds no
# request hook so it can never act as an implicit allow.
module AuthorizationBase
  extend ActiveSupport::Concern
end
