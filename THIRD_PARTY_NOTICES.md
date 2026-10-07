# Third-Party Notices

## Current status

At the repository-foundation stage, no third-party source code has been
vendored, copied, or incorporated into the project.

The project may interact with external software, APIs, SDKs, modules, or
services during later features.

When a third-party dependency is introduced, this document must be updated
with, as applicable:

- Component name
- Upstream project or vendor
- Version
- Purpose
- License
- Source
- Required attribution or notices

## Policy

Third-party source code must not be copied into the repository merely
because it is publicly accessible.

Dependencies must be reviewed for licensing and security implications
before being intentionally incorporated into distributable project
material.

Vendor documentation may be referenced for interoperability and
implementation guidance without copying protected documentation into this
repository.

## GitHub Actions dependencies

### actions/checkout

- Component: `actions/checkout`
- Version: `v7.0.1`
- Pinned commit: `3d3c42e5aac5ba805825da76410c181273ba90b1`
- Provider: GitHub
- Purpose: Repository checkout in CI
- License: MIT
- Source: https://github.com/actions/checkout

The action is referenced as an external CI dependency and is not vendored,
copied, or redistributed as project source code.
