# Changelog

All notable changes of this project are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-14

### Added

- The Flutter app for Android with the server manager and the media sender.
- The sign in with Discord over OAuth2 with PKCE, a public client and a state that is
  checked, the tokens live in the secure storage of the device.
- The server list with the icons, a search field and the favourites, the list is read
  with the pagination of Discord and filtered by the permissions of the user.
- The server screen with the overview, the moderation tools (kick, ban, timeout,
  purge, slow mode, the moderation log), the AutoMod rules, the verification level,
  the roles and the access inspector, the channels, the engagement tools and the
  server tools.
- The permission inspector that computes the real permission bits of Discord for a
  member in a channel.
- The media sender with webhooks and bot channels, the queue with pause, resume,
  cancel and reorder, the background upload service, the retry with backoff, the
  honouring of the `Retry-After` header and the history of every upload.
- The settings with the theme, the size limit, the number of files per message, the
  grouping and the notifications.
- The backend with the REST API, the access guard, the SQLite database, the
  scheduler and the Discord gateway with the event handlers.
- The workflow `.github/workflows/android-release.yml` that builds the app and the
  backend, runs the tests and publishes a signed package for the tags `v*`.
- The tests of the app and of the backend.

[1.0.0]: https://github.com/ryujin-hue/discord-server-manager/releases/tag/v1.0.0
