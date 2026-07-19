## Local build workflow

- Build with `./build.sh` so Debug builds use the stable Apple Development identity and the repo-local `DerivedData` directory.
- After a successful rebuild, quit any currently running FluidVoice instance and launch `DerivedData/Build/Products/Debug/FluidVoice-Debug.app`.
