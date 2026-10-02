# Innovate Remote

Innovate's remote-support client, a branded build of RustDesk (AGPL-3.0) pointed at Innovate's own server.

* `innovate/innovate_custom.txt` - the signed settings built into the program (name, server, server key). Signed with Innovate's own key; the matching public verify key is in `src/common.rs`.
* `innovate/make_custom.py` - how that text is made (the private signing key is NOT in this repository).
* `res/` icons and `flutter/windows/runner/Runner.rc` - Innovate logo and Windows version text.
* `.github/workflows/innovate-windows.yml` - builds the Windows installer (push to the `innovate-build` branch, or run it by hand) and publishes it under Releases.

This is a modified version of RustDesk. The source of this program is this repository. RustDesk is (c) Purslane Tech Pte. Ltd., AGPL-3.0.
