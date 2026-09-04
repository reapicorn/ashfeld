Before running `vagrant up`, place the Secret Server installer in this folder.

Expected filename (either format works):
  - ThycoticSetup.exe (preferred)
  - SecretServerSetup.exe
  - SecretServer.zip

If both an EXE and ZIP are present, the provisioning script uses the EXE.

HOW TO GET THE INSTALLER
─────────────────────────
The installer is NOT included in this repository.
Obtain it through one of the following channels:

  1. IBM / Delinea partner portal (preferred for licensed customers)
  2. Delinea free trial:
       https://delinea.com/products/secret-server/free-trial
  3. Internal shared drive — ask your team lead for the link

Do NOT download from unofficial sources.

ONCE YOU HAVE IT
─────────────────
Copy the file here:
  installer/ThycoticSetup.exe   (or SecretServer.zip)

Then run:
  vagrant up --provider=vmware_desktop
