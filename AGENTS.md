# Codex Instructions

This repository is the independently versioned Mist library. Keep its public API and release history independent from Vapor-Deployer.

When cross-repository work is requested, follow the workspace `AGENTS.md`. The consuming Deployer checkout may use this repository through SwiftPM editable mode; do not add a dependency on Deployer here.

Run the relevant Mist tests before reporting implementation work complete. Do not change Vapor-Deployer as an incidental part of a Mist-only task.
