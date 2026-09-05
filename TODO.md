# TODO

## Site

- [ ] Update the site to make its repository URL clear: `https://reapicorn.github.io/ashfeld/`.
- [ ] Generate project artwork for the site and project documentation.
- [ ] Reorder the project cards and sections as Hollowcrown, Darkhorn, Thorngate, and Ironhold.
- [ ] Reorder the project sections in `README.md` as Hollowcrown, Darkhorn, Thorngate, and Ironhold.

## Hollowcrown

- [ ] Upgrade `vite` to 6.4.3 or later to resolve Dependabot alerts #14, #15, and #16.
- [ ] Upgrade `uuid` to 11.1.1 or later in the Hollowcrown API to resolve Dependabot alert #13.
- [ ] Test Hollowcrown on Apple Silicon with VMware Fusion.
- [x] Validate Hollowcrown after VM recreation.
- [ ] Add a post-provision smoke test for the API, web UI, and PostgreSQL availability.

## Darkhorn

- [ ] Upgrade `uuid` to 11.1.1 or later in all six services to resolve Dependabot alerts #7 through #12.
- [ ] Test Darkhorn on Apple Silicon with VMware Fusion.
- [x] Validate the complete provisioning and smoke test.

## Thorngate

- [ ] Create a `docs/` exercise guide series for Thorngate, following the Ironhold documentation structure.
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
