# Supply-chain and failure safety

## Name the trust boundary

A digest proves only that downloaded bytes match the digest source.

- **Same-boundary checksum:** an archive and checksum file fetched from the same release account/CDN detect corruption and accidental mismatch, but not compromise of that release boundary.
- **Repository-pinned digest:** a reviewed digest stored in the repository makes later downloads reproducible. It is a trust anchor only to the extent that reviewers obtained and validated it independently. Updating it automatically from the same release boundary weakens that independence.
- **Signature/attestation:** verification can establish publisher identity or build provenance when the public key/identity, issuer, workflow, and verification policy are pinned independently. A signature is not equivalent to a checksum.

Document which property is provided. Never call a same-boundary checksum an independent attestation.

## Proportional tiers

Apply each available layer and state what it proves:

1. **Minimum:** establish provenance, use HTTPS, stage downloads, and functionally verify before activation.
2. **Publisher checksum:** verify when the publisher provides one; this detects mismatch but may share the release trust boundary.
3. **Repository-pinned digest:** pin per architecture when reproducibility is required; update it as one review unit with the version.
4. **Signature/attestation:** verify publisher identity or build provenance when supported, with independently pinned identity and policy.

Direct artifacts must resolve architecture and integrity before network access, reject unexpected archive contents, and fail closed on unsupported architectures. Require exact stable versions unless policy explicitly permits a channel.

Back up and restore only when replacing a managed target and a failed replacement could destroy a working installation. New installs and provider/package-manager transactions need mechanism-appropriate cleanup, not ceremonial rollback.

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
