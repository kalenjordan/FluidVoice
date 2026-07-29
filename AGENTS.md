## Local build workflow

- Use `./build.sh` for every command that may build or overwrite Debug app products, including test workflows, so builds use the stable Apple Development identity and the repo-local `DerivedData` directory.
- Never run raw `xcodebuild` with signing disabled against the repo-local `DerivedData`. Run experimental or unsigned builds in a separate temporary DerivedData directory so they cannot alter the canonical signed app.
- After a successful rebuild, leave any running FluidVoice instance untouched. The app detects the newer on-disk build, shows an orange menu-bar indicator, and offers `Restart to Use New Build`. Launch `DerivedData/Build/Products/Debug/FluidVoice-Debug.app` only when FluidVoice is not already running.
- After committing work, push the current branch to our `origin` fork without waiting for separate approval.

## Dictionary operations

- Read and write FluidVoice dictionary entries through the local dictionary API.
- Do not mutate the underlying `UserDefaults` dictionary storage directly.
