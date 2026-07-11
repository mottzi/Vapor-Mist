# Unreleased changes main...HEAD(dev)

### Added

**Frontend runtimes are embedded SwiftPM resources**

- Move `mist.js` and `morphdom.js` into the Mist target and declare them with SwiftPM `.embedInCode`, making Mist the only source-controlled authority for both browser runtimes.
- Replace the registry and metadata types with the exhaustive `MistAsset` API. Each asset exposes its filename, JavaScript media type, embedded bytes, and strong SHA-256 ETag directly.
- Add the opt-in `MistAssetRoutes` Vapor convenience API for standard GET/HEAD routing, `If-None-Match` handling, ETags, and `Cache-Control: no-cache`, while retaining direct asset access for consumers with custom response policies.
- Couple the frontend resources to the selected Mist revision and the consuming executable. Consumers no longer copy JavaScript into their own repositories, and statically linked Linux deployments require no companion Mist resource bundle.
- Add resource-contract coverage for both assets and update the existing frontend behavioral test to read the resource from its target-owned location.

### Fixed

**Static streams no longer restore stale content after a local clear**

- **Observed behaviour:** A client-side Clear action could empty a static log stream and correctly show its waiting state, but any subsequent component render—such as toggling the log viewer's Wrap action—restored all previously visible retained logs. Only content arriving after Clear should have remained visible.
- **Aetiology:** Static streams have no model instance ID. Swift's encoded stream message omitted the nil `modelID`, so JavaScript received `undefined`; the same identity reconstructed from the DOM used `getAttribute("mist-id")`, which returns `null` when the attribute is absent. `streamKey` interpolated those values without normalization and therefore registered the same static stream twice: once as `component\0undefined\0stream` and once as `component\0null\0stream`. Clear updated only the DOM-derived `null` entry, leaving the retained server snapshot under the `undefined` entry. When a fragment update caused `restoreStreams()` to run, that stale entry repopulated the stream and overwrote the cleared record.
- **Diagnosis:** The issue was reproduced on the live Deployer log viewer in Safari using the sequence retained logs → Clear → “Waiting for logs…” → Wrap → retained logs reappearing. Safari's Web Inspector confirmed two records for `DeployerLogs/deployer-log`, differing only by `undefined` versus `null` model IDs. The action path was also traced to verify that Wrap did not request another server snapshot; the stale content was restored entirely by the browser registry after DOM reconciliation.
- **Resolution:** Mist now canonicalizes every absent stream model ID to `null` before constructing stream keys or storing stream records. Replace, append, DOM capture, clear, close, and restore operations consequently address one stable record for a static stream, while instance streams remain independently keyed by their model IDs. Clearing a stream now replaces the retained client record with empty content, so later component renders preserve the clear and newly appended text starts from that empty state.
- **Regression coverage:** Frontend tests exercise a retained static-stream replacement followed by Clear and restoration, asserting that the target stays empty and only one buffer record exists. A separate test verifies that model-backed streams remain scoped to distinct model IDs. The full Mist Swift test suite also passes.
- **Deployment verification:** The equivalent client fix was first deployed through Vapor-Deployer's vendored `mist.js` in Deployer commit `26b65a3` and verified successfully on the VPS before promotion into Mist's `dev` branch.
