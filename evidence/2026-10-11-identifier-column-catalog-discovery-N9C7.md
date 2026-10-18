# Identifier candidate column discovery

HEAD: `946a4f4069dcb52d93c5ca70a1c96a8bfea233a7`. Application/test/task and generated architecture
inventory changes remain uncommitted, with unrelated source-policy and OTP documentation work
preserved. The full Rails Gate 3 recovery process remained live throughout this read-only check.

A temporary Rails runner verified the effective test configurations through DatabaseSafety, visited
the twenty distinct physical catalogs in owned fleet `20261010p3d2`, and queried pg_class,
pg_namespace and pg_attribute inside READ ONLY transactions. It exited 0. It selected public
ordinary/partitioned tables, positive non-dropped columns whose names end with an ID/ref/UUID/JTI,
fingerprint/digest/nonce/verifier/key/challenge/code segment, returning only table/column names,
format_type and attnotnull. It read no row values, PII, proof or secrets and changed no schema/data.

The aggregate was 3,060 candidate columns, including PKs/references, 589 unbounded text/varchar
candidates and 32 native-UUID candidates. Exact public_id matches numbered 238: 183 varchar(21), 52
unbounded varchar, one varchar(255), one varchar(25) and one varchar(16). Exact transaction_id
matches were 22 unbounded varchar; grant_jti and result_jti each had 17. These are discovered
metadata, not classified violations or a completeness verdict. The suffix query does not cover every
possible opaque/protocol name, including otp_generation; some discovered values are valid
external/protocol/secrets/reference/human-code roles and must retain their own contract.

The metadata-only JSON remained under /tmp, SHA256
`281b227f9a3ee7f485c4c277ca4823e6273a6bf27ae57feb5e1c3f9d5c99df52`. No raw catalog dump/log is
committed. Independent acceptance requires fresh semantic producer and consumer classification plus
actual relevant constraint/bulk tests, not these counts alone.

Separate source inspection confirmed Operator's existing public_id normalization strips whitespace
and hyphen/underscore and uppercases its sixteen-character value; its generator is a custom
SecureRandom-alphabet loop. Its retry catches general RecordNotUnique and its preflight loop is
unbounded. These are concrete I-role/collision review targets, not authorization to reinterpret a
human login code, rewrite issued identities or replace credential workflows without consumer proof.
The existing shared-generation AST guard covers named Nanoid calls only and does not detect this
different generation mechanism; complete ID-8 coverage remains open.
