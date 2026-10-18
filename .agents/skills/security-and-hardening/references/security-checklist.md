# Security review prompts

Select questions relevant to the boundary; this is not a universal compliance claim.

- Can an actor cross a surface, tenant or ownership boundary using a valid identifier from elsewhere?
- Do expiry, replay, revocation and concurrent consumption preserve the final authorization check?
- Can a partial transaction create a cookie, audit success or authority without committed state?
- Do errors or diagnostic outputs disclose account existence, credentials or sensitive payloads?
- Are queries parameterized and outputs escaped for their actual context?
- For URL retrieval, are scheme, destination, redirects and DNS rebinding controlled at connection
  time, rather than trusting a validation lookup followed by another resolution?
- For files or model output, are untrusted bytes kept separate from execution and authorization?
- Do dependency scans cover the actual sources and versions, including Git pins? Record blind spots.
- If a credential leak is suspected, contain further disclosure and report the affected boundary;
  coordinate revocation with the responsible owner. History rewriting is not credential revocation
  and needs its own authorization.

Use the repository's accepted domain contracts and current official standards for concrete limits.
