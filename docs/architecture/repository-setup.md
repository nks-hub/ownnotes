# Repository setup

The user created the private repository https://github.com/nks-hub/ownnotes.
It was verified empty on 2026-10-18. The local origin points to that repository.
No source has been uploaded yet.

The GitHub connector commit/file creation operations do not expose author or
committer fields. They must not be used to guess the required identity. Local
Git has no authenticated credential helper; the remote check fails with
authentication required. Do not paste tokens into chat or commit them.

From an authenticated workstation, restore the supplied Git bundle or use this
checkout, then run:

```bash
git config user.name LuRy
git config user.email lury@lury.cz
git config core.hooksPath .githooks
python3 tool/check_git_identity.py
git remote -v
git push -u origin main
```

When restoring from a bundle, set origin to
https://github.com/nks-hub/ownnotes.git first. Do not recreate the repository or
initialize it through GitHub with generated files. Never force-push over existing
content. After upload verify the remote SHA and CI result. A local check does not
constitute a successful remote push or CI run.
