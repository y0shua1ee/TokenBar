---
summary: "Krill wallet, subscription quota, and request-cost usage via explicit web login."
read_when:
  - Configuring or debugging the Krill provider
  - Reviewing Krill authentication or request-history behavior
---

# Krill

Krill is disabled by default. Enable it in Settings → Providers, then choose **Log in**. TokenBar opens an ephemeral
WebKit window at `https://www.krill-ai.net/login`; it does not open that window during scheduled refreshes or CLI
fetches. The login result is accepted only from Krill's HTTPS main frame and must contain an unexpired JWT.

The JWT is stored as the Krill provider credential in TokenBar's config. Advanced users may instead provide
`KRILL_JWT` in the environment. Config-projected credentials use a TokenBar-private environment key so they do not
overwrite an ambient `KRILL_JWT` value outside the provider fetch.

TokenBar reads Krill's same-origin account endpoints for:

- wallet balance and Elite credits;
- 尊享月卡 request quota;
- active subscription quota;
- aggregate request, token, cache, and cost history;
- best-effort model breakdowns for the current day.

Cost history honors TokenBar's configured history window, clamped to 1–365 days. A failed optional model breakdown
does not discard otherwise valid totals. Cancellation still stops the whole fetch.

Older TokenBar releases stored this JWT in a Keychain item named `com.tokenbar.krill-jwt`. Migration uses a
non-interactive Keychain query, saves provider config before deleting the old item, and retries later if Keychain
access is unavailable.

Krill does not currently publish a stable public API contract for these dashboard endpoints. TokenBar therefore
keeps the client typed and covered by stubbed response tests, but a server-side schema change may require an update.
