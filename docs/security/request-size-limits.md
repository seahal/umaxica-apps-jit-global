# Request Size Limits

Rails rejects JSON request bodies larger than 1 MiB before the Rails parameter parser reads them.
The boundary is the `RequestBodySizeLimit` Rack middleware, inserted immediately after
`ActionDispatch::RequestId` and before the application routes. It checks both a declared
`Content-Length` and bodies with no usable length declaration, reading at most one byte beyond the
limit. A declared invalid or negative length receives the registered `bad-request` Problem Details
response.

Only `application/json` and structured `+json` media types are covered. Compressed JSON is rejected
as unsupported because this boundary does not decompress attacker-controlled input; accepting a
compressed format requires a separately bounded decompression contract. Multipart and other upload
content types are intentionally outside this middleware and retain their existing upload-specific
limits.

The 1 MiB value is a Rails-side defense-in-depth limit for ordinary JSON APIs. It does not replace
Cloudflare, proxy, or server ingress limits, and it must not be described as evidence that those
external limits are configured. A client-visible oversize response uses the registered
`urn:umaxica:problem:content-too-large` Problem Details type and `413 Content Too Large`.

The implementation follows the Rails middleware configuration contract:

- https://guides.rubyonrails.org/configuring.html#adding-custom-middleware
- https://rack.github.io/rack/3.2/SPEC_rdoc.html#label-The+Input+Stream

The external edge limit and compressed-request policy remain separate operational verification
items.
