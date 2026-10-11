# typed: false
# frozen_string_literal: true

# Props for the base preference edit screens, shared by the app, com, and org surfaces.
#
# This is the Inertia counterpart of `app/views/base/shared/preference/{option,selectable,cookie,
# customizations}.html.erb`: the same four screen shapes, with every label translated and every URL
# generated on the server so the React components stay pure renderers and the request context stays
# in Rails. It is the sibling of BasePreferenceIndexPage, which covers the index.
module BasePreferenceScreenPage
  extend ActiveSupport::Concern

  # Region groups the screens that depend on it; the region screen links to each of them.
  REGION_LINKED_SCREENS = {
    timezone: :timezone,
    language: :language,
    currency: :currency,
    calendar: :date_format,
    clock: :time_format,
  }.freeze

  COOKIE_CATEGORIES = {
    functional: :accept_functional_cookies,
    performant: :accept_performance_cookies,
    targetable: :accept_targeting_cookies,
    consented: :accept_consent_cookies,
  }.freeze

  private

  def preference_screen_component
    "base/#{preference_surface_key}/preference/#{preference_screen_component_name}"
  end

  # The four screen shapes, mirroring the four shared templates this replaces. It is deliberately
  # not `preference_screen_template_name`: that one pluralises the selectable screens into template
  # names the dispatch never rendered, because those screens render the shared selectable template.
  def preference_screen_component_name
    case preference_key.to_s
    when "region", "timezone", "language", "theme" then "option"
    when "cookie" then "cookie"
    else "selectable"
    end
  end

  def preference_screen_page_props
    case preference_screen_component_name
    when "option" then preference_option_page_props
    when "cookie" then preference_cookie_page_props
    else preference_selectable_page_props
    end
  end

  # --- option: region, timezone, language, theme -------------------------------------------------

  def preference_option_page_props
    screen = preference_option_screen
    model = instance_variable_get(:"@preference_#{screen}")
    title = preference_option_title(screen)

    {
      screen: screen,
      title: title,
      description: t(preference_acme_i18n_key(:preference, screen, :edit, :description)),
      back_link: {
        label: preference_back_link_label,
        href: preference_option_back_href(screen),
      },
      form: {
        action: preference_screen_url_for(screen),
        method: "patch",
        scope: "preference_#{screen}",
        field: "option_id",
        label: t(preference_acme_i18n_key(:preference, screen, :edit, :"#{screen}_label")),
        value: model.option_id,
        choices: preference_option_choices(screen, model),
        submit_label: t(preference_acme_i18n_key(:preferences, :update_settings)),
        submitting_label: t(preference_acme_i18n_key(:preferences, :submitting)),
      },
      region_link: (preference_region_link unless screen == "region"),
      linked_screens: ((screen == "region") ? preference_region_linked_screens : []),
    }
  end

  def preference_option_screen
    @preference_screen.presence || params[:preference_screen].to_s
  end

  def preference_option_title(screen)
    t(preference_acme_i18n_key(:preference, screen, :edit, :heading))
  end

  def preference_back_link_label
    t(preference_acme_i18n_key(:preferences, :regions, :back_link))
  end

  def preference_option_back_href(screen)
    if screen == "region"
      preference_screen_helper("base_%<surface>s_preference_path", context: true)
    else
      preference_screen_helper("edit_base_%<surface>s_preference_region_path", context: true)
    end
  end

  def preference_region_link
    {
      label: t(preference_acme_i18n_key(:preferences, :region_settings)),
      href: preference_screen_helper("edit_base_%<surface>s_preference_region_path", context: true),
    }
  end

  def preference_region_linked_screens
    REGION_LINKED_SCREENS.map do |screen, label_key|
      {
        key: screen.to_s,
        label: t(preference_acme_i18n_key(:preferences, :region, label_key, :link)),
        href: preference_screen_edit_url_for(screen),
      }
    end
  end

  # The option label for these screens is not `preference_option_label`: region, timezone, and
  # language each resolve through their own translation tree.
  def preference_option_choices(screen, model)
    option_class = model.class.reflect_on_association(:option)&.klass
    option_type = screen.to_sym

    preference_ordered_options(option_class, option_type).filter_map do |option|
      name = option.name.to_s
      next if name.blank?

      {
        label: t(preference_option_translation_key(option_type, name)),
        value: option.id,
        disabled: option.id == model.option_id,
      }
    end
  end

  # Timezone options are presented in ascending UTC offset (UTC-12 .. UTC+00 .. UTC+14) rather than
  # by row id; every other option set keeps its curated id order. The offset is the standard
  # (non-DST) one, so the list does not reshuffle twice a year -- see TimezoneIdentifier.
  def preference_ordered_options(option_class, option_type)
    rows = option_class.order(:id).to_a
    return rows unless option_type == :timezone

    rows.sort_by { |option| TimezoneIdentifier.utc_offset_sort_key(option.name) }
  end

  def preference_option_key(option_type, name)
    (option_type == :timezone) ? name.tr("/", "_").upcase : name
  end

  def preference_option_translation_key(option_type, name)
    key = preference_option_key(option_type, name)

    case option_type
    when :timezone
      preference_acme_i18n_key(:preference, :locale, :edit, :timezone_options, key)
    when :region
      preference_acme_i18n_key(:preferences, :regions, :select_region_selector, name.upcase)
    else
      preference_acme_i18n_key(:preference, preference_option_screen, :options, key)
    end
  end

  # --- selectable: currency, calendar, clock, motion, density, pagination -------------------------

  def preference_selectable_page_props
    type = @preference_option_type

    {
      screen: type.to_s,
      title: t(preference_base_i18n_key(:preference, type, :edit, :heading)),
      description: t(preference_base_i18n_key(:preference, type, :edit, :description)),
      back_link: {
        label: t(preference_base_i18n_key(:preferences, :regions, :back_link)),
        href: @preference_option_back_url,
      },
      form: {
        action: @preference_option_update_url,
        method: "patch",
        scope: @preference_option_scope.to_s,
        field: "option_id",
        label: t(preference_base_i18n_key(:preference, type, :edit, :option_label)),
        value: @preference_option.option_id,
        choices: @preference_option_choices.map { |label, value|
          { label: label, value: value, disabled: value == @preference_option.option_id }
        },
        submit_label: t(preference_base_i18n_key(:preferences, :update_settings)),
        submitting_label: t(preference_base_i18n_key(:preferences, :submitting)),
      },
      region_link: nil,
      linked_screens: [],
    }
  end

  # --- cookie ------------------------------------------------------------------------------------

  def preference_cookie_page_props
    {
      screen: "cookie",
      title: t(preference_acme_i18n_key(:preference, :cookie, :edit, :h1)),
      description: t(preference_acme_i18n_key(:preference, :cookie, :edit, :description)),
      back_link: {
        label: t("actions.back"),
        href: preference_screen_helper("base_%<surface>s_preference_path", context: true),
      },
      form: {
        action: preference_screen_url_for("cookie"),
        method: "patch",
        scope: "preference_cookie",
        # Strictly necessary cookies cannot be declined, so the row is rendered read-only.
        necessary_label: t(preference_acme_i18n_key(:preference, :cookie, :edit, :accept_necessary_cookies)),
        categories: COOKIE_CATEGORIES.map do |field, label_key|
          {
            key: field.to_s,
            label: t(preference_acme_i18n_key(:preference, :cookie, :edit, label_key)),
            value: @preference_cookie.public_send(field) ? true : false,
          }
        end,
        submit_label: t(preference_acme_i18n_key(:preferences, :update_settings)),
        submitting_label: t(preference_acme_i18n_key(:preferences, :submitting)),
      },
    }
  end

  # --- customizations (reset) --------------------------------------------------------------------

  def preference_customization_component
    "base/#{preference_surface_key}/preference/customizations"
  end

  def preference_customization_page_props
    {
      screen: "customization",
      title: t(preference_acme_i18n_key(:preference, :resets, :title)),
      description: t(preference_acme_i18n_key(:preference, :resets, :description)),
      back_link: {
        label: t(preference_acme_i18n_key(:preferences, :regions, :back_link)),
        href: preference_screen_helper("base_%<surface>s_preference_path", context: true),
      },
      form: {
        action: preference_screen_url_for("customization"),
        method: "delete",
        field: "confirm_reset",
        label: t(preference_acme_i18n_key(:preference, :resets, :confirm)),
        value: @preference&.confirm_reset == "1",
        submit_label: t(preference_acme_i18n_key(:preference, :resets, :button)),
        submitting_label: t(preference_acme_i18n_key(:preferences, :submitting)),
      },
    }
  end

  # --- url helpers -------------------------------------------------------------------------------

  def preference_screen_url_for(screen)
    public_send("base_#{preference_surface_key}_preference_#{screen}_path", ri: params[:ri])
  end

  def preference_screen_edit_url_for(screen)
    public_send(
      "edit_base_#{preference_surface_key}_preference_#{screen}_path",
      lx: params[:lx], ri: params[:ri],
    )
  end

  def preference_screen_helper(template, context: false)
    name = format(template, surface: preference_surface_key)
    context ? public_send(name, lx: params[:lx], ri: params[:ri]) : public_send(name)
  end
end
