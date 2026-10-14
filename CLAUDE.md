# Extras

Static single-page HTML experiments for the Extras section of the site. Pushes to `main` deploy to Vercel (preset Other, no build command, no output directory). Local path: `~/Code/extras`.

## Guardrail: git, gh and vercel

- Run `git`, `gh` and `vercel` commands only from inside this repo folder (`~/Code/extras`).
- Never touch any Vercel project other than `extras`. Never link, deploy, redeploy, promote, roll back, rename, remove, change settings or env vars of, or add, move or remove domains on any other project.
- Before every `vercel` command, read `.vercel/project.json` and confirm `"projectName": "extras"`. If it says anything else, or the file is missing, stop and ask.
- Never run `vercel link` or `vercel project` commands without naming `extras` explicitly.

## Folder convention

- Each experiment lives at the repo root as `<slug>-figma-motion/index.html`. There is no `extras/` folder.
- Live URL: `$SITE_URL/<slug>-figma-motion/` (`SITE_URL` is in `scripts/site.env`).
- One commit per page: `Add <Readable name> experiment` (or `Update ...` for an existing page).

## Publishing

```
~/Code/extras/scripts/publish.sh <source-html> <slug> "<Readable name>" [--no-push]
```

It copies the file into place, runs `scripts/scrub.sh`, commits, pushes, waits for the deploy and prints the live URL. Use `--no-push` to commit only.

- Only publish the finished `.html` page. Never publish `.md` copies, `playbook.txt`, `_build/` or source READMEs.
- Never commit anything else from the source folder.
- The scrub terms live outside this repo, in the user-level `publish-extra` skill. Don't copy them into this repo.
- If the scrub fails, show the hits and stop. Don't edit page content to get past it without asking.
