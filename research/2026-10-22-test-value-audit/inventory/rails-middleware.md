# rails-middleware: per-definition ledger

9 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/middleware/request_body_size_limit_test.rb`

[test/middleware/request_body_size_limit_test.rb](../../../test/middleware/request_body_size_limit_test.rb); SHA-256: `ac1d01813fb4629c96dedddcfb4edac76f92559668275f1cc8dfac9e376d8ac8`.

File-level implementation candidates (including setup/import context): [lib/request_body_size_limit.rb:13](../../../lib/request_body_size_limit.rb#L13).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-05439"></a>T-05439 / [7](../../../test/middleware/request_body_size_limit_test.rb#L7) | "allows a JSON body at the configured boundary and preserves it for Rails"<br>Owner: `RequestBodySizeLimitTest` | `assert_equal 200, status`; `assert_equal body, received` | [RequestBodySizeLimit](../../../lib/request_body_size_limit.rb#L13) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-05440"></a>T-05440 / [22](../../../test/middleware/request_body_size_limit_test.rb#L22) | "rejects a JSON body above the boundary before the downstream app reads it"<br>Owner: `RequestBodySizeLimitTest` | `assert_equal 413, status`; `assert_equal "application/problem+json", headers.fetch("Content-Type")`; `assert_not called` | [RequestBodySizeLimit](../../../lib/request_body_size_limit.rb#L13) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-05441"></a>T-05441 / [38](../../../test/middleware/request_body_size_limit_test.rb#L38) | "rejects a chunked JSON body above the boundary without trusting Content-Length"<br>Owner: `RequestBodySizeLimitTest` | `assert_equal 413, status`; `assert_not called` | [RequestBodySizeLimit](../../../lib/request_body_size_limit.rb#L13) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-05442"></a>T-05442 / [55](../../../test/middleware/request_body_size_limit_test.rb#L55) | "rejects compressed JSON rather than applying the limit to an unsupported encoding"<br>Owner: `RequestBodySizeLimitTest` | `assert_equal 415, status`; `assert_not called` | [RequestBodySizeLimit](../../../lib/request_body_size_limit.rb#L13) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-05443"></a>T-05443 / [71](../../../test/middleware/request_body_size_limit_test.rb#L71) | "rejects a malformed JSON Content-Length before reading the body"<br>Owner: `RequestBodySizeLimitTest` | `assert_equal 400, status`; `assert_not called` | [RequestBodySizeLimit](../../../lib/request_body_size_limit.rb#L13) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-05444"></a>T-05444 / [87](../../../test/middleware/request_body_size_limit_test.rb#L87) | "rejects a negative JSON Content-Length before reading the body"<br>Owner: `RequestBodySizeLimitTest` | `assert_equal 400, status`; `assert_not called` | [RequestBodySizeLimit](../../../lib/request_body_size_limit.rb#L13) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/middleware/trusted_forwarded_headers_test.rb`

[test/middleware/trusted_forwarded_headers_test.rb](../../../test/middleware/trusted_forwarded_headers_test.rb); SHA-256: `fe361f94b85d7ca285dbf1cf84637dee348c4b79e0b8ad81ba805a0810bb3cf7`.

File-level implementation candidates (including setup/import context): [lib/trusted_forwarded_headers.rb:4](../../../lib/trusted_forwarded_headers.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-05445"></a>T-05445 / [7](../../../test/middleware/trusted_forwarded_headers_test.rb#L7) | "removes forwarding headers supplied by an untrusted direct peer"<br>Owner: `TrustedForwardedHeadersTest` | `assert_equal ["missing"], body`; `assert_not env.key?("HTTP_FORWARDED")` | [TrustedForwardedHeaders](../../../lib/trusted_forwarded_headers.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-05446"></a>T-05446 / [23](../../../test/middleware/trusted_forwarded_headers_test.rb#L23) | "preserves forwarding headers supplied by a trusted proxy"<br>Owner: `TrustedForwardedHeadersTest` | `assert_equal ["203.0.113.99"], body` | [TrustedForwardedHeaders](../../../lib/trusted_forwarded_headers.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-05447"></a>T-05447 / [40](../../../test/middleware/trusted_forwarded_headers_test.rb#L40) | "a peer address that cannot be parsed is untrusted and its forwarding headers are stripped"<br>Owner: `TrustedForwardedHeadersTest` | `assert_equal ["missing"], body, "#{peer.inspect} must not be treated as a trusted proxy"`; `assert_not env.key?("HTTP_CF_CONNECTING_IP")` | [TrustedForwardedHeaders](../../../lib/trusted_forwarded_headers.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
