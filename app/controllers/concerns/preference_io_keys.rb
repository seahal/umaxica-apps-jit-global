# typed: false
# frozen_string_literal: true

module PreferenceIoKeys
  HOST_COOKIE_PREFIX = "__Host-"
  SECURE_COOKIE_PREFIX = HOST_COOKIE_PREFIX

  module Cookies
    LANGUAGE = "language"
    public_constant :LANGUAGE
  end

  module Params
    CT = :ct
    LX = :lx
    RI = :ri
    TZ = :tz
    OPTION_ID = :option_id

    public_constant :CT
    public_constant :LX
    public_constant :RI
    public_constant :TZ
    public_constant :OPTION_ID
  end

  public_constant :HOST_COOKIE_PREFIX
  public_constant :SECURE_COOKIE_PREFIX
end
