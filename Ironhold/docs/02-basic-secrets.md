# Exercise 02 — Creating and Managing Secrets

**Estimated time:** 30 minutes  
**Level:** Beginner

---

## Objective

Learn how to create secrets of different types, organize them in folders, and manage their basic lifecycle.

---

## What is a Secret?

In Secret Server, a **Secret** is any credential or sensitive piece of data stored securely:
- Server usernames and passwords
- Database credentials
- SSH keys
- API keys
- Windows service account passwords

Each secret is based on a **Secret Template** that defines which fields it contains.

---

## 1. Create the folder structure

Before creating secrets, set up the organization:

1. Go to **Secrets** (main menu)
2. Click the folder icon **+** → **New Folder**
3. Create the following folders:

```
📁 Lab
   ├── 📁 Linux Servers
   ├── 📁 Windows Servers
   ├── 📁 Databases
   └── 📁 Applications
```

---

## 2. Create a "Unix Account (SSH)" secret

1. Navigate to the **Lab > Linux Servers** folder
2. Click **+ New Secret**
3. Choose the template: **Unix Account (SSH)**
4. Fill in the fields:
   - **Name:** `webserver-01 - root`
   - **Machine:** `192.168.1.10`
   - **Username:** `root`
   - **Password:** Use the password generator (dice icon 🎲)
   - **Notes:** `Development web server`
5. **Save**

---

## 3. Create a "Windows Account" secret

1. Navigate to **Lab > Windows Servers**
2. **+ New Secret** → Template: **Windows Account**
3. Fill in:
   - **Name:** `dc01 - Administrator`
   - **Machine:** `dc01.lab.local`
   - **Username:** `Administrator`
   - **Password:** Generate a new password
4. **Save**

---

## 4. Create a "SQL Server Account" secret

1. Navigate to **Lab > Databases**
2. **+ New Secret** → Template: **SQL Server Account**
3. Fill in:
   - **Name:** `SQL-Prod - sa`
   - **Server:** `sqlserver`
   - **Database:** `SecretServer`
   - **Username:** `sa`
   - **Password:** `Passw0rd!`
4. **Save**

---

## 5. View, copy, and audit a secret

1. Open the secret `webserver-01 - root`
2. Click the **eye** 👁 icon to reveal the password
3. Notice the **Audit** panel — it logged that you viewed the password
4. Click **Copy** to copy the password to the clipboard
5. Check the **Audit** panel again — every action is recorded

---

## 6. Search for secrets

1. Use the search bar at the top
2. Search for `webserver`
3. Try filtering by **Template**, **Folder**, and **Active**

---

## ✅ Checklist

By the end of this exercise you should have:
- [ ] 4 folders created under `Lab/`
- [ ] At least 3 secrets of different types created
- [ ] Understood the audit log for secret access
- [ ] Tested the search functionality

---

## Key concepts

| Concept | Description |
|---|---|
| **Secret Template** | Template that defines the fields for a type of secret |
| **Folder** | Organizational container — also defines inherited permissions |
| **Audit Log** | Immutable record of every action taken on a secret |
| **Password Generator** | Configurable engine for generating strong passwords |

---

## Reflection questions

1. Why is it better to use the **password generator** instead of typing a password manually?
2. What actions get audited when someone accesses a secret?
3. What would happen if we didn't organize secrets into folders?
