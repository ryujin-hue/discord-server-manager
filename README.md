# Discord Server Manager

A Flutter app for Android that manages Discord servers and sends media to Discord
channels. The repository holds two parts:

| Part | Path | What it is |
| --- | --- | --- |
| Flutter app | `lib/`, `android/`, `test/` | The Android client with the server manager and the media sender. |
| Backend | `backend/` | A small Fastify service with the REST API, the scheduler and the Discord gateway. |

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
├── backend/                 the Fastify service with the REST API and the gateway
│   ├── src/
│   │   ├── auth/            the mobile callback of the OAuth2 flow
│   │   ├── config/          the environment of the service
│   │   ├── db/              the SQLite database and the repositories
│   │   ├── discord/         the REST client of Discord and the permission helpers
│   │   ├── gateway/         the gateway client and the event handlers
│   │   ├── routes/          the REST routes of the app
│   │   ├── scheduler/       the recurring jobs
│   │   └── services/        the domain services
│   └── test/                the tests of the service
├── lib/
│   ├── app/                 the router, the shell and the theme
│   ├── core/                the configuration, the network, the storage and the widgets
│   └── features/            auth, guilds, server, media_sender and settings
├── test/                    the tests of the app
├── .github/workflows/       the release workflow
├── env.example.json         the template of the local configuration of the app
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
3. Under **Redirects** add the exact URI of the backend:

   ```
   https://YOUR-BACKEND-HOST/auth/mobile-callback
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

## Part two: backend

### 2.1 The environment

Copy the example file and fill in your values.

```bash
cd backend
cp .env.example .env
```

| Variable | Meaning |
| --- | --- |
| `DISCORD_CLIENT_ID` | The application id of the developer portal. |
| `DISCORD_BOT_TOKEN` | The token of the bot. Only needed when the gateway runs. |
| `PUBLIC_BASE_URL` | The public HTTPS address of the service, for example `https://api.example.com`. |
| `GATEWAY_ENABLED` | `true` starts the Discord gateway in the same process. |
| `PORT` | The port of the HTTP server, `8080` by default. |
| `DB_PATH` | The file of the SQLite database, `./data/app.sqlite` by default. |

### 2.2 Run it locally

```bash
cd backend
npm install
npm run dev
```

The scripts read the file `.env` when it exists, so the values of the table
above are used without exporting them. The service listens on
`http://localhost:8080`. Check that it answers with:

```bash
curl http://localhost:8080/health
```

### 2.3 Deploy it

The backend must be reachable over public HTTPS, the OAuth2 redirect URI of the
developer portal only accepts HTTPS addresses.

The service needs a Node.js runtime, a file system for the SQLite database and
a process that stays alive. Three ways to do that are prepared in the
repository.

#### A. Docker (the simplest way)

```bash
cd backend
cp .env.example .env      # fill in the values
docker compose up -d --build
docker compose logs -f backend
```

The image is built from `backend/Dockerfile`, the database lives in the volume
`backend-data` and only the port `8080` of the host is opened.

#### B. A server with systemd and Caddy

```bash
# on the server
sudo useradd --system --home /opt/discord-server-manager discord-server-manager
sudo mkdir -p /opt/discord-server-manager/data
sudo rsync -a --exclude node_modules --exclude dist ../backend/ /opt/discord-server-manager/
cd /opt/discord-server-manager && sudo npm ci && sudo npm run build
sudo cp deploy/discord-server-manager.service /etc/systemd/system/
sudo cp deploy/Caddyfile /etc/caddy/Caddyfile
sudo systemctl daemon-reload && sudo systemctl enable --now discord-server-manager
```

The secrets belong into `/etc/discord-server-manager.env`, the unit reads them
from there:

```ini
DISCORD_CLIENT_ID=000000000000000000
DISCORD_BOT_TOKEN=replace-with-your-bot-token
PUBLIC_BASE_URL=https://api.example.com
GATEWAY_ENABLED=true
PORT=8080
DB_PATH=/opt/discord-server-manager/data/app.sqlite
```

The address in the `Caddyfile` has to be the same as `PUBLIC_BASE_URL` and as
the redirect URI of the Discord application. Caddy fetches the certificate of
the address on its own.

#### C. A Cloudflare tunnel

A tunnel publishes the backend over HTTPS without a public address on the
server, which fits a machine that is already in Cloudflare.

```bash
cloudflared tunnel create discord-server-manager
cloudflared tunnel route dns discord-server-manager api.example.com
sudo cp deploy/cloudflared/config.yml /etc/cloudflared/config.yml
# fill in the id of the tunnel and the path of the credentials file
sudo systemctl restart cloudflared
```

The service itself only listens on the server, the tunnel terminates the TLS.

#### Notes for every way

- Keep the database file on a volume that is backed up.
- One process runs the REST API, the scheduler and the gateway over one SQLite
  database. Scaling it horizontally is not supported, because the scheduler and the
  gateway would run twice.

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

The workflow `.github/workflows/android-release.yml` runs on every push, on every pull
request and on the tags `v*`. It builds the app, runs the tests of the app and of the
backend and publishes a release when a tag is used.

Add these secrets in **Settings -> Secrets and variables -> Actions**:

| Secret | Meaning |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The release key as base64. Create it with `base64 -w0 upload-keystore.jks`. |
| `KEYSTORE_PASSWORD` | The password of the key store. |
| `KEY_ALIAS` | The alias of the key inside the key store. |
| `KEY_PASSWORD` | The password of the key. |

Without these secrets the workflow still builds the app, but the package is signed
with the debug key and no release is published. The workflow never writes a secret
into the repository.

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
`https://YOUR-BACKEND-HOST/auth/mobile-callback` exactly, with the same scheme and
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
`GATEWAY_ENABLED` is `false` or the bot token is missing. The features that need the
gateway are then unavailable, the rest of the API keeps working.

**`npm install` fails with a build error of `better-sqlite3`.**
A compiler or the build tools of Node.js are missing. Install the build tools of your
system or use a Node.js version with a prebuilt binary for your platform.

## License

MIT, see [LICENSE](LICENSE). The parts of Discord that this project talks to are
subject to the terms of service of Discord Inc.
