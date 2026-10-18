# OwnNotes mobile candidate

Flutter 3.47.7. Run verification from the repository root with
`bash tool/check_mobile.sh`. See the root README and `docs/acceptance/status.md`
for implemented behavior, remaining gates and actual verification evidence.

Platform credentials and signing material must never be committed. Android and
iOS use `cz.lury.ownnotes.candidate`, isolated from any future production app.
