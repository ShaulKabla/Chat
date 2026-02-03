# Master Integration Report

## Scope
This report captures the alignment work across the Mobile App (React Native build script), Backend (Node.js), and Admin Panel (Vite) for the main branch.

## Socket.io Handshake Alignment
**Resolved mismatches and alignment:**
- **Matchmaking:** Backend emits `match_found` to both users with `{ partnerId }`, aligned to mobile expectations.
- **Messaging:** Backend now accepts `message` with `{ clientId, text, createdAt, image, replyTo }` and emits `message` to the partner with `{ id, clientId, text, createdAt, userId, image, replyTo }` plus `message_ack` back to the sender with `{ clientId, messageId, status }`.
- **Typing:** Backend forwards `typing` / `stop_typing` events with `{ userId }` to paired users.
- **Ping/Pong:** Backend responds to `ping` with `{ ts }` and emits `pong` with `{ ts }`.
- **Maintenance/Drain:** Backend emits `maintenance_mode` with `{ enabled, message }` and the mobile app now stops matching when enabled.

## Binary Upload Flow
- **Mobile:** Image picks are uploaded via `multipart/form-data` under the `image` field to `/api/uploads/report`, then the returned `imageUrl` is normalized to a renderable URL before sending in chat messages.
- **Backend:** `uploadController` accepts `image` and returns `{ imageUrl, key }` from storage providers.

## Distributed Consistency & Scaling
- **Redis adapter:** Socket.io Redis adapter is initialized using pub/sub clients to ensure cross-instance broadcasts.
- **Stream key:** Matchmaking stream key is now configurable via `REDIS_STREAM_KEY`.

## Postgres Schema Coverage
- Admin panel needs report images and stats. The migrations create `reports` (with `image_url`), `bans`, and `anonymous_users` tables used by the backend.

## Token Revocation & Session Termination
- Admin bans add tokens to `revoked_tokens`, add the user to `banned_users`, and disconnect the active socket session immediately.

## Drain Mode Failover
- When drain mode is enabled, the backend broadcasts `maintenance_mode` with a "Server busy" message so mobile clients stop matching and show a clear state.

## Environment Variables
- Consolidated `.env.example` now documents backend, nginx, storage, and admin panel variables, including `S3_*`, `UPLOADS_PUBLIC_URL`, and `REDIS_STREAM_KEY`.

## Deployment & Initialization
- `deploy.sh` now validates environment configuration and runs database migrations before starting application services.
- `init_production.sh` performs a from-scratch bring-up with validation, migrations, and service health checks.
