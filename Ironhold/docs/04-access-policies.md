# Exercise 04 — Access Policies and Checkout

**Estimated time:** 45 minutes  
**Level:** Intermediate–Advanced

---

## Objective

Configure advanced security policies: exclusive secret checkout, approval workflows, automatic password rotation, and time-limited access.

---

## What are Secret Policies?

**Secret Policies** define security behaviors applied to individual secrets or entire folders:

| Feature | Description |
|---|---|
| **Check Out** | Only one user can "hold" the secret at a time — no one else can view it while it's checked out |
| **Approval Workflow** | Viewing a secret requires approval from a designated approver |
| **Auto Change** | Automatic password rotation on a schedule |
| **Hide Launcher Password** | Users can launch a session without seeing the actual password |

---

## 1. Configure Check Out on a secret

**Check Out** prevents two people from using the same account simultaneously.

1. Open the secret `dc01 - Administrator`
2. Click **Edit**
3. Scroll to the **Security** section
4. Enable **Check Out Enabled** ✅
5. **Check Out Interval:** `1 Hour`
6. **Change Password on Check In:** `Yes` (password rotates when the user returns access)
7. **Save**

### Test the checkout

1. Click **Check Out** on the secret
2. The secret is now "held" by your user
3. Open a private browser window, log in as `infra01` (if they have permission) and try to Check Out the same secret
4. What message do you see?

---

## 2. Configure an Approval Workflow

For critical secrets, you can require an approver to authorize access.

1. Open the secret `SQL-Prod - sa`
2. **Edit > Security**
3. Enable **Requires Approval for Access** ✅
4. Under **Approvers**, add the user `admin`
5. **Approval Type:** `Anyone`
6. **Access Duration:** `30 Minutes`
7. **Save**

### Test the workflow

1. Log out and log in as `dba01`
2. Try to view the secret `SQL-Prod - sa`
3. You'll be prompted to enter a justification
4. Enter a justification and submit the request
5. Open another tab with the `admin` user
6. Go to **Admin > Inbox** — you should see the pending request
7. Approve the access
8. Switch back to the `dba01` session — they can now view the secret

---

## 3. Create a Secret Policy and apply it to a folder

Instead of configuring each secret individually, you can create a policy and apply it to an entire folder.

### Create the policy

1. **Admin > Secret Policy > Create New Secret Policy**
2. **Name:** `Critical Servers Policy`
3. Configure:
   - **Check Out Enabled:** `Enforced - Enabled`
   - **Check Out Interval:** `Enforced - 2 Hours`
   - **Hide Launcher Password:** `Enforced - Enabled`
   - **Enable Session Recording:** `Enforced - Enabled` (if module is available)
4. **Save**

### Apply to a folder

1. Navigate to the **Lab > Windows Servers** folder
2. **Edit Folder > Secret Policy**
3. Select `Critical Servers Policy`
4. **Save**

All secrets (new and existing) in that folder will inherit the policy.

---

## 4. Configure Automatic Password Rotation

**Remote Password Changing (RPC)** allows Secret Server to automatically rotate passwords on remote systems.

> ⚠️ In the lab there are no real systems to rotate against, but we'll configure the mechanism to understand how it works.

1. Open the secret `webserver-01 - root`
2. **Edit > Remote Password Changing**
3. Enable **Auto Change Enabled** ✅
4. **Change Schedule:** `Weekly, every Sunday at 2:00 AM`
5. **Next Password:** leave blank to auto-generate
6. **Save**

To see it in action:
- Click **Change Password Now** to force an immediate rotation (it will fail since there's no real server, but you can observe the attempt in the log)

---

## ✅ Checklist

- [ ] Check Out configured and tested on `dc01 - Administrator`
- [ ] Approval Workflow configured and tested on `SQL-Prod - sa`
- [ ] `Critical Servers Policy` created and applied to the folder
- [ ] RPC configured on `webserver-01 - root`

---

## Reflection questions

1. In what real-world scenarios would you use **Check Out**?
2. What is the risk of enabling **Change Password on Check In** if the system doesn't support remote password changes?
3. What is the difference between **Approval Workflow** and **Check Out**?
4. Why is **Hide Launcher Password** useful? What vulnerability does it mitigate?
5. How would you justify automatic password rotation to a customer?
