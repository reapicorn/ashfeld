# Exercise 03 — Groups, Users, and Roles

**Estimated time:** 30 minutes  
**Level:** Intermediate

---

## Objective

Understand Secret Server's security model: roles, groups, and permissions on folders and secrets.

---

## Secret Server permission model

```
Role
  └─ Defines WHAT the user can do in the platform
     (manage users, view reports, create secrets, etc.)

Group
  └─ Aggregates users — permissions are granted to groups on Folders/Secrets

Folder/Secret Permission
  └─ Defines the access level: View | Edit | Owner
```

**Roles** control system-level features.  
**Folder permissions** control which secrets each group can see.

---

## 1. Explore existing Roles

1. Go to **Admin > Roles**
2. Review the built-in roles:

| Role | Description |
|---|---|
| **Administrator** | Full access to the system |
| **User** | Basic access — only sees what is shared with them |
| **Read Only** | Read-only access to shared secrets |

---

## 2. Create groups for the lab

1. Go to **Admin > Groups**
2. Click **Create New**

Create the following groups:

### Group: `Infrastructure`
- **Name:** `Infrastructure`
- **Active:** checked
- **Roles:** `User`
- **Save**

### Group: `DBAs`
- **Name:** `DBAs`
- **Roles:** `User`
- **Save**

### Group: `Security`
- **Name:** `Security`
- **Roles:** `User`
- **Save**

---

## 3. Create users and assign them to groups

### User: `infra01`
1. **Admin > Users > Create New**
2. Username: `infra01` / Display: `Infrastructure 01`
3. Password: `Passw0rd!`
4. Under **Groups**: add `Infrastructure`
5. **Save**

### User: `dba01`
1. Username: `dba01` / Display: `DBA 01`
2. Password: `Passw0rd!`
3. Group: `DBAs`
4. **Save**

---

## 4. Assign folder permissions

Now give each group access only to its corresponding folder.

### Permissions for `Infrastructure`

1. Navigate to the **Lab > Linux Servers** folder
2. Click the settings icon ⚙️ → **Edit Folder**
3. Under **Permissions**:
   - Disable parent inheritance: **Disable Inherit Permissions**
   - Click **Add Permission**
   - Search for the `Infrastructure` group
   - Permission level: **View**
4. Repeat for the **Lab > Windows Servers** folder
5. **Save**

### Permissions for `DBAs`

1. Folder **Lab > Databases**
2. Disable inherit → Add Permission
3. Group `DBAs` → permission **Edit**
4. **Save**

---

## 5. Verify permissions

1. Open a private/incognito browser window
2. Log in as `infra01`
3. Navigate to `Lab > Linux Servers`
   - Can they see the secrets?
4. Try accessing `Lab > Databases`
   - What happens?
5. Close the private window and log in as `dba01`
   - Can they edit secrets in `Databases`?
   - Can they see `Linux Servers`?

---

## ✅ Checklist

- [ ] 3 groups created (`Infrastructure`, `DBAs`, `Security`)
- [ ] 2 users created and assigned to their groups
- [ ] Folder permissions correctly configured
- [ ] Verified that each user only sees what they should

---

## Reflection questions

1. What is the difference between **View** and **Edit** permission on a folder?
2. What is **permission inheritance** and when should you disable it?
3. If a user belongs to two groups with different permissions on the same secret, what takes precedence?
4. How would you model permissions for a company with Linux, Windows, DBA, and security teams?
