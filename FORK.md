# OmaConnect Plus

This fork starts from Jitendra Dara's OmaConnect 1.5.0 at
`71282d2042b1a1cda1cb1cac84251694eaabb7cb`.

Upstream: https://github.com/jitendradara12/omaconnect
Fork: https://github.com/ryan-winkler/omaconnect
Plugin identity: `ryan.omaconnect`.

The original MIT license and copyright remain in LICENSE. Generic UI fixes can
be proposed upstream separately. Existing KDE Connect owns pairing and protocol
work. An optional existing BTH helper owns VPN policy. This fork adds no UniFi
collector, VPN provisioning service or second Syncthing core.

The first release is a development candidate. Do not enable it alongside the
original UI. Migration is explicit and reversible; development does not require
changing the installed plugin or current network mode.
