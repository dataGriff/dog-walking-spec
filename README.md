# Dog walking specs

The spec of record for this domain's services: AsyncAPI, OpenAPI, ODCS
data contracts and Gherkin acceptance criteria — system intent, versioned
and gated. Built on [sysspec](https://github.com/hungovercoders/sysspec).

- `task ci` is the definition of green - the same gates run locally, in the
  pre-commit hook and in CI.
- Gated artifacts are never edited to make an implementation pass. Bump the
  artifact and service versions in `service.yaml` with every change; merges
  to main publish each changed service as a `<service>/v<version>` git tag
  that implementation and consumer repos pin.
- `task mocks:load` stands up Microcks mocks of every service so UIs and
  consumers can build before implementations exist.
- The machinery arrives by reference and stays current via Renovate: the
  `sysspec@` pin in `Taskfile.yml`, the `sysspec-mcp@` pin in
  `.mcp.json` (both npm), and the reusable workflows under `.github/workflows/`.
- Agents get the same specs over MCP (`.mcp.json`) and the deeper
  processes via the sysspec plugin's skills — install with
  `/plugin marketplace add hungovercoders/sysspec` then `/plugin install`,
  and ask to implement or consume a service. The `implement-service` and
  `consume-service` skills carry the whole loop, from contract pin to
  verified definition of done, and read as walkthroughs in their own
  right.

## The system

`specs/system.yaml` describes the whole: a solo dog walker's back office.
Two services make it up, both implemented by
[dog-walking-api](https://github.com/dataGriff/dog-walking-api) and
consumed by [dog-walking-web](https://github.com/dataGriff/dog-walking-web):

- **clients** - the roster: Client and Dog aggregates over HTTP.
- **walks** - the Walk aggregate: scheduling and lifecycle over HTTP,
  `WalkScheduled` / `WalkCompleted` / `WalkCancelled` as CloudEvents, and
  the walk history as an ODCS data contract.

Every operation carries the signed-in walker's bearer token and only ever
sees that walker's records; the specs name the scheme (`bearer_auth`),
the implementation picks the identity provider.
