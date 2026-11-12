# web-3.example.net

## Role
One of four nginx reverse proxies for the public website and API.
Production. A load balancer in front removes a host that fails
`GET /healthz` three times.

Because there are four, one host can be out of service with no customer
impact. Two cannot.

## Owner
Team web-platform. On-call: #web-oncall.

## Where things are
- Config: /etc/nginx/ (deployed by the pipeline `web-config`; manual edits
  are overwritten at the next deploy)
- Access and error logs: /var/log/nginx/ (rotated daily, 14 days)
- TLS certificates: /etc/letsencrypt/live/ (renewed by certbot.timer)

## Safe operations
- `nginx -t`, then `systemctl reload nginx`. A reload keeps connections.
- Read logs. `curl -s localhost/healthz`.
- Take this host out of rotation: `touch /var/run/drain`. The health check
  then fails and the load balancer removes the host in about 15 seconds.
  Remove the file to return.

## Do not
- Do not `systemctl restart nginx`. A restart drops open connections,
  including long uploads. Use reload.
- Do not drain this host before you check that the other three are in
  rotation.
- Do not run `certbot renew --force-renewal`. The rate limit of the
  certificate authority applies to the whole domain.
- Do not delete logs of today to free disk space. Delete rotated `.gz`
  files first.

## Escalation
5xx errors on all four hosts at the same time: the cause is upstream
(application or database). Do not change nginx. Page the on-call.

Last reviewed: 2026-11-12
