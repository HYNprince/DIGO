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
