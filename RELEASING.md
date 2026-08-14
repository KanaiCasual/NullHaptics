# Cutting a release

The ready-to-run `NullHaptics-setup.exe` is distributed as a GitHub Release
asset, not committed to the repo.

1. **Build** a clean exe:

   ```powershell
   .\build.ps1
   ```

2. **Smoke-test** it: run `dist\NullHaptics-setup.exe`, click Install, restart
   SteamVR, confirm the log shows
   `NullHaptics: PollNextEvent hooked` (in `Steam\logs\vrserver.txt`), then
   Uninstall.

3. **Tag** the version and push it:

   ```powershell
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. **Publish** on GitHub: *Releases → Draft a new release → choose the tag →*
   attach `dist\NullHaptics-setup.exe` → write notes → **Publish release**.

5. (Recommended) Include the exe's SHA-256 in the release notes so users can
   verify their download:

   ```powershell
   (Get-FileHash dist\NullHaptics-setup.exe -Algorithm SHA256).Hash
   ```

The exe is unsigned, so mention the SmartScreen prompt in the notes (users click
*More info → Run anyway*).
