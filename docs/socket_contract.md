# Socket Contract

All payload keys are camelCase. Times are epoch milliseconds unless noted.

## Client → Server

| Event | Trigger | Payload | Notes |
| --- | --- | --- | --- |
| `find_match` | User selects mode | `{ mode: "talk" | "meet" }` | Enqueue for matchmaking. |
| `skip` | User taps Skip | `{}` | Immediate skip + requeue. |
| `message` | User sends chat message | `{ clientId: string, text: string, createdAt: number, userId: string, image?: string, replyTo?: { id: string, text?: string, image?: string, userId: string } }` | `image` is a URL. |
| `typing` | User starts typing | `{}` | Emits typing indicator. |
| `stop_typing` | User stops typing | `{}` | Stops typing indicator. |
| `ping` | Latency ping | `{ ts?: number }` | Server echoes via `pong`. |
| `block_user` | User blocks partner | `{ blockedUserId: string }` | Also triggers skip if paired. |
| `update_profile` | User saves profile | `{ gender: string, ageGroup: string, interests: string[], genderPreference?: string }` | Emits `profile_required` on error. |
| `reveal_request` | User taps reveal | `{}` | Requires both users to reveal. |
| `connect_request` | User taps connect | `{}` | Mutual request creates friends. |
| `friend_message` | Friend chat send | `{ friendId: string, text?: string, image?: string }` | Stored in DB. |

## Server → Client

| Event | Trigger | Payload | Notes |
| --- | --- | --- | --- |
| `maintenance_mode` | Maintenance enabled | `{ enabled: boolean, message?: string }` | Client should disconnect if enabled. |
| `user:id` | Socket auth ok | `{ userId: string }` | Canonical user id. |
| `match_found` | Match created | `{ partnerId: string, mode: "talk" | "meet", revealAvailable: boolean, partnerProfile?: { gender: string, ageGroup: string, interests: string[] } }` | For `meet` mode. |
| `match_searching` | Requeue | `{ message?: string }` | Displays searching notice. |
| `search_expanding` | `meet` fallback active | `{ message: string }` | Emitted after 15s wait. |
| `partner_left` | Partner skipped/disconnected | `{ reason: "skipped" | "left" | "blocked", systemMessage?: string }` | Show localized system notice. |
| `message` | Incoming chat | `{ id: string, clientId?: string, text: string, createdAt: number, userId: string, image?: string | null, imagePending?: boolean, replyTo?: { id: string, text?: string, image?: string, userId: string } }` | `imagePending` means reveal-gated. |
| `message_ack` | Delivery status | `{ ok: boolean, clientId?: string, messageId?: string, status?: "delivered" }` | Ack for sender. |
| `typing` | Partner typing | `{ userId: string }` |  |
| `stop_typing` | Partner stopped | `{ userId: string }` |  |
| `pong` | Ping response | `{ ts: number }` | Client latency calc. |
| `profile_required` | Meet profile missing | `{ message: string }` |  |
| `auth_error` | Auth failure | `{ message: string }` |  |
| `banned` | Account banned | `{ message: string }` |  |
| `rate_limit` | Rate limit hit | `{ scope: "skip" | "chat" | "connect" }` | Legacy event. |
| `rate_limit_reached` | Rate limit hit | `{ scope: "skip" | "chat" | "connect" }` | Preferred rate-limit event. |
| `connect_request` | Partner requests connect | `{ userId: string }` |  |
| `friend_added` | Mutual connect | `{ friendId: string }` |  |
| `reveal_timer_started` | Reveal timer starts | `{ revealAt: number, durationMs: number }` | 7-minute countdown. |
| `reveal_available` | Timer elapsed | `{}` | Reveal button enabled. |
| `reveal_confirmed` | Mutual reveal | `{}` | Photos can unblur. |
| `reveal_granted` | Mutual reveal | `{}` | Reveal is confirmed. |
| `source_revealed` | Full image revealed | `{ images: { messageId: string, imageUrl: string }[] }` | Full-res reveal after mutual approval. |
| `friend_message` | Incoming friend chat | `{ id: number | string, senderId: string, recipientId: string, body: string, imageUrl?: string | null, createdAt: string }` | Stored in DB. |
