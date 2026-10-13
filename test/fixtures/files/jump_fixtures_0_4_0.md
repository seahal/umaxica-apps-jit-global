# Jump 0.4.0 Candidate Fixtures

The JSON fixtures in this directory are unmodified copies retrieved on 2026-10-13 from
`seahal/umaxica-apps-edge-jump` at commit `a92ef1c916464ae41fcc41453fca92f4fa6d2cd9`. The candidate
is unreleased and marked `RELEASE_BLOCKED`; these files are local compatibility baselines, not
evidence of deployment or approval.

| Local file                          | Source path                            | Service version | SHA-256                                                            |
| ----------------------------------- | -------------------------------------- | --------------- | ------------------------------------------------------------------ |
| `jump_receiver_contract_0_4_0.json` | `test/fixtures/receiver-contract.json` | `0.4.0`         | `0db02b9412487931465a81e5e292e7bc6f0ca3eb06a1296e558348772cdadb9a` |
| `jump_production_graph_0_4_0.json`  | `test/fixtures/production-graph.json`  | `0.4.0`         | `3e93ca422c35be5bb034d797ae61ddc9d0befcfd431ba12e3e859a43611588ab` |

The older `jump_receiver_contract.json` remains unchanged. Its recorded provenance is the same
repository at commit `a92ef1c916464ae41fcc41453fca92f4fa6d2cd9`, path
`test/fixtures/receiver-contract.json`, service version `0.3.0`, SHA-256
`7f884dcc348ff61cd94643b4dfbc0c5e27caa21fbf570abed81084b59471339e`; see
`evidence/2026-10-02-rails-receiver-followup-W8T4.md`.
