## Local build workflow

- Build with `./build.sh` so Debug builds use the stable Apple Development identity and the repo-local `DerivedData` directory.
- After a successful rebuild, quit any currently running FluidVoice instance and launch `DerivedData/Build/Products/Debug/FluidVoice-Debug.app`.
- After committing work, push the current branch to our `origin` fork without waiting for separate approval.

## Dictionary operations

- Read and write FluidVoice dictionary entries through the local dictionary API.
- Do not mutate the underlying `UserDefaults` dictionary storage directly.
