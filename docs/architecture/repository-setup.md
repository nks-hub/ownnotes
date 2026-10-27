# Repository setup

Source lives in the public repository https://github.com/nks-hub/ownnotes.
The first push happened on 2026-10-19 over SSH (`git@github.com:nks-hub/ownnotes.git`)
from a checkout restored from the supplied Git bundle.

The GitHub connector commit/file creation operations do not expose author or
committer fields. Do not use them to create commits. Push from a local checkout
with the required identity:

```bash
git config user.name LuRy
git config user.email lury@lury.cz
git config core.hooksPath .githooks
python3 tool/check_git_identity.py
git push
```

Do not recreate the repository or initialize it through GitHub with generated
files. Never force-push over existing content. After a push verify the remote SHA
and the CI result. A local check does not constitute a successful remote CI run.
