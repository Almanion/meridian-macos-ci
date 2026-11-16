# Meridian native macOS build recipe

This repository contains the public build automation associated with the
Meridian desktop game. The game sources, artwork, models and engine remain in
the owner's private source repository or the licensed engine download service.

The workflow uses only the standard `macos-15-intel` GitHub-hosted runner.
GitHub documents standard runners in public repositories as free. Both jobs
refuse to run when the workflow repository is private. There are no push,
pull-request, scheduled or external event triggers: an owner must dispatch
each preflight or build manually.
The `core` mode compiles and runs the existing rules and economy test suites
with native Apple Clang without downloading Unreal Engine.

The private source checkout uses a deploy key limited to read access on that
one source repository. Personal GitHub credentials and Epic account sessions
are not exported. The engine descriptor contains only licensed Mac-engine
download metadata, not an account access token or refresh token.

Detailed game build logs are redirected to local runner files. The installer,
verification report and diagnostic logs are packaged together and encrypted
with OpenSSL CMS using AES-256-GCM and an RSA-OAEP recipient certificate before
artifact upload. Only the encrypted bundle is uploaded. The decryption key
remains on the owner's computer and is absent from this repository and CI.

`recipient.crt` is the public encryption certificate. It grants no account or
repository access and is not an Apple signing certificate. Developer ID and
notarization are separate from artifact encryption and are not configured.

The source snapshot must include the native build and verification helpers.
Passing preflight does not prove that the game builds. Passing a NullRHI smoke
check does not prove Metal rendering, Apple Silicon execution or physical LAN
acceptance. Those checks must be reported separately.

See GitHub's documented runner terms and configurations:
https://docs.github.com/en/actions/reference/runners/github-hosted-runners
