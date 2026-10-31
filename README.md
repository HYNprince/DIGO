# DIGO v1.6 🎲

DIGO is a chat-first social mini-game **demo** with a colorful DropMesh-inspired interface.

## What works in the demo
- Color-based nickname ID tags and guest identities
- Chat rooms, reactions, and emotes
- Friend requests and mutual-friend direct messages in local demo mode
- Emoji Guess, Would You Rather, Trivia Clash, and Word Rush
- Room customization, leaderboards, and mobile/desktop responsive layout

## Live website
When GitHub Pages is enabled, the site is available at:
https://hynprince.github.io/DIGO/

## Important: this is NOT a real multiplayer service yet
Each visitor gets a local demo in their own browser. Demo identities/messages are not shared across devices. Do not invite strangers expecting shared real-time chat.

Future real online multiplayer requires a separately configured backend, tests for room permissions and moderation, and safeguards against abuse.

## Safety
No secret or server-side credentials should ever be included in this public repository.


## DIGO v1.7 — message controls (requires a SQL migration)

New controls in the chat room:

- **Delete**: delete your own message for everyone by replacing its content with a deleted marker. Deleted messages cannot be edited or replied to.
- **Clear for me**: hide older room messages on your current browser only. **Restore view** undoes the local hiding; nothing is removed from Supabase.
- **Edit**: edit your own message; the label shows that it was edited.
- **Reply**: quote an existing room message with a real `reply_to` relationship; if the original is deleted the quote shows a deleted marker.
- **Copy** a message to the clipboard.
- **Unread indicators**: check recent messages in other rooms every 12 seconds while DIGO is open; the indicator resets when you enter a room. The poll is limited to recent rows and is a beta convenience, not a guaranteed full-history unread count.

### IMPORTANT: Run this once for the existing Supabase database

1. Open [DIGO v1.7 SQL migration](supabase/DIGO-v1.7-Message-Controls.sql) on GitHub. Click **Raw**, then copy all its contents.
2. In the **DIGO** Supabase project, open **SQL Editor → New query**.
3. Paste and review the SQL. Ensure the selected project is DIGO (not another project).
4. Click **Run** exactly once. A success message like *Success. No rows returned* indicates the SQL executed successfully.
5. Reload [DIGO](https://hynprince.github.io/DIGO/?v=1.7) on your laptop and phone, then test sending, deleting, editing, and replying in the same room.

**Until the migration runs**, delete/edit/reply operations may show a database error. Basic chat works as before. Do not rerun the full v1.6 setup. Room deletion and deleting other people's messages are intentionally not offered to normal users. Reported-message snapshots are stored privately for moderation review, while deleted message content is replaced in the public chat.

DIGO is still an early public beta. Keep testing with trusted people until anonymous-signup protection, abuse moderation, and database access policies have been independently verified.

## DIGO v1.8 — Cloudflare Turnstile protection

The public **Site Key** is embedded in `index.html`. No private Turnstile Secret Key should ever be checked into GitHub.

To finish activation:

1. Check the sign-in widget renders on `https://hynprince.github.io/DIGO/` in a private/incognito window. Disable content blockers for the site if the widget cannot load.
2. In **Supabase → DIGO → Authentication → Attack Protection** (sometimes displayed as Bot and Abuse Protection), enable CAPTCHA with **Cloudflare Turnstile**.
3. Copy the **Secret Key directly from Cloudflare Turnstile** into the Supabase CAPTCHA Secret Key setting; **never** paste the secret into DIGO source code, GitHub or chat.
4. Save the Supabase setting, then test *new anonymous signup* in a fresh private window on a phone and laptop. Existing anonymous user sessions will not require a new CAPTCHA token for returning to their current session.
5. If signup fails, turn off CAPTCHA temporarily in Supabase while fixing the frontend/provider mismatch; do not remove or publish the private key.

The site uses explicit Turnstile rendering for dynamically generated onboarding, refreshes expired/used tokens and passes `captchaToken` only to `signInAnonymously`. This reduces automated anonymous signups but does not replace moderation, rate limits or database access policies.

## DIGO v1.9: moderation + friend-request alerts

Frontend code is committed, but the admin panel stays hidden until the SQL migration and your admin identity are configured.

### Activate moderation on the existing DIGO Supabase project

1. Open [DIGO v1.9 moderation migration](supabase/DIGO-v1.9-Moderation.sql) on GitHub and select **Raw**.
2. Copy the complete SQL script into **Supabase → DIGO → SQL Editor → New query**. Verify the project, review the script, then run it **once**. Do not rerun v1.6 or v1.7 migrations.
3. Choose the exact DIGO account that should own moderation. On the same browser where that account is signed in, note the nickname, then find its UUID under **Supabase Authentication → Users**. A unique UID matters: two users can share a nickname.
4. Using the SQL Editor, manually run the following, replacing the placeholder with the specific, verified Auth user UUID:

```sql
insert into digo_private.admins(user_id)
values ('YOUR-VERIFIED-AUTH-USER-UUID'::uuid)
on conflict (user_id) do nothing;
```

5. Refresh DIGO in the same browser. A yellow **🛡 Admin moderation** link should appear. Normal accounts must never see it.
6. Using two non-admin test accounts, report a message. Verify the admin can review and optionally redact reported content, suspend a test sender, and restore that sender.
7. Verify a suspended test account cannot post or start games. A suspension prevents writes; it is not a server-side sign-out.

**Security:** The admin role and suspension data are stored in a non-exposed schema. All privileged operations check the caller's authenticated UUID on the database. No service-role key or admin UUID is hardcoded into the website. Report contents are visible only to admins through narrowly scoped functions, and only reported private DMs are exposed.

**Limitations:** This is a limited beta moderation tool, not a fully tested public trust-and-safety operation. Before a broad launch, test RLS and RPC authorization with admin and ordinary accounts, add a permanent recoverable admin sign-in (anonymous guest sessions can be lost), document reporting and appeals, and arrange timely moderator review. Test the SQL on a separate/staging project before running it against important real data.

**Friend alerts:** Pending friend requests now show an unread-count badge after a periodic refresh while DIGO is open, without external push notifications. Live chat and mini-games continue working as before.


## 🚀 DIGO v1.9 — Limited Public Beta

**[Open DIGO](https://hynprince.github.io/DIGO/)** · **[Community rules & privacy basics](community.html)** · **[Beta launch checklist](BETA-LAUNCH.md)**

The beta is open for small-scale testing. Anonymous guest login uses Cloudflare Turnstile, rooms use Supabase Realtime, and a server-checked moderation desk handles reported content. **This is not a fully audited, large-scale public launch.** Before promoting widely, complete the live security/reporting tests in the checklist, establish recoverable moderator access, and provide an account/data deletion contact path.

## DIGO v2.0 — Private-room WebRTC Voice Beta

**Voice is an opt-in beta feature for INVITE-ONLY PRIVATE rooms, not DIGO's public chat rooms.**

To activate on the existing DIGO Supabase project:

1. Open [DIGO v2.0 Voice SQL](supabase/DIGO-v2.0-Voice.sql) on GitHub and select **Raw**.
2. Paste the SQL into **Supabase → DIGO → SQL Editor → New Query** and run it once, **after v1.9**. Do **not** rerun old setup scripts. This adds authorization policies for the private `voice:<room_uuid>` Realtime signaling topics, not any voice recordings or databases.
3. Open **https://digo.vercel.app/** and hard refresh. Ensure Cloudflare Turnstile permits the Vercel hostname.
4. Sign into separate test accounts on a MacBook and phone. Create a **private room** on one device and share its invite link with the other.
5. Both enter the **same private room** and press **JOIN VOICE**, granting microphone permission on each device. Use headphones to avoid feedback.
6. Check two-way audio, MUTE and UNMUTE, LEAVE VOICE, switching rooms, and closing tabs. Confirm the microphone is released after leaving.
7. On a separate account **not invited** to that private room, verify that the voice signaling channel cannot be joined. Check Supabase Realtime policies if private membership checks fail.

### Technical implementation

- `voice.js`: browser microphone with `getUserMedia`, one peer-to-peer `RTCPeerConnection` per other caller, STUN for ICE, hidden remote audio elements, and manual `resumeAudio()` for browser autoplay restrictions.
- Supabase private Realtime Broadcast carries offer, answer and ICE signaling; private Presence announces current voice participants. The microphone is **off by default**, never starts without a user click, and is stopped when leaving/switching rooms/closing the page.
- A **recommended**, not server-enforced, four-participant capacity. This mesh design increases bandwidth and CPU with each added speaker. No voice recording or storage is built into the code.

### Limitations and safety before broad launch

- **No TURN relay is configured**. Connections may fail between restrictive mobile networks or symmetric NATs despite apparently successful presence/signaling. For reliability, add an authenticated short-lived TURN credential service (never hardcode long-term TURN secrets in GitHub).
- Peer-to-peer voice may expose network address information to connected peers. Audio is encrypted in transit by WebRTC (DTLS-SRTP), but DIGO has no end-to-end verification/anti-impersonation for signaling messages.
- Invite-only rooms are for trusted testers. Each voice participant must opt in; private room membership isn't a strong identity or age verification system.
- Block/report controls currently exist for text. **Voice-specific reporting, participant eviction, guardian/youth safety controls, and call abuse moderation are not complete**. Keep voice limited to trusted private beta until those controls are developed and tested.
- The v2.0 JavaScript was statically checked, but not independently tested with two real browsers/microphones yet.

**If a Join Voice button is missing**, confirm the room is private, the browser is on the latest DIGO deployment, and the v2.0 SQL has been applied. For errors, inspect the on-screen message and browser console.
