# DIGO v1.9 — Limited Public Beta Launch

**Status:** Public GitHub Pages site is deployed by commits to `main`. v1.9 includes room chat, mini-games, anonymous guest accounts with Cloudflare Turnstile, friend-only DMs, message reports, and a server-checked admin moderation desk.

- Live URL: https://hynprince.github.io/DIGO/
- Community and privacy basics: https://hynprince.github.io/DIGO/community.html
- Source: https://github.com/HYNprince/DIGO

## Launch gate: test using a second non-admin account

This is a **small test release**. Do not promote broadly until these are verified on the live Supabase environment:

- [ ] New guest on a private/incognito browser completes Turnstile and joins without error.
- [ ] MacBook + mobile both enter **DIGO Central**; each sees the other's message within a reasonable time.
- [ ] Only the chosen admin sees the admin shield. A normal account cannot call any `digo_admin_*` RPC (must get access denied).
- [ ] Non-admin sends a test report; admin sees it in the queue. Admin can review, remove reported content, and dismiss.
- [ ] Suspend a **test** user for one hour; their new messages must be rejected. Restore them and check posting works.
- [ ] Friend requests and friend-only DMs work; strangers cannot read a private DM without participating.
- [ ] Delete, edit, reply, clear for me, and restore work across laptop and phone as expected.
- [ ] Safety and privacy page loads from both devices and links back to DIGO.
- [ ] No API service-role key, Turnstile secret, credentials or other non-public tokens appear in GitHub.
- [ ] A human moderator is available to review reports while new people are invited.

## First invite wave (5–10 people maximum)

Send the live link personally to a small circle of trusted testers. Have them join public rooms, test chats/games, and report bugs. Do **not** publicly invite hundreds of strangers yet.

Ask testers three questions:

1. Did you join successfully on your phone? If not, which browser and what happened?
2. Were messages fast and did the games work with another player?
3. What was confusing, unsafe, or missing?

Revisit reports daily during the small beta, including DMs, and keep incident notes without publishing anyone's messages. Never test moderation by harassing real people.

## Known limitations before full public promotion

- Guest accounts cannot be recovered after losing browser/session data. **Use a recoverable login for moderators** before large-scale launch.
- The admin dashboard, suspension policies and friend/DMS authorization need real adversarial security testing. A visible button is not proof that server permissions are safe.
- Moderation is not guaranteed to be immediate; provide a clear owner contact path and an account/data deletion process before promoting widely.
- Private messages are friend-only, **not end-to-end encrypted**. Reported content may be retained as private evidence.
- Platform rules for processing children's data and for operating a public social app in India need review before inviting minors broadly.
- GitHub Pages is primarily intended for static personal/project sites. Review its service limitations and migrate hosting before launching a commercial SaaS.
- Supabase Free and Cloudflare plans have limits; monitor their dashboards before scaling.

## If something goes wrong

- Signups fail → verify Turnstile secret in Supabase Attack Protection and the public site key in DIGO. Avoid sharing secrets or copying them into GitHub.
- Messages stop syncing → check Supabase service status, Realtime channels and client diagnostics; test in the same room on both devices.
- Abuse reports arrive → prioritize safety; review, remove offending content, suspend test/abusive accounts when justified, and document action.
- Security problem → pause new invitations and resolve it before resuming.
- Lost moderator guest session → do not guess UUIDs or grant admin by nickname. A project owner with Supabase administrative access must verify the new account before granting a role.

## Release announcement for a small trusted circle

> 🎮 DIGO beta is open! Join a room, chat with friends and play quick mini-games — no email needed. It's an early test, so please keep it respectful and don't share personal information. Try it on your phone or laptop: https://hynprince.github.io/DIGO/ ✳

This is a **beta**, not a claim of legal compliance, full security testing, or production reliability.
