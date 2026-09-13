// The persistent layout every Inertia page of every surface renders inside.
//
// It replaces the header and footer that the surface ERB layouts used to build, and it is
// persistent in the Inertia sense: a visit swaps the page below it without remounting the chrome,
// so the cookie banner keeps its dismissed state and the theme control keeps its selection across
// navigation. It renders nothing it decides for itself — `chrome` is a shared prop assembled by
// SurfaceChrome on the server.
//
// The document structure here is plain semantic HTML on purpose. Landmarks, headings and lists are
// what assistive technology navigates by, and React Aria has nothing to add to them: it is an
// interaction layer, and there is no interaction in a header.
//
// Horizontal measure is owned here and nowhere else. The header, the main column and the footer all
// take `SHELL`, so the brand, the page title and the footer links sit on one vertical line at every
// width. A page picks how narrow it wants to be inside that column through `Page`'s `width`; it
// never restates the gutter.
import { usePage } from "@inertiajs/react";
import type { ReactNode } from "react";

import CookieBanner from "@/components/chrome/CookieBanner";
import ThemeControls from "@/components/chrome/ThemeControls";

const SHELL = "mx-auto w-full max-w-4xl px-4 sm:px-6";

const NAV_LINK = "text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline";

export default function SurfaceLayout({ children }: { children: ReactNode }) {
  const { chrome } = usePage().props;

  return (
    <div className="flex min-h-screen flex-col">
      {/*
        Sticky, because the brand is also the way back out of a ceremony and a long settings page
        would otherwise scroll it away. Translucent over a blur so the page reads as continuing
        underneath the bar rather than being clipped by it; the opaque fallback is the same token,
        so an engine without `backdrop-filter` loses the effect and nothing else.
      */}
      <header className="sticky top-0 z-30 border-b border-line bg-surface/85 backdrop-blur">
        {/*
          Restricted Mode sits above everything else in the header and outside the page, so it is
          visible for the whole life of an Emergency session and no single screen can drop it. It
          is a shared prop, not page state: a page has no way to render this or to suppress it.

          There is deliberately no "leave Restricted Mode" control. The only way back to a normal
          session is to end this one and sign in again, which is what the link does.
        */}
        {chrome.restricted_mode ? (
          <section
            aria-label={chrome.restricted_mode.label}
            className="border-b border-line bg-danger text-danger-fg"
          >
            <div
              className={`${SHELL} flex flex-wrap items-baseline gap-x-3 gap-y-1 py-2.5 text-sm`}
            >
              <p className="font-semibold">{chrome.restricted_mode.label}</p>
              <p>{chrome.restricted_mode.description}</p>
              <a
                href={chrome.restricted_mode.sign_out.href}
                className="underline underline-offset-4"
              >
                {chrome.restricted_mode.sign_out.label}
              </a>
            </div>
          </section>
        ) : null}

        {chrome.banner ? (
          <section
            aria-label="banner"
            className="border-b border-line bg-surface-muted"
          >
            <div className={`${SHELL} flex flex-col gap-0.5 py-2.5 text-sm text-fg`}>
              {chrome.banner.title ? (
                <h2 className="font-semibold">{chrome.banner.title}</h2>
              ) : null}
              <p className="text-fg-muted">{chrome.banner.body}</p>
            </div>
          </section>
        ) : null}

        <div
          className={`${SHELL} flex flex-wrap items-center justify-between gap-x-6 gap-y-2 py-3`}
        >
          <p className="flex flex-wrap items-baseline gap-x-2 text-base font-semibold text-fg">
            <a
              href={chrome.brand.href}
              className="underline-offset-4 hover:underline"
            >
              {chrome.brand.name}
            </a>
            {chrome.family_label ? (
              <span className="font-normal text-fg-muted">{chrome.family_label}</span>
            ) : null}
            <span className="text-sm font-normal text-fg-muted">({chrome.surface})</span>
          </p>
        </div>
      </header>

      <main
        id="main"
        className="grow py-10 sm:py-14"
      >
        <div className={SHELL}>{children}</div>
      </main>

      {/*
        The footer is the page's floor, so it takes the canvas rather than the surface colour: the
        content above it sits on cards, and repeating the card colour down here made the page look
        like it ended twice.
      */}
      <footer className="mt-16 border-t border-line bg-canvas">
        <div className={`${SHELL} flex flex-col gap-6 py-8`}>
          {chrome.footer_navigation ? (
            <nav aria-label="Footer">
              <ul className="flex flex-wrap gap-x-5 gap-y-2">
                {chrome.footer_navigation.map((link) => (
                  <li key={link.href}>
                    <a
                      href={link.href}
                      className={NAV_LINK}
                    >
                      {link.label}
                    </a>
                  </li>
                ))}
              </ul>
            </nav>
          ) : null}

          {chrome.theme_controls ? (
            <aside aria-label="Preferences">
              <ThemeControls controls={chrome.theme_controls} />
            </aside>
          ) : null}

          <p className="text-xs text-fg-muted">{chrome.copyright}</p>
        </div>
      </footer>

      {/*
        Outside the footer: the banner is fixed to the viewport, so nesting it inside a
        content landmark misreports where it sits in the document.
      */}
      {chrome.cookie_controls ? <CookieBanner controls={chrome.cookie_controls} /> : null}
    </div>
  );
}
