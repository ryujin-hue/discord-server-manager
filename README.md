# Discord Server Manager

A Flutter app for Android that manages Discord servers and sends media to Discord
channels. The repository holds two parts:

| Part | Path | What it is |
| --- | --- | --- |
| Flutter app | `lib/`, `android/`, `test/` | The Android client with the server manager and the media sender. |
| Backend | `functions/`, `workers/`, `migrations/` | Cloudflare Pages Functions + D1 + Cron Triggers — no server to maintain. |

The app signs the user in with Discord, lists the servers the user administers and
offers the tools a server owner needs. The media sender uploads pictures and videos to
a webhook or to a channel of the bot.

> This project is not affiliated with, endorsed by or sponsored by Discord Inc.
> "Discord" is a trademark of Discord Inc.

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Repository layout](#repository-layout)
- [Part one: Discord developer portal](#part-one-discord-developer-portal)
- [Part two: backend](#part-two-backend)
- [Part three: the app](#part-three-the-app)
- [GitHub secrets for the release workflow](#github-secrets-for-the-release-workflow)
- [The Cloudflare Pages project](#the-cloudflare-pages-project)
- [Tests](#tests)
- [Limits](#limits)
- [Token and secret policy](#token-and-secret-policy)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

### Server manager

- Sign in with Discord over OAuth2 (PKCE, no client secret in the app).
- Server list with the icons of the servers, a search field and favourites.
- Overview with the member, channel and role counters.
- Moderation: kick, ban, timeout, message purge, slow mode and the moderation log.
- AutoMod rules: the keyword, the spam and the link filter of a channel.
- Verification levels, the server settings and the audit log.
- Roles and access: create roles, grant them, and inspect the permissions of a member
  in a channel with the real permission bits of Discord.
- Channels: create, rename, move and delete channels and categories.
- Engagement: welcome messages, announcements, reaction roles and the invite tracker.
- Tools: emojis, stickers, invites and the slash commands of the bot.

### Media sender

- Destinations: webhooks and bot channels, stored on the device.
- Queue with pause, resume, cancel, reorder and a background upload service.
- Retry with backoff, the `Retry-After` header of Discord is always honoured.
- History of every upload with the duration, the size and the error of a failure.

## Requirements

| Tool | Version |
| --- | --- |
| Flutter | 3.47.9 (pinned in `pubspec.yaml` and in the workflow) |
| Dart | the version that comes with Flutter 3.47.9 |
| Node.js | 22.19.0 or newer (Node LTS) |
| JDK | 17 |
| Android SDK | platform 35, build tools 36.0.0 |

The app needs Android 8.0 (API 26) or newer.

## Repository layout

```
discord-server-manager/
├── android/                 the Android host of the app
├── backend/                 the original Node/Fastify backend (archived, not deployed)
├── functions/               Cloudflare Pages Functions (the API + OAuth2 callback)
│   ├── [[path]].ts          the route dispatcher
│   └── _lib/                services, repos, discord, auth, http, rateLimit
├── workers/
│   └── scheduler/           the Cron Worker (announcements + snapshots)
├── migrations/              D1 SQL migrations
├── docs/
│   └── cloudflare-migration.md   migration guide and architecture
├── lib/
│   ├── app/                 the router, the shell and the theme
│   ├── core/                the configuration, the network, the storage and the widgets
│   └── features/            auth, guilds, server, media_sender and settings
├── test/                    the tests of the app
├── .github/workflows/       deploy-cloudflare.yml + android-release.yml
├── env.example.json         the template of the local configuration of the app
├── wrangler.toml            Cloudflare Pages + D1 configuration
└── pubspec.yaml
```

## Part one: Discord developer portal

### 1.1 Create the application

1. Open <https://discord.com/developers/applications> and press **New Application**.
2. Name it `Discord Server Manager` and press **Create**.
3. Copy the **Application ID** from the *General Information* page. It is the
   `DISCORD_CLIENT_ID` of the app and of the backend.

### 1.2 The OAuth2 client of the app

1. Open **OAuth2 -> Client** in the sidebar.
2. Press **Add Client** and choose **Public Client** (no client secret).
3. Under **Redirects** add the exact URI of the Cloudflare Pages deployment:

   ```
   https://YOUR-PAGES-DOMAIN/auth/mobile-callback
   ```

   The backend redirects the browser further to
   `my-discord-manager://oauth2/callback`. The mobile scheme itself is fixed in
   `lib/core/config/app_config.dart` and in the Android manifest.
4. Under **Scopes** select exactly these two:

   | Scope | Why it is needed |
   | --- | --- |
   | `identify` | The app shows the name and the avatar of the signed in user. |
   | `guilds` | The app lists the servers of the user and reads their channels, roles and members. |

   No other scope is needed and no scope of a bot is needed for the sign in.

### 1.3 The bot of the backend

The bot is optional. It is only needed for the gateway features (welcome messages,
reaction roles, the invite tracker) and for the bot destinations of the media sender.

1. Open **Bot** in the sidebar and press **Reset Token**. Keep the token safe, it is the
   `DISCORD_BOT_TOKEN` of the backend.
2. Under **Privileged Gateway Intents** switch on **Server Members Intent**. The
   backend needs it to know when a member joins or leaves.
3. Invite the bot with the permissions below. The integer is the sum of the listed
   permission bits, the bot never receives **Administrator**.

   **Permission integer: `1103001365751`**

   | Bit | Permission | Why the bot needs it |
   | --- | --- | --- |
   | `1 << 0` | `CREATE_INSTANT_INVITE` | The invite tracker reads the invite list of a server. |
   | `1 << 1` | `KICK_MEMBERS` | Kicking a member is part of the moderation tools. |
   | `1 << 2` | `BAN_MEMBERS` | Banning a member is part of the moderation tools. |
   | `1 << 4` | `MANAGE_CHANNELS` | Channels and categories are created, renamed and deleted. |
   | `1 << 5` | `MANAGE_GUILD` | The verification level and the server settings are changed. |
   | `1 << 6` | `ADD_REACTIONS` | Reaction roles are granted when a reaction is added. |
   | `1 << 7` | `VIEW_AUDIT_LOG` | The audit log is shown in the server tools tab. |
   | `1 << 10` | `VIEW_CHANNEL` | Every server feature reads channels and members. |
   | `1 << 11` | `SEND_MESSAGES` | Welcome messages, announcements and the moderation log are sent. |
   | `1 << 13` | `MANAGE_MESSAGES` | Purging messages deletes up to 100 messages per call. |
   | `1 << 16` | `READ_MESSAGE_HISTORY` | Purging needs the history, and reactions need the message. |
   | `1 << 28` | `MANAGE_ROLES` | Roles are created, edited and granted by the role tools. |
   | `1 << 30` | `MANAGE_GUILD_EXPRESSIONS` | Emojis and stickers are managed in the server tools tab. |
   | `1 << 31` | `USE_APPLICATION_COMMANDS` | The bot registers slash commands for the server. |
   | `1 << 40` | `MODERATE_MEMBERS` | Timing a member out requires the moderate members permission. |

   The same list is defined in `lib/core/utils/discord_permissions.dart` and is covered
   by a test, so it can never drift apart from the documentation.

### 1.4 The webhook of the media sender

A webhook is created in Discord itself: **Server settings -> Integrations -> Webhooks ->
New Webhook**. The URL of the webhook contains the secret. The app stores it in the
secure storage of the device and sends it directly to Discord, it never passes through
the backend.

## Part two: backend (Cloudflare)

The backend is now a **Cloudflare Pages Functions** project backed by **D1** and
**Cron Triggers**. There is no server, no Docker container, no systemd unit and no
tunnel to maintain. The original Node/Fastify backend is preserved in `backend/` as
archived reference code but is no longer deployed.

The full migration guide is in [`docs/cloudflare-migration.md`](docs/cloudflare-migration.md).

### 2.1 Prerequisites

- A Cloudflare account with Pages, Workers and D1 enabled.
- The [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) (`npx wrangler`).
- The GitHub secrets listed in `.github/workflows/deploy-cloudflare.yml`.

### 2.2 Run it locally

```bash
npm install
npm run build:site
npx wrangler pages dev dist --local
```

Wrangler creates a local D1 database and runs the Functions on
`http://localhost:8788`. Check that it answers:

```bash
curl http://localhost:8788/health
```

### 2.3 Deploy it

The deployment is automated by the `deploy-cloudflare.yml` GitHub Actions workflow
on every push to `main`. The steps it performs:

1. `npm ci` + `npm run typecheck`
2. `npm run build:site` (copies `site/` into `dist/`)
3. Apply D1 migrations to the production database
4. Deploy Pages (static site + Functions API) to production
5. Deploy the Cron Worker

For a manual first-time setup:

```bash
# 1. Create D1 databases
npx wrangler d1 create discord-server-manager
npx wrangler d1 create discord-server-manager-preview

# 2. Apply migrations
npx wrangler d1 migrations apply discord-server-manager --remote --config wrangler.toml

# 3. Set Cloudflare secrets (never in git)
npx wrangler pages secret put DISCORD_BOT_TOKEN   --project-name=discord-server-manager
npx wrangler pages secret put DISCORD_PUBLIC_KEY  --project-name=discord-server-manager

# 4. Deploy
npm run deploy:pages
npm run deploy:cron
```

After the first deploy, set the OAuth2 redirect URI in the Discord Developer Portal
to `https://YOUR-PAGES-DOMAIN/auth/mobile-callback`.

#### Gateway limitations

The Discord Gateway uses a persistent WebSocket and cannot run on Cloudflare
Workers/Pages Functions. The following features are **unavailable** on the
Cloudflare backend:

- Welcome/goodbye messages (member add/remove events)
- Reaction-role live listener (reaction add events)
- Invite tracking attribution (invite create/delete events)
- Persistent bot presence (shows offline unless a separate always-on process is used)

**Button-role interactions** work via the `/interactions` endpoint with Ed25519
signature verification. All other REST API features work identically to the
original backend.

### 2.4 The contract of the API

Every answer uses the same envelope.

```jsonc
// success
{ "data": { "guilds": [] } }

// failure
{ "error": { "code": "forbidden", "message": "…", "discordCode": 50013, "retryAfter": 2 } }
```

The access guard of the backend runs on every server route:

1. The bearer token of the request is read and never written to the database.
2. `GET /users/@me/guilds` is read with the pagination of Discord, until a page
   holds less than 200 servers.
3. The user must own the server or hold `ADMINISTRATOR` (`1 << 3`) or
   `MANAGE_GUILD` (`1 << 5`).
4. The result is cached for 60 seconds, the key is the SHA-256 hash of the token.

## Part three: the app

### 3.1 The local configuration

The app reads its configuration from `env.json`. The file is not part of the
repository, `env.example.json` is the template.

```bash
cp env.example.json env.json
```

```json
{
  "DISCORD_CLIENT_ID": "000000000000000000",
  "BACKEND_URL": "https://api.example.com",
  "GITHUB_REPO": "ryujin-hue/discord-server-manager"
}
```

| Key | Meaning |
| --- | --- |
| `DISCORD_CLIENT_ID` | The application id of the developer portal. |
| `BACKEND_URL` | The public HTTPS address of the backend. |
| `GITHUB_REPO` | The repository that is shown in the settings, for example `owner/name`. |

The file is passed to the build with `--dart-define-from-file=env.json`.

`BACKEND_URL` has to be the same address as `PUBLIC_BASE_URL` of the backend,
without a trailing slash. The app builds the redirect URI of the OAuth2 flow
out of it (`$BACKEND_URL/auth/mobile-callback`) and Discord only accepts a
redirect URI that was registered in the developer portal.

### 3.2 Run it

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define-from-file=env.json
```

### 3.3 Build a package

```bash
flutter build apk --release --dart-define-from-file=env.json
```

The package is written to `build/app/outputs/flutter-apk/app-release.apk`.

### 3.4 The signing key of a release

The release build uses the key of `android/key.properties` when the file exists and
falls back to the debug key when it does not. The file has four lines.

```properties
storeFile=upload-keystore.jks
storePassword=…
keyAlias=…
keyPassword=…
```

`storeFile` is relative to `android/app/`. The file and the key are never part of the
repository, see `.gitignore`.

## GitHub secrets for the release workflow

The workflow `.github/workflows/android-release.yml` runs on every push to `main`, on every
pull request and on the tags `v*`. It builds the app, runs the tests of the app and of the
backend and publishes a release with the package attached.

Add these secrets in **Settings -> Secrets and variables -> Actions**:

| Secret | Meaning |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The release key as base64. Create it with `base64 -w0 upload-keystore.jks`. |
| `KEYSTORE_PASSWORD` | The password of the key store. |
| `KEY_ALIAS` | The alias of the key inside the key store. |
| `KEY_PASSWORD` | The password of the key. |

Without these secrets the workflow still builds the app and still publishes the release,
but the package is signed with the debug key and the release notes say so. The workflow
never writes a secret into the repository.

Add these variables in the same place, they are not secret:

| Variable | Meaning |
| --- | --- |
| `DISCORD_CLIENT_ID` | The application id of the developer portal, it is written into the configuration of the build. |
| `BACKEND_URL` | The public HTTPS address of the backend, it is written into the configuration of the build. |

### The version of a release

Every push to `main` raises the version by itself.

1. `tool/release.mjs` reads the version of the last tag and raises the patch number.
   The kind of the raise comes from `RELEASE_BUMP` (`patch`, `minor` or `major`).
2. The new version is written into `pubspec.yaml` and into a new section of the
   `CHANGELOG.md`, the build number is the number of the commits.
3. The package is built with that version and published as a release with the tag
   `v<version>`. The name of the file is `Discord-Server-Manager-<version>.apk`.
4. The raised version is committed back to `main`. That commit carries the marker that
   tells GitHub to not start a new run, so the version is raised exactly once.

The app reads the latest release of the repository to show that an update is
available, so every push also makes the update check of the installed app find the
new package.

To build a release with a key of your own, add the four secrets of the table above.
A package that is signed with the debug key can be installed, but Android shows a
warning and it can never replace a package that was signed with the release key.

## The Cloudflare Pages project

The pages project of this repository is `discord-server-manager`. It reads the
repository from GitHub, so every push to `main` starts a build.

| Setting | Value |
| --- | --- |
| Address | `https://discord-server-manager.pages.dev` |
| Source | GitHub, `ryujin-hue/discord-server-manager` |
| Production branch | `main` |
| Build command | `bash .github/cloudflare/build-site.sh` |
| Output directory | `dist` |

The build script copies the folder `site` into the output directory. The folder
holds the landing page of the project. The application itself is built for
Android, the web build of the app is not part of this repository yet.

The connection to GitHub is made with the Cloudflare GitHub App. When the
repository is missing in the list of the dashboard, the app does not have the
access to it yet. Open **Settings -> Applications -> Installed GitHub Apps ->
Cloudflare Pages and Workers -> Configure**, choose the repository (or
**All repositories**) and save. The pages project has to be connected again
after that.

## Tests

```bash
# the app
flutter test

# the backend
cd backend
npm test
```

The tests of the app cover the PKCE challenge of the RFC 7636, the filter of the
permissions, the pagination of the server list, the interceptor of the token with the
shared refresh, the inspector of the permissions, the classification of the errors,
the redaction of secrets, the state machine of the queue, the upload engine against a
mock adapter (success, rate limit, file too large, cancel, lost connection, an upload
that was interrupted by a restart), the persistence of the history and of the settings
and an integration test that adds a webhook, picks two files, sends them and finds two
successes in the history.

The tests of the backend cover the access guard, every REST route with a mocked
Discord, the scheduler across a restart, the round trip of the settings, the whitelist
of the callback address and every gateway handler with fakes.

## Limits

The app stays inside the limits of the Discord API.

| Limit | Value |
| --- | --- |
| Upload size per message | 10 MiB, the limit can be lowered in the settings, never raised above the Discord limit. |
| Files per message | 10, the settings allow 1 to 10. |
| Messages deleted by a purge | 100 per call and only messages that are less than 14 days old. |
| Bots per server | 200 by the API of Discord. |
| Rate limit of a route | The `Retry-After` header of Discord is always honoured, the upload waits as long as it says. |
| Background upload | Only on Android, the service stops when the app is removed. |

## Token and secret policy

- The access token and the refresh token of the user live only in the secure storage
  of the device (`flutter_secure_storage`). They are never written to the database of
  the app and never sent to the backend.
- The backend reads the token of the request, uses it for the call to Discord and
  forgets it. No token is stored, not even a hash of a token.
- Webhook URLs and bot tokens for the media sender stay in the secure storage of the
  device and are sent directly to Discord by the app.
- Secrets are never written to a log. Every message that could contain a secret is
  redacted by `lib/core/utils/redaction.dart` before it is shown.
- The debug build of the app prints the redacted version of an error, the release
  build shows only the error code and the message of Discord.

## Troubleshooting

**The sign in ends immediately with `invalid_client`.**
The redirect URI of the developer portal must match
`https://YOUR-PAGES-DOMAIN/auth/mobile-callback` exactly, with the same scheme and
without a trailing slash. The client of the app must be a public client.

**The sign in ends with `access_denied`.**
The user pressed *Cancel* in the browser. The app returns to the login screen and does
not show an error.

**Every request fails with `forbidden`.**
The user is not the owner of the server and holds neither `ADMINISTRATOR` nor
`MANAGE_GUILD`. The access guard of the backend answers with 403.

**The upload fails with `permission_denied`.**
The webhook was deleted or the bot has no `SEND_MESSAGES` in the target channel. The
app shows the error code of Discord, for example `50013`.

**The upload fails with `file_too_large`.**
The file is larger than the limit of the settings or larger than the limit of
Discord (10 MiB for a normal account). The app refuses the file before it is sent.

**The upload fails with `rate_limited`.**
Discord answered with 429. The app waits as long as the `Retry-After` header says and
tries once more. A file that is still limited after the retries is reported as
failed.

**The upload fails with `interrupted`.**
The app was killed while the upload was running. The file is marked as interrupted
when the app starts again and can be sent again.

**The background upload stops on Android 14 or newer.**
Android needs the notification permission for a foreground service. The app asks for it
the first time a background upload starts. The service also stops when the user
removes the app.

**The backend answers with `gateway_disabled`.**
On the Cloudflare backend, live Gateway features (welcome/goodbye messages,
reaction-role listener, invite tracking) are permanently unavailable — there is
no persistent WebSocket. The REST API, button-role interactions, scheduled
announcements and snapshots all keep working. See
[docs/cloudflare-migration.md](docs/cloudflare-migration.md) for details.

**`npm install` fails.**
Make sure you are running Node.js 22 or newer. The Cloudflare project no longer
depends on `better-sqlite3` (D1 replaces SQLite), so native build tools are not
required for the serverless backend.

## License

MIT, see [LICENSE](LICENSE). The parts of Discord that this project talks to are
subject to the terms of service of Discord Inc.
