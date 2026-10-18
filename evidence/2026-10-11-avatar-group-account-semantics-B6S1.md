# Avatar Group account consumer evidence

HEAD: `804ccf09bd50bc7ea2f9df07070c363bd110eb84`. Application/tests/tasks, local adapters and
unrelated source-policy changes are uncommitted. This is read-only consumer research while the
shared-generation full Rails gate remains running, not a Group migration or acceptance PASS.

`app/services/group_management/create.rb` accepts separate account and owner arguments, requires
account identity to equal the authorized subject identity, and independently requires owner
collective identity. `app/policies/avatar_group_policy.rb` filters both selected account and current
owning collective and checks their permissions separately. The app Avatar controller's
current_persona resolves selected account through ClientPersona. The accepted surface naming ADR
identifies org's Persona implementation as Agent and expressly leaves Avatar authority outside its
own authority cutover. These observations support preserving independent selected account context;
they do not authorize derivation of that identity from the owning organization.

The owning specification and AV-8 now record the evidence without declaring data reconciliation,
concrete account relationships or transfer consequences complete. Historical D-2 options remain
historical, explicitly subordinate to the adopted current decision. Actual persisted ambiguous rows
must still be reported unchanged and held locally rather than guessed.

The first knowledge-checker run failed on the existing specification's prose-suffixed Status line
and absent local AC definitions. Its metadata now uses exact Status: implementing, with AC-1–AC-9
referencing the existing durable AV-1–AV-9 definitions rather than duplicating or weakening them.
The same checker then exited 0 (8 Skills/adapters, 68 documents, 0 evidence records). Oxfmt and git
diff --check exited 0. No runtime Group code or database was changed or tested here.
