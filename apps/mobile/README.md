# OwnNotes mobile app

Flutter 3.47.7. Run verification from the repository root with
`bash tool/check_mobile.sh`. See the root README and `docs/acceptance/status.md`
for implemented behavior, remaining gates and actual verification evidence.

Platform credentials and signing material must never be committed. The app id
is `com.nkshub.nextcloudnotes`; `flutter build apk --android-project-arg=candidate=true`
builds `com.nkshub.nextcloudnotes.candidate` to install beside it.
