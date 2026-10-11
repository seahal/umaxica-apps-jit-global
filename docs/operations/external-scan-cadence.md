# External Scan Cadence

External, third-party scanners observe the deployed surfaces from the public internet. They cover
what repository tests cannot: the live TLS termination, the headers actually emitted by the edge,
and the delivered page performance. Repository tests remain authoritative for application behavior;
these scans are authoritative for deployed edge configuration.

## Scanned Surfaces

Run every scan against the production hostname of each trust boundary separately. A passing result
on one surface says nothing about the others.

- `app` — end-user application
- `org` — staff and organization surface
- `com` — public and corporate surface

## Scanners and Cadence

### Transport and Headers

| Scanner                  | URL                                             | Scope                                                              | Cadence                                                                                                      |
| ------------------------ | ----------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Qualys SSL Labs          | https://www.ssllabs.com/ssltest/                | TLS protocol, cipher suites, certificate chain, HSTS preload       | Quarterly, and after any TLS, certificate, or CDN change                                                     |
| Mozilla HTTP Observatory | https://developer.mozilla.org/en-US/observatory | Security headers, CSP, cookie flags, subresource integrity         | Monthly, and after any change under `config/initializers/content_security_policy.rb` or header configuration |
| Security Headers         | https://securityheaders.com/                    | Response header presence and values                                | Monthly, together with the Observatory run                                                                   |
| CSP Evaluator            | https://csp-evaluator.withgoogle.com/           | Whether the delivered policy is actually bypassable                | With every Observatory run, and after any policy change                                                      |
| HSTS Preload             | https://hstspreload.org/                        | Preload list membership and eligibility of each registrable domain | Quarterly, and before any subdomain or hostname change                                                       |

Header scanners report only that a header is present. CSP Evaluator is what determines whether the
policy is meaningful, so treat `unsafe-inline`, an over-broad host allowlist, or a missing
`object-src` as a finding even when Security Headers reports a top grade.

HSTS preload applies to the registrable domain and all subdomains at once. Because the `app`, `org`,
and `com` surfaces are separated by subdomain, confirm preload state before adding, renaming, or
retiring any hostname. See `docs/reference/subdomains.md`.

Scan both a representative unauthenticated page and, where the scanner permits, a page that is
representative of the authenticated layout, because header and asset behavior can differ between
them. Cookie attributes (`Secure`, `HttpOnly`, `SameSite`, and the `__Host-` prefix) are partly
covered by the Observatory; verify them externally as well, because surface separation depends on
them and application tests cannot observe what the edge finally emits.

### DNS, Mail, and Certificates

The application sends authentication mail, so sender authentication is a security control of the
same standing as TLS. Domain-level checks apply to the registrable domain, not to a single surface.

| Scanner                                           | Scope                                                                                                   | Cadence                                               |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| MXToolbox, dmarcian, or Hardenize                 | SPF, DKIM, DMARC, MTA-STS, TLS-RPT                                                                      | Quarterly, and after any mail provider or DNS change  |
| Same tooling                                      | CAA records, as protection against certificate mis-issuance                                             | Quarterly, and after any certificate authority change |
| Certificate Transparency search (https://crt.sh/) | Unexpected certificates issued for the domain, and forgotten subdomains that indicate takeover exposure | Monthly                                               |

### Content Delivery and Reachability

| Scanner                                                        | Scope                                                                                   | Cadence                                                                        |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| PageSpeed Insights (https://pagespeed.web.dev/)                | Core Web Vitals, Lighthouse performance, accessibility, SEO                             | Monthly, and before and after any front-end bundle or asset-delivery change    |
| WebPageTest (https://www.webpagetest.org/)                     | Field-representative measurement across network conditions and regions                  | After CDN or asset-delivery configuration changes only                         |
| Google Safe Browsing status, via Search Console URL inspection | Whether a public surface is flagged or blocked                                          | Monthly, with the checks in `docs/operations/search-engine-webmaster-tools.md` |
| Manual external fetch of `.well-known` paths                   | `openid-configuration`, `security.txt`, `apple-app-site-association`, `assetlinks.json` | Monthly, and after any routing or edge change                                  |

The `.well-known` check is a reachability check rather than a graded scan, but it must be run from
outside the network, because a routing or edge rule can break these paths without failing any
in-repository test.

### Out of Scope

Do not add active scanners such as ZAP, Nikto, or credential-spraying tools to this cadence. Pointed
at authenticated surfaces they cause account lockouts, pollute rate-limit state, and contaminate
audit data. Any such testing belongs in a separate, explicitly agreed engagement against a
non-production environment.

## Thresholds

Treat a result below these levels as a defect to triage, not as informational output.

| Scanner                  | Minimum accepted result                                                  |
| ------------------------ | ------------------------------------------------------------------------ |
| Qualys SSL Labs          | A                                                                        |
| Mozilla HTTP Observatory | A                                                                        |
| Security Headers         | A                                                                        |
| PageSpeed Insights       | Performance 90, Accessibility 90, Best Practices 90, SEO 90 on mobile    |
| CSP Evaluator            | No high-severity finding on any surface                                  |
| HSTS Preload             | Every production registrable domain listed as preloaded                  |
| SPF, DKIM, DMARC         | All present and passing, with a DMARC policy of `quarantine` or `reject` |
| MTA-STS, TLS-RPT, CAA    | Published and syntactically valid                                        |
| Certificate Transparency | Every certificate issued for the domain accounted for                    |
| Safe Browsing            | No flag on any public surface                                            |
| `.well-known` paths      | All expected paths reachable and correctly typed                         |

A regression below a previously achieved level is a defect even when the new result still meets the
minimum.

## Procedure

1. Run each surface-level scan against every surface hostname. Run the DNS, mail, certificate, and
   preload checks once per registrable domain.
2. Record the date, surface, scanner, and result grade or score.
3. For any result below the threshold, or any regression, open a tracking issue that names the
   failing control and the responsible configuration.
4. Fix the configuration in this repository when the cause is application-side. When the cause is
   edge or CDN configuration, record the external change and link it from the issue.
5. Re-run the scan after the fix is deployed and confirm the result before closing the issue.

Qualys SSL Labs and PageSpeed Insights publish results by default. Use the SSL Labs option that
suppresses publication of the results board entry. Do not submit URLs that contain session
identifiers, tokens, or other credentials in the path or query string.

## Related

- `docs/security/security-headers.md`
- `docs/security/public-entrypoints.md`
- `docs/operations/health-check.md`
- `docs/operations/search-engine-webmaster-tools.md`
- `docs/reference/subdomains.md`
