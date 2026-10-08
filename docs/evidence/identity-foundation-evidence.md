# Identity Foundation Evidence

## Purpose

This document defines what Feature 3 evidence may be committed.

## Publishable evidence

Repository evidence may contain:

- synthetic account IDs;
- synthetic aliases;
- neutral display names;
- persona identifiers;
- department identifiers;
- privilege classes;
- neutral security-group names;
- validation outcomes;
- non-identifying counts.

## Local-only evidence

The following remain local:

- tenant domain;
- tenant ID;
- complete live UPNs;
- Graph object IDs;
- temporary passwords;
- authentication tokens;
- recovery addresses;
- screenshots containing personal information;
- raw directory exports.

Local-only data belongs under ignored evidence paths.

## Password evidence

Passwords are never valid portfolio evidence.

Validation proves that an identity was created or authenticated without
recording its credential.

## Screenshot handling

Screenshots intended for publication must be reviewed and sanitized before
being committed.
