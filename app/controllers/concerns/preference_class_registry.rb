# typed: false
# frozen_string_literal: true

module PreferenceClassRegistry
  module_function

  CHILD_RECORD_TYPES = %i(
    language
    timezone
    region
    theme
    currency
    date_format
    time_format
    motion
    density
    page_size
    adult_content_gate
  ).freeze

  TYPE_KEY_MAP = {
    :timezone => :timezone,
    :language => :language,
    :region => :region,
    :currency => :currency,
    :date_format => :date_format,
    :time_format => :time_format,
    :motion => :motion,
    :density => :density,
    :page_size => :page_size,
    :adult_content_gate => :adult_content_gate,
    :colortheme => :theme,
    :theme => :theme,
    "Timezone" => :timezone,
    "Language" => :language,
    "Region" => :region,
    "Currency" => :currency,
    "DateFormat" => :date_format,
    "TimeFormat" => :time_format,
    "Motion" => :motion,
    "Density" => :density,
    "PageSize" => :page_size,
    "AdultContentGate" => :adult_content_gate,
    "Colortheme" => :theme,
    "Theme" => :theme,
  }.freeze

  REGISTRY = {
    "App" => {
      preference: AppPreference,
      status: AppPreferenceStatus,
      cookie: AppPreferenceCookie,
      audit: AppPreferenceChronicle,
      audit_event: AppPreferenceChronicleEvent,
      audit_level: AppPreferenceChronicleLevel,
      option_classes: {
        timezone: AppPreferenceTimezoneOption,
        language: AppPreferenceLanguageOption,
        region: AppPreferenceRegionOption,
        theme: AppPreferenceThemeOption,
        currency: AppPreferenceCurrencyOption,
        date_format: AppPreferenceDateFormatOption,
        time_format: AppPreferenceTimeFormatOption,
        motion: AppPreferenceMotionOption,
        density: AppPreferenceDensityOption,
        page_size: AppPreferencePageSizeOption,
        adult_content_gate: AppPreferenceAdultContentGateOption,
      }.freeze,
      record_classes: {
        timezone: AppPreferenceTimezone,
        language: AppPreferenceLanguage,
        region: AppPreferenceRegion,
        theme: AppPreferenceTheme,
        currency: AppPreferenceCurrency,
        date_format: AppPreferenceDateFormat,
        time_format: AppPreferenceTimeFormat,
        motion: AppPreferenceMotion,
        density: AppPreferenceDensity,
        page_size: AppPreferencePageSize,
        adult_content_gate: AppPreferenceAdultContentGate,
      }.freeze,
    }.freeze,
    "Com" => {
      preference: ComPreference,
      status: ComPreferenceStatus,
      cookie: ComPreferenceCookie,
      audit: ComPreferenceChronicle,
      audit_event: ComPreferenceChronicleEvent,
      audit_level: ComPreferenceChronicleLevel,
      option_classes: {
        timezone: ComPreferenceTimezoneOption,
        language: ComPreferenceLanguageOption,
        region: ComPreferenceRegionOption,
        theme: ComPreferenceThemeOption,
        currency: ComPreferenceCurrencyOption,
        date_format: ComPreferenceDateFormatOption,
        time_format: ComPreferenceTimeFormatOption,
        motion: ComPreferenceMotionOption,
        density: ComPreferenceDensityOption,
        page_size: ComPreferencePageSizeOption,
        adult_content_gate: ComPreferenceAdultContentGateOption,
      }.freeze,
      record_classes: {
        timezone: ComPreferenceTimezone,
        language: ComPreferenceLanguage,
        region: ComPreferenceRegion,
        theme: ComPreferenceTheme,
        currency: ComPreferenceCurrency,
        date_format: ComPreferenceDateFormat,
        time_format: ComPreferenceTimeFormat,
        motion: ComPreferenceMotion,
        density: ComPreferenceDensity,
        page_size: ComPreferencePageSize,
        adult_content_gate: ComPreferenceAdultContentGate,
      }.freeze,
    }.freeze,
    "Org" => {
      preference: OrgPreference,
      status: OrgPreferenceStatus,
      cookie: OrgPreferenceCookie,
      audit: OrgPreferenceChronicle,
      audit_event: OrgPreferenceChronicleEvent,
      audit_level: OrgPreferenceChronicleLevel,
      option_classes: {
        timezone: OrgPreferenceTimezoneOption,
        language: OrgPreferenceLanguageOption,
        region: OrgPreferenceRegionOption,
        theme: OrgPreferenceThemeOption,
        currency: OrgPreferenceCurrencyOption,
        date_format: OrgPreferenceDateFormatOption,
        time_format: OrgPreferenceTimeFormatOption,
        motion: OrgPreferenceMotionOption,
        density: OrgPreferenceDensityOption,
        page_size: OrgPreferencePageSizeOption,
        adult_content_gate: OrgPreferenceAdultContentGateOption,
      }.freeze,
      record_classes: {
        timezone: OrgPreferenceTimezone,
        language: OrgPreferenceLanguage,
        region: OrgPreferenceRegion,
        theme: OrgPreferenceTheme,
        currency: OrgPreferenceCurrency,
        date_format: OrgPreferenceDateFormat,
        time_format: OrgPreferenceTimeFormat,
        motion: OrgPreferenceMotion,
        density: OrgPreferenceDensity,
        page_size: OrgPreferencePageSize,
        adult_content_gate: OrgPreferenceAdultContentGate,
      }.freeze,
    }.freeze,
    "Client" => {
      preference: ClientPreference,
      option_classes: {
        timezone: ClientPreferenceTimezoneOption,
        language: ClientPreferenceLanguageOption,
        region: ClientPreferenceRegionOption,
        theme: ClientPreferenceThemeOption,
        currency: ClientPreferenceCurrencyOption,
        date_format: ClientPreferenceDateFormatOption,
        time_format: ClientPreferenceTimeFormatOption,
        motion: ClientPreferenceMotionOption,
        density: ClientPreferenceDensityOption,
        page_size: ClientPreferencePageSizeOption,
        adult_content_gate: ClientPreferenceAdultContentGateOption,
      }.freeze,
      record_classes: {
        timezone: ClientPreferenceTimezone,
        language: ClientPreferenceLanguage,
        region: ClientPreferenceRegion,
        theme: ClientPreferenceTheme,
        currency: ClientPreferenceCurrency,
        date_format: ClientPreferenceDateFormat,
        time_format: ClientPreferenceTimeFormat,
        motion: ClientPreferenceMotion,
        density: ClientPreferenceDensity,
        page_size: ClientPreferencePageSize,
        adult_content_gate: ClientPreferenceAdultContentGate,
      }.freeze,
    }.freeze,
    "Operator" => {
      preference: OperatorPreference,
      option_classes: {
        timezone: OperatorPreferenceTimezoneOption,
        language: OperatorPreferenceLanguageOption,
        region: OperatorPreferenceRegionOption,
        theme: OperatorPreferenceThemeOption,
        currency: OperatorPreferenceCurrencyOption,
        date_format: OperatorPreferenceDateFormatOption,
        time_format: OperatorPreferenceTimeFormatOption,
        motion: OperatorPreferenceMotionOption,
        density: OperatorPreferenceDensityOption,
        page_size: OperatorPreferencePageSizeOption,
        adult_content_gate: OperatorPreferenceAdultContentGateOption,
      }.freeze,
      record_classes: {
        timezone: OperatorPreferenceTimezone,
        language: OperatorPreferenceLanguage,
        region: OperatorPreferenceRegion,
        theme: OperatorPreferenceTheme,
        currency: OperatorPreferenceCurrency,
        date_format: OperatorPreferenceDateFormat,
        time_format: OperatorPreferenceTimeFormat,
        motion: OperatorPreferenceMotion,
        density: OperatorPreferenceDensity,
        page_size: OperatorPreferencePageSize,
        adult_content_gate: OperatorPreferenceAdultContentGate,
      }.freeze,
    }.freeze,
    "Visitor" => {
      preference: VisitorPreference,
      option_classes: {
        timezone: VisitorPreferenceTimezoneOption,
        language: VisitorPreferenceLanguageOption,
        region: VisitorPreferenceRegionOption,
        theme: VisitorPreferenceThemeOption,
        currency: VisitorPreferenceCurrencyOption,
        date_format: VisitorPreferenceDateFormatOption,
        time_format: VisitorPreferenceTimeFormatOption,
        motion: VisitorPreferenceMotionOption,
        density: VisitorPreferenceDensityOption,
        page_size: VisitorPreferencePageSizeOption,
        adult_content_gate: VisitorPreferenceAdultContentGateOption,
      }.freeze,
      record_classes: {
        timezone: VisitorPreferenceTimezone,
        language: VisitorPreferenceLanguage,
        region: VisitorPreferenceRegion,
        theme: VisitorPreferenceTheme,
        currency: VisitorPreferenceCurrency,
        date_format: VisitorPreferenceDateFormat,
        time_format: VisitorPreferenceTimeFormat,
        motion: VisitorPreferenceMotion,
        density: VisitorPreferenceDensity,
        page_size: VisitorPreferencePageSize,
        adult_content_gate: VisitorPreferenceAdultContentGate,
      }.freeze,
    }.freeze,
  }.freeze

  def fetch(prefix)
    REGISTRY.fetch(prefix) do
      raise KeyError, "Unknown preference prefix: #{prefix.inspect}"
    end
  end

  def for_controller_path(controller_path)
    prefix = controller_path.to_s.split("/")[1]&.capitalize
    fetch(prefix)[:preference]
  end

  def prefix_from_preference_class(preference_class)
    preference_class.name.delete_suffix("Preference")
  end

  def status_class_for(preference_class)
    fetch(prefix_from_preference_class(preference_class))[:status]
  end

  def audit_class_for(preference_class)
    fetch(prefix_from_preference_class(preference_class))[:audit]
  end

  def audit_event_class_for(preference_class)
    fetch(prefix_from_preference_class(preference_class))[:audit_event]
  end

  def audit_level_class_for(preference_class)
    fetch(prefix_from_preference_class(preference_class))[:audit_level]
  end

  def cookie_class(prefix)
    fetch(prefix)[:cookie]
  end

  def option_class(prefix, type)
    fetch(prefix)[:option_classes].fetch(TYPE_KEY_MAP.fetch(type))
  end

  def record_class(prefix, type)
    fetch(prefix)[:record_classes].fetch(TYPE_KEY_MAP.fetch(type))
  end

  def default_option_id(prefix, type)
    option = option_class(prefix, type)
    case TYPE_KEY_MAP.fetch(type)
    when :timezone then option::ASIA_TOKYO
    when :language then option::JA
    when :region then option::JP
    when :theme then option::SYSTEM
    when :currency then option::JPY
    when :date_format then option::ISO
    when :time_format then option::HOUR_24
    when :motion, :density then option::STANDARD
    when :page_size then option::PER_INFINITY
    when :adult_content_gate then option::NOTHING
    end
  end

  # Symbolic audit-event constants live on each surface's
  # *PreferenceChronicleEvent class. The constant name is stable across
  # surfaces, with one historical exception:
  # UPDATE_PREFERENCE_COLORTHEME maps to UPDATE_PREFERENCE_THEME on the
  # event class.
  AUDIT_EVENT_NAME_REMAP = {
    "UPDATE_PREFERENCE_COLORTHEME" => "UPDATE_PREFERENCE_THEME",
  }.freeze

  def audit_event_id_for(audit_event_class, event_name)
    return event_name if event_name.is_a?(Integer)

    constant_name = AUDIT_EVENT_NAME_REMAP.fetch(event_name.to_s, event_name.to_s)
    unless audit_event_class.const_defined?(constant_name, false)
      raise ArgumentError,
            "unknown preference audit event #{event_name.inspect} for #{audit_event_class}"
    end

    audit_event_class.const_get(constant_name)
  end
end
