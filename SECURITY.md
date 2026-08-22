# Security policy

The release workflow blocks images with Trivy `HIGH` or `CRITICAL` findings. An exception requires security-owner approval recorded in the release issue, the affected CVE/package, compensating control, and an expiry date. The release owner must remove the exception by rebuilding from an updated pinned base image.

Do not commit credentials, private keys, SAML metadata, database dumps or application configuration. Report vulnerabilities privately through the repository's configured security advisory channel.

For urgent rollback, deploy the preceding known-good GHCR manifest digest; do not move a tag. Revalidate the PHP base digest monthly and after relevant PHP, Debian or Apache CVEs.
