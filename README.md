# ashfeld

Ashfeld is a decaying industrial city, once known for its foundries and its archives. Today it is a city in transition — its old guilds dissolved, its districts repurposed, its remaining organizations held together by paperwork and habit. Nobody agrees on who is in charge. Nobody agrees on who still works here.

This lab puts you in the city and gives you the keys. The backends are real, the protocols are live, and the data is already there waiting. You are not reading about identity provisioning — you are doing it, against systems that behave the way systems behave in the real world: inconsistently, on their own terms, without a common standard in sight.

```
.
├── darkhorn/        # the district — six companies, six protocols, none of them compatible
├── hollowcrown/     # the bureau — citizen records, the only list anyone agrees to use
├── Ironhold/        # the vault — privileged credentials, locked below the city
└── Thorngate/       # the gate — who gets access, to what, and under what conditions
```

---

## Projects

### darkhorn

Six companies settled in the Darkhorn district after the foundries closed. None of them inherited the same systems. None of them agreed to standardize. They each handle the same three questions — who works here, what do they have access to, are they still active — and they each answer in a different language.

→ See [`darkhorn/README.md`](darkhorn/README.md) — the six companies, their doors, and what moves across the wire.

### hollowcrown

Hollowcrown was the council that governed Ashfeld before it dissolved. The name passed to the bureau that kept its records. Every citizen who was ever hired, transferred, or terminated has an entry here. What the bureau records, the rest of the city is supposed to reflect.

→ See [`hollowcrown/README.md`](hollowcrown/README.md)

### Ironhold

Before the foundries closed, Ironhold was the most secure facility in the district. The guilds kept what they could not afford to lose there. The guilds are gone. The building is still standing. If something has a password that matters, it goes through Ironhold.

→ See [`Ironhold/README.md`](Ironhold/README.md)

### Thorngate

Ashfeld was always a city where nobody agreed on who had access to what. Thorngate was built to answer that question — the gate that decides who gets access, to what, and under what conditions. Not because anyone asked for it, but because the city had become impossible to audit without it.

→ See [`Thorngate/README.md`](Thorngate/README.md)

---

## Prerequisites

Vagrant and a VMware hypervisor are required for all components.

**Install VMware:** [vmware.com/products/desktop-hypervisor](https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion)

| Machine | Hypervisor |
|---|---|
| Windows | VMware Workstation Pro |
| Mac Intel | VMware Fusion |
| Mac Apple Silicon (M1/M2/M3) | VMware Fusion 13+ |
| Linux | VMware Workstation |

**Install Vagrant:** [developer.hashicorp.com/vagrant/downloads](https://developer.hashicorp.com/vagrant/downloads)

**Install the Vagrant VMware plugin (one-time):**

```bash
vagrant plugin install vagrant-vmware-desktop
```

**Install the VMware Utility Service:** [developer.hashicorp.com/vagrant/docs/providers/vmware/vagrant-vmware-utility](https://developer.hashicorp.com/vagrant/docs/providers/vmware/vagrant-vmware-utility)

---

## Clone

```bash
git clone https://github.com/reapicorn/ashfeld ~/ashfeld
```

