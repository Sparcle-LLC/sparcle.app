# Security Policy

## Reporting a vulnerability

**Email <security@sparcle.app>.** One email; we monitor it.

The full policy — scope, what to include, our commitments, and safe harbor for
good-faith research — is published once, canonically, at:

**<https://sparcle.app/trust/vulnerability-disclosure>**

That page is the single source of truth. This file deliberately does **not**
restate it, so the two can never drift apart. Our RFC 9116 contact is published
at <https://sparcle.app/.well-known/security.txt>.

If your finding is sensitive enough to warrant encryption, say so in your first
message and we will reply with our PGP key. We do not require encryption for
first contact — it tends to slow reports down.

## What we commit to

These are the timelines published in the policy above, repeated here only
because they are the part reporters most need up front:

| Stage | Commitment |
|---|---|
| Acknowledgement | within **1 business day** |
| Triage — severity assessed, reproducibility confirmed | within **5 business days** |
| Fix — Critical | **7 days** |
| Fix — High | **30 days** |
| Fix — Medium | **90 days** |
| Fix — Low | next quarterly release |
| Coordinated disclosure | target **90 days** from acknowledgement, extendable by mutual agreement |

Reporters who want credit are credited in release notes and on the policy page,
after the fix ships and customers have had a reasonable upgrade window.

## Please do not

- Open a public GitHub issue for a security report. Email instead.
- Access customer data, customer environments, or any data that is not yours.
  Stop and report immediately if you encounter any.
- Test against a customer's deployment. We cannot accept reports about a
  specific customer's installation — contact that customer directly.

## Supported versions

Bolt and Aeira are distributed as on-device and customer-deployed software.
Security fixes are issued against the **latest released version**. If you are
running an older release, the remedy is to upgrade; we do not backport fixes to
superseded versions.
