# Third-Party Sign-In Button Requirements

Design constraints that must not be changed on Google and Apple sign-in buttons.

## Scope

Applies to every Google and Apple sign-in entry point on the `app` surface: the sign-in page, the
sign-up page, the social ceremony start page, and the link action on the settings pages.

The `org` surface uses Microsoft Entra ID; Microsoft brand rules are outside this document. The
`com` surface has no social sign-in.

## Why these are MUST NOT items

Google and Apple both make correct button presentation a condition of using their identity service.
Non-compliance is not a style disagreement: it can cost API access, block App Review, and create
trademark and contract liability. Treat every item below as a hard boundary. If a design requirement
conflicts with one of these, the design requirement loses.

Do not invent a button. Do not approximate one from memory. Read this page and the linked official
sources before writing button markup.

## Google — MUST NOT

- Alter the size or colour of the Google "G" logo. Only the standard colour version is permitted.
- Use a monochrome "G", a self-drawn icon, or a superseded Google logo.
- Show the "G" icon alone, without a button boundary and accompanying text.
- Place the standard "G" on any background other than the approved themes: light `#FFFFFF`, dark
  `#131314`, or neutral `#F2F2F2`.
- Use "Google" alone as the label, without an action verb.
- Use any call to action other than "Sign in with Google", "Sign up with Google", or "Continue with
  Google".
- Distort the aspect ratio when scaling.
- Present the Google button less prominently than other third-party sign-in options.

### Google — required and permitted values

- Text colour: `#1F1F1F` on the light and neutral themes, `#E3E3E3` on the dark theme.
- Font: Google Sans Medium, 14/20.
- Web and Android padding: 12px before the logo, 10px after the logo, 12px after the text. iOS
  padding: 16px, 12px, 16px.
- Shape: rectangular or pill.
- Localising the label into the interface language is encouraged.

## Apple — MUST NOT

- Use any title other than "Sign in with Apple", "Sign up with Apple", or "Continue with Apple".
- Change the general button shape: rectangular for logo plus text; circular or rectangular for
  logo-only.
- Recolour the logo or the title. They are black together or white together, never a custom colour.
- Use any appearance other than black, white, or white with outline.
- Recreate, redraw, or trace the Apple logo. Only official artwork from Apple Design Resources may
  be used.
- Go below the minimum size of 140pt wide by 30pt high.
- Crowd the button. The minimum margin is 1/10 of the button height, the minimum right margin is 8%
  of the button width, and a logo-only button stays at a 1:1 aspect ratio with no added horizontal
  padding, because the supplied artwork already includes its padding.
- Make the button smaller than other sign-in buttons, or place it where a user has to scroll to
  reach it.

### Apple — permitted variation

- Corner radius anywhere from square corners to a capsule.
- Title font weight and size, and all-caps casing where the surrounding interface requires it.
- Background texture or subtle gradient, within black or white.
- Button bezel and drop shadow.
- Logo inset, to align the logo with other providers' logos.

A custom button must remain instantly identifiable as a Sign in with Apple button. For a logo plus
text button, use the system font with the title at roughly 43% of the button height, and match the
logo height to the button height.

Apple's own web button component accepts these values, which also bound what a custom button should
look like:

| Attribute            | Allowed values                                      |
| -------------------- | --------------------------------------------------- |
| `data-type`          | `sign-in` (default), `continue`, `sign-up`          |
| `data-color`         | `black` (default), `white`                          |
| `data-border`        | `true` (default), `false`                           |
| `data-border-radius` | 0–50 (default 15)                                   |
| `data-width`         | 130–375, or `100%` (default)                        |
| `data-height`        | 30–64, or `100%` (default)                          |
| `data-mode`          | `center-align` (default), `left-align`, `logo-only` |

## Artwork

Use official artwork only. Commit the files to this repository; do not hot-link a provider CDN, and
do not redraw a logo by hand.

### Google — in the repository

`public/images/social/google_sign_in_light.svg` and `google_sign_in_dark.svg` are the complete
official button artwork, taken unmodified from Google's `signin-assets.zip`
(`Android + Web/SVG/{Light,Dark}/Theme=…, Show text=Yes, Shape=Square`). Only the file names were
changed. Each is 180×40 with the wording drawn as paths, so it needs no font and no recolouring.

They are served from `public/` rather than the asset pipeline, because the pipeline resolves through
a precompiled manifest that CI does not build.

The artwork carries English "Sign in with Google" wording, so the button's accessible name is that
same English string rather than the locale string. The sign-up page uses the same asset: the zip has
no "Sign up with Google" variant, and "Sign in with Google" is one of the three permitted calls to
action. If a localised or sign-up variant is wanted later, take it from Google, do not typeset one.

### Apple — in the repository

`app/views/auth/shared/_social_provider_button.html.erb` renders a custom Apple button, styled in
`src/styles/social_button.css` to the guideline constraints: black with a bezel on light backgrounds
and white with an outline on dark, 8px corner radius, title at 17px in the system font (roughly 43%
of the button height), 4px vertical margin and 8% minimum right margin. The title comes from the
locale and every locale value is on the permitted call-to-action list.

Both buttons are 180x40 and stacked in a `.social-provider-buttons` list, because each provider
requires that its button is not less prominent than the other's. 180x40 is the natural size of the
Google artwork, which must not be scaled out of ratio, and is above Apple's 140x30 minimum.

The logo is `public/images/social/apple_logo_white.svg` on the black button and
`apple_logo_black.svg` on the white button. Both are the unmodified 31x44 left-aligned medium SVG
from Apple Design Resources; only the file names were changed. They are drawn at 28x40, the same
ratio at the button height, and flush against the left edge, because the artwork already carries its
own padding and its own opaque background matching the button colour. The button clips them to its
corner radius.

The complete download from <https://developer.apple.com/design/resources/> — left-aligned and
logo-only, in PDF, PNG and SVG, at every offered size — is archived unmodified under
`src/assets/brand/sign-in-with-apple/`. Take any future variant from there rather than editing the
served files. The download requires an Apple Developer account, so re-fetching needs a maintainer.

`Auth::CommonHelper::APPLE_SIGN_IN_LOGOS_PRESENT` resolves the served files' presence once at load,
and the button falls back to its title alone if a deployment lacks them. Do not turn that into a
per-request check, and do not substitute a redrawn logo.

Community Sketch and Figma files that reproduce the button are not official artwork and must not be
used as the source, however accurate they look. <https://appleid.apple.com/signinwithapple/button>
is useful for previewing colour, corner radius, and size, but it is not an artwork download either.

## Sources

- Google: <https://developers.google.com/identity/branding-guidelines>
- Apple, Human Interface Guidelines:
  <https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple/>
- Apple, web button reference:
  <https://developer.apple.com/documentation/signinwithapple/displaying-sign-in-with-apple-buttons-on-the-web>
- Apple Design Resources: <https://developer.apple.com/design/resources/>

Apple's Human Interface Guidelines pages render client-side. Their content was read through Apple's
documentation JSON endpoint for the same paths.
