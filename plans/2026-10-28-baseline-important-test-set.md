# Baseline important-test-set inventory

- Baseline commit: `b6e7871073bdc43a55fc5f05e8476de8ee71252f`.
- Source of identifiers: `plans/2026-10-28-baseline-failing-tests.md` (from the single baseline run
  recorded in `evidence/2026-10-28-baseline-test-result-Q6N4.md`).
- Purpose: give `two.md` WU-0 the important-set partition that the run summary did not record.
- Scope: bookkeeping over the retained inventory. This is not a new test run, and it does not
  recover identifiers that passed.

## Partition rule

Each failing entry is `Class#test_name`. The class is mapped to the test file that defines it
(repository grep for `^class`), then the file path decides the area by the first matching substring:

| Area | Path substrings |
| --- | --- |
| Authentication | `auth`, `sign`, `ceremony`, `oidc`, `passkey`, `session`, `secret`, `password` |
| Routing | `rout`, `path`, `redirect`, `jump`, `url` |
| Membership | `membership`, `organi`, `company`, `individual` |
| Avatar | `avatar` |
| Preference | `preference` |
| Unassigned | none of the above |

The same rule classifies every `test/**/*_test.rb` file for the file and case counts.

## Counts

| Area | Test files | Approx. test cases | Baseline failing identifiers |
| --- | --- | --- | --- |
| Authentication | 868 | 5,508 | 772 |
| Routing | 72 | 443 | 1 |
| Membership | 37 | 202 | 0 |
| Avatar | 73 | 410 | 3 |
| Preference | 184 | 1,183 | 38 |
| Unassigned | 1,160 | 5,935 | 168 |
| Total | 2,394 | 13,681 | 982 |

981 identifiers are distinct; the inventory contains one duplicated error line. Ten failing classes
(`Auth::App::In::EmailsControllerEnumerationTest`, `Auth::App::In::EmailsControllerSecurityTest`,
`Auth::App::In::MfaPasskeysControllerTest`, `Auth::App::Sign::In::Passkey::AuthenticationFlowTest`,
`Auth::App::Up::CheckpointPasskeysControllerTest`, `Auth::Com::In::EmailsControllerEnumerationTest`,
`Outbound::SmsProviders::AwsSnsTest`, `Security::Invariants::ActorContextInvariantTest`,
`Sign::In::OtpResendServiceTest`, `Webauthn::RelyingPartyConfigTest`) have no `^class` definition
match and count as Unassigned.

## Reproduction

```bash
python3 - <<'PY'
import re, pathlib, subprocess, collections
inv = pathlib.Path('plans/2026-10-28-baseline-failing-tests.md').read_text()
ids = re.findall(r'^- (?:Error|Failure): `([^`]+)`', inv, re.M)
areas = [("authentication", ["auth","sign","ceremony","oidc","passkey","session","secret","password"]),
         ("routing", ["rout","path","redirect","jump","url"]),
         ("membership", ["membership","organi","company","individual"]),
         ("avatar", ["avatar"]), ("preference", ["preference"])]
def area(path):
    low = path.lower()
    for name, keys in areas:
        if any(k in low for k in keys): return name
    return "unassigned"
files = subprocess.run(['grep','-rIl','--include=*.rb','^class ','test'],
                       capture_output=True, text=True).stdout.split()
defs = {}
for f in files:
    for line in open(f, errors='ignore'):
        m = re.match(r'class\s+([A-Za-z0-9_:]+)', line)
        if m: defs.setdefault(m.group(1), f)
print(collections.Counter(area(defs.get(i.split('#')[0], '?')) for i in ids))
PY
```

## Limits

- Path-based areas are an aid, not a claim that a file tests only one area; authentication files
  that exercise routing are counted once, under the first match.
- Case counts are line-based approximations (`test "` and `def test_`), not a Minitest report.
- The baseline run used a checkout with different local configuration and dependencies, so the
  three-figure counts above describe that run, not a clean-environment baseline.
- Deleted or renamed tests after the baseline are not reflected. WU-6 and WU-X2 must diff the
  identifiers again when they close their stages.
