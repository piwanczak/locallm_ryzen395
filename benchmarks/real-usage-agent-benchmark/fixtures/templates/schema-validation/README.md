# Schema Validation Fixture

Task: strengthen `src/validateConfig.mjs`.

Run:

```powershell
node tools/test.mjs
```

Expected behavior:

- return a normalized copy rather than mutating input;
- default `mode` to `strict`;
- default missing service `retries` to `2` and `timeoutMs` to `5000`;
- allow `https://` and `http://localhost` endpoints only;
- reject duplicate service names, invalid retry/timeout values, invalid modes, and non-string headers.
