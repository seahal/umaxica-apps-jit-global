// Client-side theme application.
//
// Rails renders `data-theme` and the theme class on <html> from the `ct` cookie so the first paint
// already carries the visitor's theme. This module keeps that in sync afterwards: a new choice is
// applied only after the server accepts it, the system setting is followed while the choice is
// "system", and the stored preference remains the authority.
//
// The wire format is the two-letter code the preference store uses; `Theme` is the name the UI
// works in. Converting at the boundary keeps the codes out of the components.

import { readCookie, watchCookie } from "@/lib/cookies";
import { readString } from "@/lib/payload";

export type Theme = "dark" | "light" | "system";

const THEME_BY_CODE: Record<string, Theme> = {
  dr: "dark",
  dark: "dark",
  li: "light",
  light: "light",
  sy: "system",
  system: "system",
};

const CODE_BY_THEME: Record<Theme, string> = {
  dark: "dr",
  light: "li",
  system: "sy",
};

export function themeFromCode(value: string | null | undefined): Theme {
  if (value === undefined || value === null || value.length === 0) {
    return "system";
  }
  return THEME_BY_CODE[value.toLowerCase()] ?? "system";
}

export function codeFromTheme(theme: Theme): string {
  return CODE_BY_THEME[theme];
}

/** The stored theme, read from the `ct` cookie. */
export async function readThemeCookie(): Promise<Theme> {
  return themeFromCode(await readCookie("ct"));
}

/**
 * Calls back with the theme whenever the `ct` cookie changes. Returns an unsubscribe function.
 *
 * The theme preference screen saves through the server, so the cookie is what actually carries the
 * new choice back to the document - on every surface, under either navigation model, and whether
 * or not a navigation happens at all.
 */
export function watchThemeCookie(listener: (theme: Theme) => void): () => void {
  return watchCookie("ct", (value) => listener(themeFromCode(value)));
}

/**
 * The theme the document is currently rendered in.
 *
 * Rails writes `data-theme` from the `ct` cookie and `applyTheme` keeps it in step, so this is the
 * same answer `readThemeCookie` gives - available synchronously, which the cookie no longer is.
 * It is what a React initial state and the system-theme watcher read, so neither has to wait for a
 * cookie read to render the theme the visitor is already looking at.
 */
export function themeFromDocument(): Theme {
  return themeFromCode(document.documentElement.dataset["theme"]);
}

export function applyTheme(theme: Theme): void {
  const html = document.documentElement;
  const applied =
    theme === "system"
      ? window.matchMedia("(prefers-color-scheme: dark)").matches
        ? "dark"
        : "light"
      : theme;

  html.dataset["theme"] = theme;
  html.classList.remove("theme-dark", "theme-light", "theme-system");
  html.classList.add(`theme-${theme}`);
  html.classList.toggle("dark", applied === "dark");
}

/**
 * Keeps the document following the system setting. Returns a cleanup function so a React effect
 * can unsubscribe; the caller owns which theme is current.
 */
export function watchSystemTheme(currentTheme: () => Theme): () => void {
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  const sync = () => applyTheme(currentTheme());

  media.addEventListener("change", sync);

  return () => media.removeEventListener("change", sync);
}

function themeEndpointUrl({ includeThemeParams = true }: { includeThemeParams?: boolean } = {}) {
  const endpoint = new URL("/web/v0/theme", window.location.origin);
  endpoint.search = window.location.search;
  if (!includeThemeParams) {
    endpoint.searchParams.delete("ct");
    endpoint.searchParams.delete("theme");
  }
  return endpoint.toString();
}

/** The stored preference, or null when it cannot be read; the cookie stays authoritative then. */
export async function fetchStoredTheme(): Promise<Theme | null> {
  try {
    const response = await fetch(themeEndpointUrl());
    if (!response.ok) {
      return null;
    }
    const data: unknown = await response.json();
    return themeFromCode(readString(data, "theme"));
  } catch {
    return null;
  }
}

/**
 * Persists a choice and returns the theme the server stored. Returns null when the write is not
 * accepted or the response names no theme — callers must not apply a colour until this resolves to
 * a stored value.
 */
export async function persistTheme(theme: Theme, csrf: string): Promise<Theme | null> {
  try {
    const response = await fetch(themeEndpointUrl({ includeThemeParams: false }), {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(csrf ? { "X-CSRF-Token": csrf } : {}),
      },
      body: JSON.stringify({ theme }),
    });

    if (!response.ok) {
      return null;
    }

    const data: unknown = await response.json();
    const code = readString(data, "theme");
    return code ? themeFromCode(code) : null;
  } catch {
    return null;
  }
}
