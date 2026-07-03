# Failing Command Recovery Fixture

Task: make `npm test` pass.

Run:

```powershell
npm test --silent
```

There are two problems:

- the package test command points at the wrong file;
- `src/parser.mjs` mishandles quoted comma fields.
