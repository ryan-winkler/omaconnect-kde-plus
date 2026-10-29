# Omaconnect KDE Plus development

The public display name is Omaconnect KDE Plus. The exact plugin, IPC and private-storage ID is `Omaconnect.plus`. Keep names in runtime metadata neutral; retain author and source attribution in AUTHORS.md, LICENSE and FORK.md.

This is an isolated fork. Develop on the feature branch. Keep upstream history
and MIT attribution. Never modify installed plugins, user shell configuration,
VPN profiles, router state or other projects from this checkout.

The first release implements appearance, aliases, multi-file KDE submission,
truthful operation state, the existing BTH controller view, saved private
addresses, bounded opt-in rediscovery, and explicit Syncthing link metadata/open.
Quick Share, router rosters and inline Syncthing controls remain later releases.

Do not duplicate the separate Banatik/UniFi collector and classification work.
Keep provider identity, route hints and local appearance distinct. No raw
cross-plugin service lookup, secret copy, new protocol daemon or automatic setup.

Use fixed argument arrays, bounded input/output, explicit actions and plain text.
Tests must use owned temporary state and fake services unless an isolated native
test explicitly substitutes all external actions. No real transfer or mode change
is part of automated tests. Run focused checks, then the full suite before commit.

For contributions, start with CONTRIBUTING.md. docs/ICONS.md explains icon
sources, resolver ownership, private storage and the preset parity check.

Every user-facing feature needs concise contextual help or a direct documentation
link. Put it next to its owning control/domain. Use verified fixed official URLs
for external help; local contributor guides can open installed documentation.
Update docs/HELP.md when adding a feature. Keep toolbar action labels, readiness
and ordering in ActionCatalog.js; do not add another hardcoded toolbar branch.

Do not reintroduce privileged dependency/firewall setup launchers. Document prerequisites with supported Omarchy commands. Media retains text/player controls but must not render or fetch a provider-supplied artwork URI. Keep scanner findings and scope visible; no tool result is a security certification.
