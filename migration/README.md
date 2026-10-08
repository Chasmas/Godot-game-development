# New Windows PC

1. Copy `C:/Users/gil_n/.codex/transfers/hotshot-new-pc/hotshot-migration.key` to a USB drive or another private channel. This decrypts the API bundle; never upload it to GitHub or share it publicly.
2. On the new PC download `START-ON-NEW-PC.cmd` and run it. It clones the migration branch, retrieves Git LFS art, extracts the exact existing Blender, installs Python/Node/FFmpeg as needed, extracts the exact existing Godot version, imports the API credentials when you select the private key, and imports the Godot project. GitHub authentication may be required. Allow time and disk space for ~18 GB of source assets plus toolchain and Git LFS cache.
3. Install/sign into Codex, restart it after credential import, open the cloned folder, and paste `RESUME.txt`. Read `RESUME_HANDOFF.md` first. Chat history and MCP connector authorizations cannot be silently recreated by this launcher; reconnect them as needed. Built-in ImageGen uses your signed-in Codex account.

The launcher does not generate a game EXE, trailer, music or charge generation APIs. It does install software and download source files. Winget may request elevation. GitHub LFS storage/bandwidth must be available. Existing Godot executables are transported as software; no new game installer is generated.

Local review candidates, rejected models, prompts and Blender sources are preserved so the agent can distinguish work in progress from approved runtime assets. `.godot` import cache, Python cache, transient exports and old game installer ZIP are excluded and regenerated or intentionally unused.

## Codex permissions

The user authorizes full project access and API use on the new PC. After opening the repository, select Full access in the permissions control beneath the composer. The launcher does not weaken Windows security or copy login tokens. Official instructions: https://learn.chatgpt.com/docs/sandboxing .
