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
  #   Actor.preferences.null?      # => true only when no request context is bound
  class Preference
    attr_reader :language, :region, :timezone, :theme,
                :currency, :date_format, :time_format, :motion, :density, :page_size, :web_push

    # The resolved Actor preference does not hydrate browser consent from Preference storage.
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
                   cookie: NULL_COOKIE, web_push: "disabled", null: false)
      raise ArgumentError, "invalid web push state" unless %w(enabled disabled).include?(web_push)

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
      @web_push = web_push.freeze
      @null = null
      freeze
    end

    def cookie
      @cookie
    end

    def null?
      @null
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
        web_push == other.web_push &&
        cookie == other.cookie &&
        null? == other.null?
    end

    alias eql? ==

    def hash
      [
        self.class, language, region, timezone, theme, currency, date_format, time_format,
        motion, density, page_size, web_push, cookie, null?,
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
      with_browser_state(cookie: cookie, web_push: @web_push)
    end

    public

    def with_browser_state(cookie:, web_push:, region: @region)
      self.class.new(
        language: @language,
        region: region,
        timezone: @timezone,
        theme: @theme,
        currency: @currency,
        date_format: @date_format,
        time_format: @time_format,
        motion: @motion,
        density: @density,
        page_size: @page_size,
        cookie: self.class.cookie_from(cookie),
        web_push: web_push,
        null: @null,
      )
    end

    # Null Object -- returned when no preference is loaded (guests, bearer tokens).
    # All values are safe defaults; no DB access occurs.
    NULL = new(null: true).freeze

    # Build the request-local runtime value from a verified realm snapshot or its URL overlay.
    # The compact keys are generated internally from the verified snapshot; old token shapes are
    # rejected before this value object receives them.
    # @param cookie [Cookie] optional cookie consent data
    # @return [Preference] the constructed preference, or NULL if claim is invalid
    def self.from_jwt(preference_snapshot, cookie: NULL_COOKIE)
      return NULL unless preference_snapshot.is_a?(Hash)

      theme = hash_value(preference_snapshot, "theme", :theme, "ct", :ct) || DEFAULTS[:theme]
      new(
        language: hash_value(preference_snapshot, "language", :language, "lx", :lx) || DEFAULTS[:language],
        region: hash_value(preference_snapshot, "region", :region, "ri", :ri) || DEFAULTS[:region],
        timezone: hash_value(preference_snapshot, "timezone", :timezone, "tz", :tz) || DEFAULTS[:timezone],
        theme: theme_from_snapshot(theme),
        currency: hash_value(preference_snapshot, "currency", :currency, "cu", :cu) || DEFAULTS[:currency],
        date_format: hash_value(preference_snapshot, "date_format", :date_format, "df", :df) ||
          DEFAULTS[:date_format],
        time_format: hash_value(preference_snapshot, "time_format", :time_format, "tf", :tf) ||
          DEFAULTS[:time_format],
        motion: hash_value(preference_snapshot, "motion", :motion, "mo", :mo) || DEFAULTS[:motion],
        density: hash_value(preference_snapshot, "density", :density, "dn", :dn) || DEFAULTS[:density],
        page_size: hash_value(preference_snapshot, "page_size", :page_size, "ps", :ps) || DEFAULTS[:page_size],
        cookie: cookie,
      )
    end

    def self.theme_from_snapshot(value)
      { "light" => "li", "dark" => "dr", "system" => "sy" }.fetch(value.to_s, value)
    end

    def self.hash_value(hash, *keys)
      key = keys.find { |candidate| hash.key?(candidate) }
      hash[key] if key
    end

    private_class_method :hash_value
    private_class_method :theme_from_snapshot

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
