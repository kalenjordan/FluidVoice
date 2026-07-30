## Local build workflow

- Never invoke `xcodebuild` directly against the repo-local `DerivedData` directory for any action, including `test-without-building`. Use `./build.sh` for builds and tests so they use the stable Apple Development identity. `test-without-building` still launches FluidVoice as the XCTest host and can affect the running app and privacy permissions.
- Run tests with `./build.sh test`. Add one or more `-only-testing:<test-identifier>` arguments to select specific tests.
- Run experimental or unsigned builds in a separate temporary DerivedData directory so they cannot alter the canonical signed app.
- After a successful rebuild, ensure FluidVoice transitions to the new build. A running instance detects the newer on-disk build and automatically restarts once dictation and processing are idle; wait for and verify that restart instead of terminating it manually. Launch `DerivedData/Build/Products/Debug/FluidVoice-Debug.app` only when FluidVoice is not already running.
- After committing work, push the current branch to our `origin` fork without waiting for separate approval.

## Dictionary operations

- Read and write FluidVoice dictionary entries through the local dictionary API.
- Do not mutate the underlying `UserDefaults` dictionary storage directly.
