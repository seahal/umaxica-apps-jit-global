import { Controller } from "@hotwired/stimulus";

import { readBoolean } from "@/lib/payload";
import { sameOriginEndpoint } from "@/lib/request";

// Connects to data-controller="cookie-toggle"
export default class extends Controller {
  static override targets = ["checkbox", "status"];
  static override values = {
    endpointUrl: String,
  };

  // Stimulus defines these from `static targets` at registration; the declarations record what it
  // creates so the compiler sees the same properties the runtime does.
  declare readonly checkboxTargets: HTMLInputElement[];
  declare readonly statusTarget: HTMLElement;
  declare readonly hasStatusTarget: boolean;
  declare readonly endpointUrlValue: string;
  declare readonly hasEndpointUrlValue: boolean;

  override connect() {
    this.updateStatus();
    this.setupFormListener();
  }

  toggle(_event: Event) {
    this.updateStatus();
  }

  setupFormListener() {
    const form = this.element.querySelector("form");
    if (form) {
      form.addEventListener("turbo:submit-end", (event) => {
        void this.onFormSubmitEnd(event);
      });
    }
  }

  async onFormSubmitEnd(event: Event) {
    if (!(event instanceof CustomEvent) || readBoolean(event.detail, "success") !== true) {
      return;
    }

    const url = this.cookieEndpointUrl();
    try {
      const consentState = await this.fetchCookieConsent(url);
      // A body that is not an object carries no consent to sync; the checkboxes stay as they are.
      if (typeof consentState === "object" && consentState !== null) {
        this.syncCheckboxesFromAPI(consentState);
        this.updateStatus();
      }
    } catch {
      this.updateStatus();
    }
  }

  async fetchCookieConsent(url: string): Promise<unknown> {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const body: unknown = await response.json();
    return body;
  }

  cookieEndpointUrl() {
    if (!this.hasEndpointUrlValue || this.endpointUrlValue === "") {
      throw new Error("cookie toggle rendered without data-cookie-toggle-endpoint-url-value");
    }
    const endpoint = sameOriginEndpoint(this.endpointUrlValue);
    endpoint.search = window.location.search;
    return endpoint.toString();
  }

  syncCheckboxesFromAPI(consentState: unknown) {
    const fields = ["functional", "performant", "targetable", "consented"];

    fields.forEach((fieldName) => {
      const checkbox = this.element.querySelector<HTMLInputElement>(
        `input[name="preference_cookie[${fieldName}]"]`,
      );
      const value = readBoolean(consentState, fieldName);
      if (checkbox && value !== undefined) {
        checkbox.checked = value;
      }
    });
  }

  updateStatus() {
    if (this.hasStatusTarget) {
      const checkedCount = this.checkboxTargets.filter((cb) => cb.checked).length;
      const totalCount = this.checkboxTargets.length;
      this.statusTarget.textContent = `${checkedCount} / ${totalCount} cookies enabled`;
    }
  }
}
