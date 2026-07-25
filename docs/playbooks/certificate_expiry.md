---
title: Certificate Expiry
description: Certificate Expiry for Inkorporated.
tags: [enterprise]
---

**Scenario:** An SSL/TLS certificate has expired or is about to expire, causing connection failures.

## 1. Symptoms
* Browser warning: "Your connection is not private".
* Internal service errors: `x509: certificate has expired`.
* Alert: "Certificate expires in < 7 days".

## 2. Severity Assessment
* **SEV 1:** Public facing site certificate expired. Users blocked.
* **SEV 2:** Internal service-to-service communication broken.
* **SEV 3:** Expiry approaching (< 1 week).

## 3. Initial Verification
* **Browser:** Check the certificate details in the browser bar.
* **CLI:** `echo | openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -noout -dates`

## 4. Investigation
* Identify where the certificate is terminated (Load Balancer, Nginx, Kubernetes Ingress, CDN).
* Check if auto-renewal (Cert-Manager, LetsEncrypt) failed.

## 5. Mitigation
* **Emergency Renewal:** Manually renew the certificate via the provider (AWS ACM, DigiCert, LetsEncrypt).
* **Upload:** Upload the new cert/key to the Load Balancer or Secret Manager.
* **Restart:** Restart services/ingress controllers to pick up the new cert.

## 6. Resolution
* Fix the auto-renewal automation.
* Add monitoring for certificate expiry (e.g., 30-day warning).

## 7. Escalation
* **Security Team** / **Infrastructure**.
