# typed: false
# frozen_string_literal: true

class Actor
  # Immutable value object representing the resolved preference state for the current request.
  #
  # Controller boundary code installs this value after preference resolution.
  # Normal code may read the immutable value through the current-context API, but
  # must not mutate or rebuild it outside the resolver/installer path.
  #
  # Examples:
  #   Actor.preferences.language   # => "ja"
  #   Actor.preferences.timezone   # => "Asia/Tokyo"
  #   Actor.preferences.theme      # => "sy"
  #   Actor.preferences.cookie.consented?  # => false
  #   Actor.preferences.null?      # => true only when no request context is bound
  class Preference
    attr_reader :language, :region, :timezone, :theme,
                :currency, :date_format, :time_format, :motion, :density, :page_size

    # Field names (strings) the user set on purpose. Drives localization: an
    # explicitly set field's saved value wins over dynamic region seeding (?ri),
    # while an unset field stays eligible for seeding. See PreferenceExplicitFields.
    attr_reader :explicit_fields

    Cookie =
      Data.define(:consented, :functional, :performant, :targetable, :consent_version, :consented_at) do
        def consented? = !!consented

        def functional? = !!functional

        def performant? = !!performant

        def targetable? = !!targetable
      end

    DEFAULTS = {
      language: "ja",
      region: "jp",
      timezone: "Asia/Tokyo",
      theme: "sy",
      currency: "jpy",
      date_format: "iso",
      time_format: "24",
      motion: "standard",
      density: "standard",
      page_size: "infinity",
    }.freeze

    SCHEMA_VERSION = 1

    NULL_COOKIE = Cookie.new(
      consented: false,
      functional: false,
      performant: false,
      targetable: false,
      consent_version: nil,
      consented_at: nil,
    ).freeze

    def initialize(language: DEFAULTS[:language], region: DEFAULTS[:region],
                   timezone: DEFAULTS[:timezone], theme: DEFAULTS[:theme],
                   currency: DEFAULTS[:currency], date_format: DEFAULTS[:date_format],
                   time_format: DEFAULTS[:time_format], motion: DEFAULTS[:motion],
                   density: DEFAULTS[:density], page_size: DEFAULTS[:page_size],
                   cookie: NULL_COOKIE, null: false, explicit_fields: [])
      @explicit_fields = Array(explicit_fields).map(&:to_s).freeze
      @language = language.freeze
      @region = region.freeze
      @timezone = timezone.freeze
      @theme = theme.freeze
      @currency = currency.freeze
      @date_format = date_format.freeze
      @time_format = time_format.freeze
      @motion = motion.freeze
      @density = density.freeze
      @page_size = page_size.freeze
      @cookie = cookie
      @null = null
      freeze
    end

    def cookie
      @cookie
    end

    def null?
      @null
    end

    # True when the user explicitly chose this field (vs an auto-seeded default).
    def explicit?(field)
      @explicit_fields.include?(field.to_s)
    end

    def language_explicit?
      explicit?(:language)
    end

    def ==(other)
      other.is_a?(self.class) &&
        language == other.language &&
        region == other.region &&
        timezone == other.timezone &&
        theme == other.theme &&
        currency == other.currency &&
        date_format == other.date_format &&
        time_format == other.time_format &&
        motion == other.motion &&
        density == other.density &&
        page_size == other.page_size &&
        cookie == other.cookie &&
        null? == other.null? &&
        explicit_fields == other.explicit_fields
    end

    alias eql? ==

    def hash
      [
        self.class, language, region, timezone, theme, currency, date_format, time_format,
        motion, density, page_size, cookie, null?, explicit_fields,
      ].hash
    end

    def locale
      case @language
      when "ja" then :ja
      when "en" then :en
      else :"#{@language}"
      end
    end

    def time_zone
      ActiveSupport::TimeZone[@timezone] || ActiveSupport::TimeZone["Asia/Tokyo"]
    end

    def dark_mode?
      @theme == "dr"
    end

    def light_mode?
      @theme == "li"
    end

    def system_theme?
      @theme == "sy"
    end

    def to_h
      {
        language: @language,
        region: @region,
        timezone: @timezone,
        theme: @theme,
        currency: @currency,
        date_format: @date_format,
        time_format: @time_format,
        motion: @motion,
        density: @density,
        page_size: @page_size,
        consented: @cookie.consented?,
      }
    end

    def with_cookie(cookie)
      self.class.new(
        language: @language,
        region: @region,
        timezone: @timezone,
        theme: @theme,
        currency: @currency,
        date_format: @date_format,
        time_format: @time_format,
        motion: @motion,
        density: @density,
        page_size: @page_size,
        cookie: self.class.cookie_from(cookie),
        null: @null,
        explicit_fields: @explicit_fields,
      )
    end

    # Null Object -- returned when no preference is loaded (guests, bearer tokens).
    # All values are safe defaults; no DB access occurs.
    NULL = new(null: true).freeze

    # Build Preference from JWT prf claim hash
    # @param prf_claim [Hash] the prf claim from JWT payload with lx, ri, tz, ct and extended keys
    # @param cookie [Cookie] optional cookie consent data
    # @return [Preference] the constructed preference, or NULL if claim is invalid
    def self.from_jwt(prf_claim, cookie: NULL_COOKIE)
      return NULL unless prf_claim.is_a?(Hash)

      new(
        language: prf_claim["lx"] || DEFAULTS[:language],
        region: prf_claim["ri"] || DEFAULTS[:region],
        timezone: prf_claim["tz"] || DEFAULTS[:timezone],
        theme: prf_claim["ct"] || DEFAULTS[:theme],
        currency: hash_value(prf_claim, "cu", :cu, "currency", :currency) || DEFAULTS[:currency],
        date_format: hash_value(prf_claim, "df", :df, "date_format", :date_format) || DEFAULTS[:date_format],
        time_format: hash_value(prf_claim, "tf", :tf, "time_format", :time_format) || DEFAULTS[:time_format],
        motion: hash_value(prf_claim, "mo", :mo, "motion", :motion) || DEFAULTS[:motion],
        density: hash_value(prf_claim, "dn", :dn, "density", :density) || DEFAULTS[:density],
        page_size: hash_value(prf_claim, "ps", :ps, "page_size", :page_size) ||
          DEFAULTS[:page_size],
        cookie: cookie,
        explicit_fields: hash_value(prf_claim, "explicit", :explicit) || [],
      )
    end

    def self.hash_value(hash, *keys)
      key = keys.find { |candidate| hash.key?(candidate) }
      hash[key] if key
    end

    private_class_method :hash_value

    def self.cookie_from(value)
      case value
      when Cookie
        value
      when Hash
        build_cookie_from_hash(value)
      else
        build_cookie_from_object(value)
      end
    end

    def self.build_cookie_from_hash(value)
      Cookie.new(
        consented: value.key?(:consented) ? value[:consented] : value["consented"],
        functional: value.key?(:functional) ? value[:functional] : value["functional"],
        performant: value.key?(:performant) ? value[:performant] : value["performant"],
        targetable: value.key?(:targetable) ? value[:targetable] : value["targetable"],
        consent_version: value.key?(:consent_version) ? value[:consent_version] : value["consent_version"],
        consented_at: value.key?(:consented_at) ? value[:consented_at] : value["consented_at"],
      )
    end

    private_class_method :build_cookie_from_hash

    def self.build_cookie_from_object(value)
      return NULL_COOKIE if value.blank?

      Cookie.new(
        consented: value.try(:consented),
        functional: value.try(:functional),
        performant: value.try(:performant),
        targetable: value.try(:targetable),
        consent_version: value.try(:consent_version),
        consented_at: value.try(:consented_at),
      )
    end

    private_class_method :build_cookie_from_object
  end
end
