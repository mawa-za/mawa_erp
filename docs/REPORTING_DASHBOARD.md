# Reporting dashboard

The ERP `Reports` workcentre calls `mawa-reporting-bes` directly using the current ERP bearer token and selected role.

Reporting hosts:

- dev: `dev.reports.api.app.mawa.co.za`
- alpha: `alpha.reports.api.app.mawa.co.za`
- beta: `beta.reports.api.app.mawa.co.za`
- prep: `prep.reports.api.app.mawa.co.za`
- prod: `reports.api.app.mawa.co.za`

Native installations may override the derived host using the SharedPreferences key `reporting_api_host`.
