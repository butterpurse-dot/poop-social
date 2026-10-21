# iMac (muffins-imac.local) — fleet upgrade plan

**Status: PLANNING → IN PROGRESS. Started 2026-10-20.**

## Why this machine matters

It is the only **x86_64 Mac** in the fleet, and the only machine with a real
Xcode GUI, Simulator.app, and the ability to sign and install to a physical
iPhone. The Linux nodes (ge76, gp66) cannot sideload to iOS at all. So this Mac
is not "spare capacity" — for the poop-social goal it is the *only* path to a
phone install, and it is also the fastest local build box available for the
Xcode work that currently only happens in CI.

## Hardware facts (verified 2026-10-20, `system_profiler`)

| | |
|---|---|
| Model | iMac18,2 (Mid-2017, 21.5" 4K) |
| CPU | Intel i5-7400 @ 3.00GHz — Kaby Lake, family 6 model 158 |
| RAM | 8 GB |
| GPU | **AMD Radeon Pro 555, 2 GB VRAM, Metal 2** (discrete!) |
| Disk | 931 GB SSD, **781 GB free** |
| OS now | macOS 13.7.8 (Ventura, build 22H730) |
| Xcode now | **15.2** (max for Ventura) |
| T2 chip | **none** — removes the biggest OCLP complication |
| FileVault | **Off** — good for OCLP, no unlock friction |
| SIP | enabled (OCLP needs it off; reversible via Recovery) |
| Time Machine | destination configured ("TimeMachine External Passport") but **currently fails to mount** |

## Why the GPU fact changes the earlier "impossible" verdict

I previously wrote off this Mac as hardware-capped. That was **too pessimistic**,
and the reason is the GPU:

* OpenCore Legacy Patcher's dropped-Metal list covers *integrated* Intel graphics
  (Ivy Bridge, Haswell, Broadwell, Skylake).
* This machine has a **discrete AMD Polaris (Radeon Pro 555)** — exactly the class
  OCLP's Metal patches target.
* Combined with **no T2** and **FileVault off**, this is close to a best-case
  OCLP candidate rather than a worst-case one.

So the honest position is: *probably upgradeable*, not *provably impossible*.
That is a different claim and it deserves a real attempt rather than an argument.

## Target

**macOS Sequoia 15.x**, not Tahoe 26.

Reason — Xcode's own compatibility table:

| Xcode | Supported macOS | Ships |
|---|---|---|
| 26.1 and earlier | **Sequoia 15.6** – Tahoe 26.x | iOS 26.1 SDK |
| 26.4.1+ | Tahoe 26.2 – 26.x only | iOS 26.4 SDK |
| 26.6 | Tahoe 26.2 – 26.x only | iOS 26.5 SDK |

So Sequoia 15.6 unlocks **Xcode 26.1** — a genuine Xcode 26, which is what the
App Store toolchain rule requires. Tahoe would unlock 26.6, but Tahoe's OCLP
support is an unfinished release candidate, whereas Sequoia's is mature. Taking
Xcode 26.1 on Sequoia is the *lower-risk path to the same class of toolchain*,
and 26.6 is already proven in CI regardless.

## Risk assessment — LOW

An in-place upgrade is structurally safe here:

* 37 GB home, of which **29 GB is `Library`** (caches/DerivedData) and **3.1 GB
  is `Xcode_15.2.xip`** — both regenerable. No documents, no photos, no DBs.
* Machine is already a fresh install (created Feb 2026).
* 781 GB free — Sequoia needs ~40 GB.

**No irreplaceable data is at risk.** The realistic worst case is re-running the
installer, not data loss.

## The blocker that is NOT technical

The upgrade itself is automated end-to-end *except* for steps that physically
require hands on the machine:

1. **Recovery-mode boot** (hold ⌘R / power-button long-press) to run
   `csrutil disable` — OCLP requires it.
2. Choosing the boot entry in the OCLP picker on first boot.
3. Holding Option at boot if the default entry misbehaves.

Everything else — downloading the installer, building the OCLP EFI, patching
root volume, installing Xcode 26.1 — is scriptable over SSH once the Mac is
reachable (it now is, from both fleet nodes, key-based).

**So the plan is: do all the automatable work, and batch the physical steps into
the smallest possible number of hand-overs.** Not "give up because hands are
needed."

## Access (done)

* ge76 → Mac: **key-based, no password** ✅
* gp66 → Mac: **key-based, no password** ✅
* Address by hostname `muffins-imac.local` (Bonjour/mDNS), never a stale IP.

Fleet key installed into `~/.ssh/authorized_keys` on the Mac from both nodes.

## Work plan

- [x] Verify hardware, free space, backup state, FileVault/SIP
- [x] Establish password-free SSH from both fleet nodes
- [x] Determine the correct target (Sequoia 15.6 → Xcode 26.1)
- [ ] Fetch the Sequoia installer on the Mac (`softwareupdate --fetch-full-installer`)
- [ ] Build the OCLP EFI and stage the installer
- [ ] **HAND-OVER 1**: disable SIP in Recovery (only physical step that must
      happen before the install can proceed)
- [ ] Run the Sequoia install (scriptable once staged)
- [ ] **HAND-OVER 2**: pick the OCLP boot entry on first boot
- [ ] Apply OCLP root patches (GPU acceleration — the Radeon 555)
- [ ] Install Xcode 26.1
- [ ] Point the local build at Xcode 26.1 and re-run the full suite locally
- [ ] Register as a fleet node (fleet-hosts-sync, hostname resolution)
- [ ] Retire the 3.1 GB `Xcode_15.2.xip`

## If it fails

Fallbacks, in order:

1. **Stay on Ventura + keep using CI for Xcode 26.** This already works and is
   proven (two green runs). Nothing about the app is blocked by this — the Mac
   upgrade buys *local* iteration speed and the ability to test on a device, not
   the ability to build a shippable binary.
2. Install Sequoia to an **external SSD** (the "HDD INTERNAL" volume, 931 GB, is
   present and unused) so the internal install is untouched. Fully reversible.
3. Revert to a Ventura snapshot and stop.

Option 1 is the important one: **the app's progress does not depend on this
succeeding.** The upgrade is an optimisation, and treating it as a hard
dependency would be a planning error.
