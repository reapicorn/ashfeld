# TODO

## Darkhorn

- [x] Validate the complete provisioning and smoke test.

## Hollowcrown

- [x] Validate Hollowcrown after VM recreation.
- [ ] Add a post-provision smoke test for the API, web UI, and PostgreSQL availability.

## Thorngate

- [x] Validate IVIG workload readiness and HTTPS console availability after provisioning.
- [ ] Validate Thorngate with 12 GiB RAM through a clean provision or `vagrant reload`.
- [ ] Test Thorngate ARM64 on VMware Fusion/Rosetta with the full IVIG deployment.

## Ironhold

- [ ] Add a post-provision smoke test for IIS, the Secret Server HTTP endpoint, and SQL Server availability.
- [ ] Evaluate x86_64 full-system emulation on Apple Silicon for Ironhold; VMware Fusion/Rosetta cannot run its required x86_64 Windows Server guest.
  - [ ] Install QEMU and the `vagrant-qemu` provider on an Apple Silicon Mac.
  - [ ] Obtain Windows Server 2025 x86_64 Evaluation installation media.
  - [ ] Create and configure an x86_64 Windows Server 2025 QEMU VM under emulation.
  - [ ] Install OpenSSH, create the `vagrant` administrator user, and configure WinSSH access.
  - [ ] Package the VM as a QEMU-compatible Vagrant box.
  - [ ] Add a QEMU-specific Ironhold configuration without changing the VMware Desktop path.
  - [ ] Validate SQL Server Express, IIS, the application installer, and the complete Ironhold workflow.
  - [ ] Measure provisioning time and runtime responsiveness under emulation.
