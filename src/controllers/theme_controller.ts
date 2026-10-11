import { Controller } from "@hotwired/stimulus";

import { csrfToken } from "@/lib/csrf";
import {
  type Theme,
  applyTheme,
  fetchStoredTheme,
  persistTheme,
  readThemeCookie,
  themeFromCode,
  themeFromDocument,
} from "@/lib/theme";

// The theme radio group on the surfaces that do not boot React.
//
// The cookie parsing, the code-to-theme mapping, the DOM application and both HTTP calls live in
// `@/lib/theme`, which the React theme controls use as well. This controller is only the radio
// group: it reflects the current theme into the inputs and reports the choice.
export default class extends Controller {
  // The visitor's own choice, once made. It wins over a slower server answer, which would
  // otherwise arrive after the click and move the selection back.
  private selectedTheme: Theme | null = null;

  override connect() {
    void this.syncFromServer();
  }

  select(event: Event) {
    const { target } = event;

    if (!(target instanceof HTMLInputElement)) {
      return;
    }

    const theme = themeFromCode(target.value);
    this.selectedTheme = theme;
    void this.persist(theme);
  }

  async persist(theme: Theme) {
    const stored = await persistTheme(theme, csrfToken());
    if (!stored) {
      this.selectedTheme = null;
      this.showTheme(themeFromDocument());
      return;
    }

    this.selectedTheme = stored;
    this.showTheme(stored);
  }

  async syncFromServer() {
    const stored = await fetchStoredTheme();

    if (this.selectedTheme !== null) {
      return;
    }

    // The cookie is authoritative when the server cannot be reached: it is what the first paint
    // already used.
    this.showTheme(stored ?? (await readThemeCookie()));
  }

  /** Applies a theme to the document and reflects it into the radio group and the value readout. */
  showTheme(theme: Theme) {
    applyTheme(theme);

    // The radios carry the theme name, not the wire code
    // (app/views/layouts/shared/_footer_theme_controls.html.erb).
    const radio = this.element.querySelector<HTMLInputElement>(`input[value="${theme}"]`);
    if (radio) {
      radio.checked = true;
    }

    const valueElement = document.querySelector("#js-theme-cookie-value");
    if (valueElement) {
      valueElement.textContent = theme;
    }
  }
}
