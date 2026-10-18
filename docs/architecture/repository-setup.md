# Repository setup

Target: nks-hub/ownnotes, private until licensing and distribution decisions are
resolved. The current GitHub connector can write existing repositories but does
not expose repository creation. Its browser fallback requires GitHub sign-in.

From a trusted workstation with GitHub CLI authenticated and organization
creation rights, in the local repository:

```bash
gh repo create nks-hub/ownnotes --private --source . --remote origin --push
```

If the repository has already been created, do not run that creation command:

```bash
git remote add origin https://github.com/nks-hub/ownnotes.git
git push -u origin main
```

Create an empty remote without a generated README/license to preserve the initial
history. Never force-push over existing content. Verify repository owner,
visibility and remote commit after upload. This document does not imply that the
remote has already been created.
