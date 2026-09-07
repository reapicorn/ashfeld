# Exercise 05 — Audit, Reports, and Alerts

**Estimated time:** 30 minutes  
**Level:** Intermediate

---

## Objective

Understand Secret Server's audit capabilities: access logs, built-in reports, and security alerts for critical events.

---

## Why does auditing matter in PAM?

Secret Server generates an **immutable log** of every action:
- Who accessed which secret and when
- Who viewed, copied, or edited a password
- Failed access attempts
- System configuration changes

This is essential for compliance (PCI-DSS, ISO 27001, SOX) and security incident investigations.

---

## 1. View the audit log for a secret

1. Open any secret (e.g. `dc01 - Administrator`)
2. Click the **Audit** tab
3. Review the history — you should see actions from previous exercises:
   - `VIEW` — when you revealed the password
   - `COPY PASSWORD` — when you copied it
   - `EDIT` — when you modified the secret
   - `CHECK OUT` / `CHECK IN` — if you configured checkout

---

## 2. Global audit log

1. Go to **Admin > Configuration > Log**
2. Filter by:
   - **Event Action:** `View Password`
   - **Date Range:** Last 24 hours
3. How many times were passwords viewed in the last 24 hours?

---

## 3. Built-in reports

Secret Server includes ready-to-use reports.

1. Go to **Reports**
2. Explore the categories:

| Report | What it shows |
|---|---|
| **Secrets Not Accessed** | Secrets no one has accessed in X days |
| **Secret Summary** | All secrets summarized by template |
| **User Audit** | Activity by user |
| **Inactive Users** | Users with no recent activity |
| **Secrets Expiring** | Secrets with passwords about to expire |

### Exercise: run the "User Audit" report
1. Click **User Audit**
2. Filter by user `admin`
3. Export the results to CSV: **Export > CSV**

---

## 4. Configure security alerts

Secret Server can send alerts when critical events occur.

> ⚠️ There is no real SMTP server in the lab, but we'll configure alerts to understand the mechanism.

### Configure the email server (fictitious for the lab)

1. **Admin > Configuration > Email**
2. Fill in:
   - **SMTP Server:** `smtp.lab.local`
   - **Port:** `25`
   - **From Address:** `secretserver@lab.local`
3. **Save** (the test will fail, but the config is saved)

### Create an alert for "multiple failed login attempts"

1. **Admin > Configuration > Event Subscriptions**
2. **Create New Subscription**
3. Configure:
   - **Name:** `Alert - Failed access attempts`
   - **Send Email To:** `admin@lab.local`
   - **Events:**
     - `User Login Failure` ✅
     - `Secret View Failure` ✅
4. **Save**

---

## 5. Simulate and detect an incident

We'll simulate an unauthorized access attempt and trace it in the logs.

1. Open a private/incognito browser window
2. Try to log in to Secret Server with:
   - Username: `admin`
   - Password: `wrongpassword` (3 times)
3. Switch back to the admin session
4. Go to **Admin > Configuration > Log**
5. Filter by **Event Action:** `USER LOGIN FAILURE`
6. Confirm that the failed attempts are logged

---

## 6. Password history

Secret Server keeps the password history for every secret.

1. Open the secret `webserver-01 - root`
2. Click the **History** tab
3. If you ran rotations in the previous exercise, you'll see the previous passwords here
4. You can restore a previous version if needed

---

## ✅ Checklist

- [ ] Reviewed the audit log for at least one secret
- [ ] Ran the "User Audit" report and exported to CSV
- [ ] Configured the failed-attempts alert
- [ ] Simulated and detected an unauthorized login attempt
- [ ] Explored the password history

---

## Reflection questions

1. Which compliance frameworks require this type of audit log?
2. How would you use Secret Server to investigate a security incident?
3. What are the advantages of keeping the audit log inside Secret Server vs. an external SIEM?
4. How would you configure alerts for a customer in production?
5. Why is **password history** important from a forensic standpoint?

---

## Suggested next steps

Once you complete all 5 exercises, you can explore:

- **Discovery** — Automated scanning for unmanaged accounts on the network
- **Launchers** — Launch RDP/SSH sessions directly from Secret Server
- **Session Recording** — Record privileged sessions (requires additional license)
- **REST API** — Automate operations using the Secret Server API
- **Active Directory integration** — AD authentication and user synchronization
- **Secret Server Cloud** — SaaS version of the platform
