# OmaConnect Plus development

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

Subagents own only their assigned files. The parent integrates shared files and
commits after reviewing the changes. Do not overwrite another agent's edits.

For contributions, start with CONTRIBUTING.md. docs/ICONS.md explains icon
sources, resolver ownership, private storage and the preset parity check.
