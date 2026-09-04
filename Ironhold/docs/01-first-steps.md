# Exercise 01 — First Steps in Secret Server

**Estimated time:** 20 minutes  
**Level:** Beginner

---

## Objective

Get familiar with the Secret Server interface, complete the initial configuration wizard, and understand the basic structure of the platform.

---

## 1. Log in to Secret Server

1. Open your browser and go to: `http://localhost:8080/SecretServer`
2. Log in with the admin credentials:
   - **Username:** `admin`
   - **Password:** `Passw0rd!`

---

## 2. Initial configuration wizard

The first time you log in, Secret Server walks you through a setup wizard. Follow these steps:

### 2.1 Email configuration (skip in the lab)
- Click **Skip** — no SMTP server in this lab

### 2.2 Security settings
- **Require Two Factor for all users:** No (lab only)
- **Force HTTPS:** No (lab only — no certificate)

### 2.3 License
- The lab uses the included evaluation license

---

## 3. Explore the interface

Once inside, take note of the main sections:

| Section | Description |
|---|---|
| **Dashboard** | Overview, recent activity |
| **Secrets** | Where credentials are stored |
| **Admin** | Platform configuration |
| **Reports** | Audit and reporting |

---

## 4. Set up the admin profile

1. Click the username (top right)
2. Select **My Profile**
3. Fill in:
   - Display Name: `Lab Administrator`
   - Email: `admin@lab.local`
4. **Save**

---

## 5. Create a test user

1. Go to **Admin > Users**
2. Click **Create New**
3. Fill in:
   - Username: `consultant01`
   - Display Name: `Consultant 01`
   - Email: `consultant01@lab.local`
   - Password: `Passw0rd!`
4. **Save**

---

## ✅ Checklist

By the end of this exercise you should have:
- [ ] Successfully logged in to Secret Server
- [ ] Completed the setup wizard
- [ ] Created the user `consultant01`
- [ ] Familiarity with basic navigation

---

## Reflection questions

1. What is the difference between a **Secret** and a **Folder** in Secret Server?
2. What is the **Dashboard** used for?
3. When should you enable 2FA in a production environment?
