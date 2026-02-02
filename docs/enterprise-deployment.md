# Enterprise Deployment Notes

## Health Checks for Corporate Monitoring

Use the Nginx edge endpoint for external HTTP/S monitoring:

- **HTTPS**: `https://<DOMAIN>/health`
- **HTTP** (optional): `http://<DOMAIN>/health` (will redirect to HTTPS if TLS is enabled)

Internal-only checks (inside the Docker network) can target:

- Backend API: `http://backend:3000/health`
- Admin panel: `http://admin-panel:8080/health`

These endpoints respond with a simple `200 OK` payload and can be used for
HTTP-based checks from corporate monitoring tools. Avoid probing internal
containers from outside the private Docker network.

## Scaling Notes

- The backend uses Redis-backed Socket.io adapters, so it can be scaled with:
  `docker compose up -d --scale backend=3`
- Redis must be reachable on the private network to maintain shared sessions.
