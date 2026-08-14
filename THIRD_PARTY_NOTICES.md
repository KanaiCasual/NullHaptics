# Third-party notices

NullHaptics bundles the following third-party components. Their licenses are
reproduced in full at the paths listed below.

## MinHook

- Purpose: inline function hooking (used by the driver to intercept
  `IVRServerDriverHost::PollNextEvent`).
- Version: vendored source under `third_party/minhook/`.
- License: BSD 2-Clause — see `third_party/minhook/LICENSE.txt`.
- Copyright (c) 2009-2017 Tsuda Kageyu and contributors (see
  `third_party/minhook/AUTHORS.txt`).

## OpenVR driver header

- Purpose: SteamVR driver interface definitions (`openvr_driver.h`).
- Source: https://github.com/ValveSoftware/openvr
- License: BSD 3-Clause. The full text is available in the OpenVR repository
  (`LICENSE`). Only the single header `third_party/openvr_driver.h` is vendored.
- Copyright (c) 2015 Valve Corporation.

NullHaptics is not affiliated with, endorsed by, or sponsored by Valve
Corporation. "SteamVR", "Steam", "Valve", and "Index" are trademarks of Valve
Corporation.
