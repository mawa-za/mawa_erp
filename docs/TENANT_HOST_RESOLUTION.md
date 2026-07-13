# Tenant host resolution

Flutter web sends the browser hostname, not the complete browser URL, in `X-TenantID`.

For example:

- Browser URL: `https://dev.app.mawa.co.za/#/login`
- `X-TenantID`: `dev.app.mawa.co.za`

`Config.webTenant` uses the browser URI host and strips the scheme, port, path, query string and Flutter hash route.
