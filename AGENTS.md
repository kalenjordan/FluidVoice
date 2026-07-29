## Local build workflow

- Build with `./build.sh` so Debug builds use the stable Apple Development identity and the repo-local `DerivedData` directory.
- After a successful rebuild, leave any running FluidVoice instance untouched. The app detects the newer on-disk build, shows an orange menu-bar indicator, and offers `Restart to Use New Build`. Launch `DerivedData/Build/Products/Debug/FluidVoice-Debug.app` only when FluidVoice is not already running.
- After committing work, push the current branch to our `origin` fork without waiting for separate approval.

## Dictionary operations

- Read and write FluidVoice dictionary entries through the local dictionary API.
- Do not mutate the underlying `UserDefaults` dictionary storage directly.
