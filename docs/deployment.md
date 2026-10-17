# Running this on another machine, and deploying (owner: C)

This project's `by llm()` calls need a provider API key set as an
environment variable. The key is never committed (`.env` is gitignored)
so it has to be set separately in every place the code runs. Three places:

## 1. Your own machine (or a teammate's)

```bash
cp .env.example .env
```

Then edit `.env` and set `GOOGLE_API_KEY` to your own key:

1. Go to [aistudio.google.com/apikey](https://aistudio.google.com/apikey).
2. "Create API key" -> "Create API key in new project" (or an existing one).
3. Copy the key (starts `AIzaSy...`) into `.env`.

Free tier, no card required. Everyone on the team can use their own key -
they don't need to share one.

Confirm it's wired up:

```bash
jac check . && jac test .
```

## 2. The deployed Jac Hammer app

Jac Hammer env vars have two scopes (confirmed in docs.jachammer.ai ->
Settings -> Environment variables):

- **Global** (set once per account) - reaches preview and sandbox deploys
  only, **not** a permanent/production deploy.
- **Project** (set per project) - reaches preview, sandbox, **and**
  production deploys.

So the deployed app's `GOOGLE_API_KEY` has to be a **project-level**
variable, not a global one, or it silently won't be there in production.
Set it from the project's own Settings -> Environment variables -> add a
project variable named `GOOGLE_API_KEY`.

This is separate from Jac Hammer's "Bring your own API key" feature -
that one is account-wide and only affects which model *JacHammer's own
AI assistant* uses while editing your code, not what your deployed app's
`by llm()` calls use at runtime.

## 3. Jac version (confirmed, no action needed)

`jac.toml`'s `jac-version = "==0.37.25"` pin is read directly by Jac
Hammer (Settings -> Jac version works by writing this same field), so the
deployed app automatically builds on the same Jac release this repo was
developed and tested against - no separate version pin needed in the Jac
Hammer UI.

## GitHub sync (resolves the playbook's open mentor-question)

Confirmed in docs.jachammer.ai -> Integrations -> GitHub: a Jac Hammer
project can **import an existing GitHub repo**, then **push/pull like a
normal git remote from the Git panel**, and a production deploy can
**auto-deploy on every push to a branch** (separate GitHub App
authorization from push/pull - may need a second one-time auth even on an
already-connected project). So the "does Jac Hammer sync with GitHub"
question from the playbook is yes, bidirectionally, with optional
auto-deploy.
