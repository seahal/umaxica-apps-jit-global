# rails-serializers: per-definition ledger

9 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/serializers/health_status_serializer_test.rb`

[test/serializers/health_status_serializer_test.rb](../../../test/serializers/health_status_serializer_test.rb); SHA-256: `6bf2354e8df619c07d7a97af3348c389e0263a6c36633132dbea97dbdfefd4ed`.

File-level implementation candidates (including setup/import context): [app/serializers/health_status_serializer.rb:17](../../../app/serializers/health_status_serializer.rb#L17); [app/services/health.rb:6](../../../app/services/health.rb#L6).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-10961"></a>T-10961 / [14](../../../test/serializers/health_status_serializer_test.rb#L14) | "all probes ok is status pass and HTTP 200"<br>Owner: `HealthStatusSerializerTest` | `assert_equal(`; `assert_equal 200, serialized.http_status` | [HealthStatusSerializer](../../../app/serializers/health_status_serializer.rb#L17) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-10962"></a>T-10962 / [33](../../../test/serializers/health_status_serializer_test.rb#L33) | "an unready readiness is fail overall and HTTP 503, and does not change liveness"<br>Owner: `HealthStatusSerializerTest` | `assert_equal "fail", serialized.body.fetch(:status)`; `assert_equal "fail", serialized.body.dig(:checks, :readiness, :status)`; `assert_equal "pass", serialized.body.dig(:checks, :liveness, :status)`; +1 further assertion lines | [HealthStatusSerializer](../../../app/serializers/health_status_serializer.rb#L17) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-10963"></a>T-10963 / [48](../../../test/serializers/health_status_serializer_test.rb#L48) | "degraded but acceptable is warn overall and still HTTP 200"<br>Owner: `HealthStatusSerializerTest` | `assert_equal "warn", serialized.body.fetch(:status)`; `assert_equal "warn", serialized.body.dig(:checks, :readiness, :status)`; `assert_equal 200, serialized.http_status` | [HealthStatusSerializer](../../../app/serializers/health_status_serializer.rb#L17) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-10964"></a>T-10964 / [62](../../../test/serializers/health_status_serializer_test.rb#L62) | "a starting process warns on liveness but fails on startup"<br>Owner: `HealthStatusSerializerTest` | `assert_equal "warn", liveness_starting.body.dig(:checks, :liveness, :status)`; `assert_equal "warn", liveness_starting.body.fetch(:status)`; `assert_equal 200, liveness_starting.http_status`; +3 further assertion lines | [HealthStatusSerializer](../../../app/serializers/health_status_serializer.rb#L17) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-10965"></a>T-10965 / [88](../../../test/serializers/health_status_serializer_test.rb#L88) | "checks are emitted in startup, liveness, readiness order"<br>Owner: `HealthStatusSerializerTest` | `assert_equal %i(startup liveness readiness), serialized.body.fetch(:checks).keys` | [HealthStatusSerializer](../../../app/serializers/health_status_serializer.rb#L17) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/serializers/oidc_user_info_response_serializer_coverage_test.rb`

[test/serializers/oidc_user_info_response_serializer_coverage_test.rb](../../../test/serializers/oidc_user_info_response_serializer_coverage_test.rb); SHA-256: `5ecf43c79477c89c131131b20dc24dd9fc33c532495fde09791fc573a606e83e`.

File-level implementation candidates (including setup/import context): [app/serializers/oidc_user_info_response_serializer.rb:4](../../../app/serializers/oidc_user_info_response_serializer.rb#L4); [app/values/oidc_subject.rb:4](../../../app/values/oidc_subject.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-10966"></a>T-10966 / [8](../../../test/serializers/oidc_user_info_response_serializer_coverage_test.rb#L8) | "build returns profile claims when the resource exposes them"<br>Owner: `OidcUserInfoResponseSerializerCoverageTest` | `assert_equal "Ada Lovelace", claims[:name]`; `assert_equal "ada@example.test", claims[:email]`; `assert claims[:email_verified]`; +1 further assertion lines | [OidcUserInfoResponseSerializer](../../../app/serializers/oidc_user_info_response_serializer.rb#L4); [OidcSubject](../../../app/values/oidc_subject.rb#L4) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-10967"></a>T-10967 / [22](../../../test/serializers/oidc_user_info_response_serializer_coverage_test.rb#L22) | "build omits profile claims when the resource does not expose them"<br>Owner: `OidcUserInfoResponseSerializerCoverageTest` | `assert_equal "acr", claims[:acr]`; `assert_equal OidcSubject.for(resource, resource_type: "visitor"), claims[:sub]`; `assert_not claims.key?(:name)`; +2 further assertion lines | [OidcUserInfoResponseSerializer](../../../app/serializers/oidc_user_info_response_serializer.rb#L4); [OidcSubject](../../../app/values/oidc_subject.rb#L4) | S: static inventory; individual semantic review open | coverage-named |
| <a id="t-10968"></a>T-10968 / [37](../../../test/serializers/oidc_user_info_response_serializer_coverage_test.rb#L37) | "build scopes profile and email claims independently"<br>Owner: `OidcUserInfoResponseSerializerCoverageTest` | `assert_equal "Grace Hopper", profile_claims[:name]`; `assert_not profile_claims.key?(:email)`; `assert_not profile_claims.key?(:email_verified)`; +3 further assertion lines | [OidcUserInfoResponseSerializer](../../../app/serializers/oidc_user_info_response_serializer.rb#L4) | S: static inventory; individual semantic review open | coverage-named |

## `test/serializers/webauthn_options_serializer_test.rb`

[test/serializers/webauthn_options_serializer_test.rb](../../../test/serializers/webauthn_options_serializer_test.rb); SHA-256: `c6269398ec19a3b4c05ded3faa95db9f214387db6204c8cd33006ee42b6a195a`.

File-level implementation candidates (including setup/import context): [app/serializers/webauthn/options_serializer.rb:10](../../../app/serializers/webauthn/options_serializer.rb#L10).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-10969"></a>T-10969 / [6](../../../test/serializers/webauthn_options_serializer_test.rb#L6) | "normalizes hash user ids and snake case credential lists"<br>Owner: `WebauthnOptionsSerializerTest` | `assert_equal Base64.urlsafe_encode64("user-id", padding: false), serialized.dig("user", "id")`; `assert_equal "credential-id", serialized.dig("allow_credentials", 0, "id")`; `assert_equal "public-key", serialized.dig("allow_credentials", 0, "type")` | [Webauthn::OptionsSerializer](../../../app/serializers/webauthn/options_serializer.rb#L10) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
