# Agent instructions

Read [CONTRIBUTING.md](CONTRIBUTING.md) first; it holds the domain map and review rules.

- Keep each change inside one domain and reuse its existing helpers.
- Tests use temporary state and fake providers. Never install or enable plugins,
  restart the shell, send real files, ring devices or change VPN or router state.
- Use fixed argument arrays and bounded input and output. Keep remote text plain.
- Every user-facing feature needs nearby help text or a docs link, and an entry
  in [docs/HELP.md](docs/HELP.md).
- Toolbar actions live only in `ActionCatalog.js`.
- Do not add privileged setup launchers or fetch provider-supplied artwork.
- Keep the plugin ID `Omaconnect.plus` and the upstream attribution in
  [LICENSE](LICENSE) and [AUTHORS.md](AUTHORS.md).
- Run `./scripts/validate.sh` before you commit.
