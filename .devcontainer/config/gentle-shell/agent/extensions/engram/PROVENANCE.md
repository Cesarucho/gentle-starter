# Engram Pi runtime adapter

Runtime-only upstream adapter from Gentleman-Programming/engram v3.0.0,
commit `15a2f78885d7ad8ced23b2d1d88383e9bb472c17`, `plugin/pi` version 0.2.0.
Files are copied unchanged from the public immutable source. See `LICENSE` and
`SHA256SUMS`. No binary, initializer, credentials, or database is included.

The adapter uses the existing installed Engram CLI and its existing storage.
Do not run `pi-engram init` or install a second Engram distribution.

The annotated v3.0.0 tag object
`fcf2eb5b6fe445c19a2e5568612a0a421f0fd5e1` resolves to this commit. Runtime
files and the root license match immutable raw commit URLs byte-for-byte;
`plugin/pi/package.json` identifies `gentle-engram` 0.2.0. The tag is unsigned;
same-publisher hashes are integrity evidence, not independent attestation.

This adapter sends the required `expected_project` on observation updates and
deletes. It also uses acknowledged core resume registration, capability-checked
cross-project satellite sessions, and no longer imports a cloned manifest on
startup. Its server launch opts into cloud autosync when existing Engram cloud
configuration permits it; no credentials or cloud configuration are seeded here.
