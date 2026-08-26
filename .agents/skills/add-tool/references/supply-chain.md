# Supply-chain and failure safety

## Name the trust boundary

A digest proves only that downloaded bytes match the digest source.

- **Same-boundary checksum:** an archive and checksum file fetched from the same release account/CDN detect corruption and accidental mismatch, but not compromise of that release boundary.
- **Repository-pinned digest:** a reviewed digest stored in the repository makes later downloads reproducible. It is a trust anchor only to the extent that reviewers obtained and validated it independently. Updating it automatically from the same release boundary weakens that independence.
- **Signature/attestation:** verification can establish publisher identity or build provenance when the public key/identity, issuer, workflow, and verification policy are pinned independently. A signature is not equivalent to a checksum.

Document which property is provided. Never call a same-boundary checksum an independent attestation.

## Direct artifact contract

1. Require an exact stable version unless policy explicitly permits a channel.
2. Resolve architecture before download and require architecture-specific integrity material.
3. Download to a fresh temporary directory with bounded attempts and bounded backoff.
4. Verify digest/signature before extraction or execution where possible.
5. Reject archives with unexpected paths; extract only the expected binary.
6. Execute the staged binary's version check before replacing the target.
7. Back up the existing target, install to a same-filesystem staged path, and atomically rename.
8. Verify the final target. Restore the backup—or remove a new invalid target—on failure.
9. Clean temporary, staged, and backup files with traps without masking the primary error.

## Partial failures and idempotency

An exact-version guard must compare observable behavior, not merely `command -v`. Validate mandatory policy before skipping so missing digests or unsupported architectures cannot hide behind an existing binary.

Test these states:

- no prior binary;
- exact binary (no network);
- stale binary replaced;
- transient download then success;
- retry exhaustion with old binary intact;
- wrong architecture digest;
- malformed/missing policy;
- extracted version mismatch;
- final verification failure with rollback;
- interruption leaves no target corruption.

For npm tools, pin the package version, use the repository's package manager, inspect global-bin ownership, and explicitly decide whether lifecycle scripts are allowed. For official scripts, download-and-inspect or signature-verify when supported; never pipe an unpinned network response directly to a privileged shell without an explicit accepted policy.

## Coupled updates

Version plus per-architecture repository-pinned digests form one review unit. Signature identity/policy changes are also coupled. Automate only when the updater preserves the intended independent boundary; otherwise keep the update manual and explain the verification procedure.
