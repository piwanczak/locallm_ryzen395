# CLI Report Fixture

Task: enhance `bin/usage-report.mjs`.

Run:

```powershell
node tools/test.mjs
```

Expected behavior:

- preserve existing text output;
- add `--since YYYY-MM-DD` date filtering;
- add `--format json`;
- return non-zero with a useful stderr message for unknown formats.
