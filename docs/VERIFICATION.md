# Candidate verification — 29 October 2026

Local full-run result: **124 Python tests passed**, all three JavaScript suites
passed (including 18 BTH/discovery checks), manifest validation and shell syntax
passed. Quickshell 0.3.2 ran the native fixtures. QML lint returned success with
host-import/type diagnostics; this is not a warning-free lint claim. The native
integration fixture passed 31 runtime assertions without TypeError/ReferenceError.
Seven protected installed source/config/helper files retained their starting
hashes. This result applies to the isolated ARM candidate and synthetic providers.

Status: first-release implementation candidate. No installed activation, real
transfer, VPN-mode change or router/UniFi change is part of this receipt.

## Runnable evidence

`./scripts/validate.sh` runs all Python tests, the actual JS model checks, shell
syntax, the installed Omarchy manifest validator and QML lint when available.
The runner uses a temporary HOME/XDG/runtime, no host display and a private session
bus. Optional native prerequisites cause explicit skips; inspect the final test
summary before making a claim. CI runs this same command and has no native Omarchy
runtime by default.

Focused suites cover:

- Portal multiselect/cancel over private D-Bus, inspected real temporary regular
  files and unsupported/folder/FIFO/changed/oversized sources.
- Actual transfer JS/controller functions and fake CLI accepted, failed,
  ambiguous timeout and after-invocation cancellation outcomes.
- Appearance storage, stable identity, alias validation, concurrent writes,
  corrupt-state preservation, image import/rejection and Syncthing link metadata.
- BTH strict status, fixed commands, unsafe/unknown/missing cases, intent versus
  actual state and helper-path drift.
- Private address validation, baseline preservation, merge/readback conflicts,
  four concurrent writers, real busctl against private fake KDE and native
  queue/close-disable behavior with owned helpers.
- Native/ryan.bar/tray migration, icon semantics, private staging and rollback
  conflicts that preserve unrelated later edits.
- Native QML component/control integration: actual Service, BarWidget, Panel,
  facade bridge, tabs, chooser Apply/Cancel/reload, aliases, portal review,
  explicit Send, fixed recipient, sequential requests, delivery-unknown activity,
  cancellation and unconfirmed owner-panel opening. See [native QA details](../tests/NATIVE-QA.md).

## Platform limitation

Qt offscreen has no native Quickshell PanelWindow backend. The integration fixture
substitutes only the KeyboardPanel hosting boundary. Actual product components and
UI logic run unchanged in that fixture. It asserts no TypeError/ReferenceError or
configuration-load error. It is not a mapped desktop screenshot or an end-to-end
keyboard/assistive-technology test.

A separate CPU-only headless Hyprland attempt could not start a Wayland socket.
The isolated compositor reported backend creation failure; a mandatory-headless
Aquamarine probe reported no allocator. No host display/GPU or installed settings
were used to bypass this limit.

## Open acceptance gates

| Gate | Status |
| --- | --- |
| ARM native helper/model/UI logic fixtures | Run by the documented local validation command |
| Genuine PanelWindow mapping and compositor focus | Blocked by isolated compositor prerequisite |
| Native and replacement-bar activation | Not run; installed desktop preserved |
| x86_64 native UI | Not run |
| Linux/Android physical payload and zero-byte delivery | Not run |
| Offsite BTH and phone-away / desktop-LAN pairing | Not run |
| Scale 2, RTL, reduced motion and assistive technology | Not accepted; basic names/plain text/focus controls implemented |
| Release publication | Not performed |

A successful CLI request does not close the delivery gate. A successful helper
status does not prove a VPN handshake, service reachability or fleet acceptance.
