# VÔL web (Flutter)

The VÔL user app, rebuilt in Flutter Web. It uses the same NestJS API as the Next.js apps in
`Vol_Webapp` (`apps/api`). The admin panel stays in Next.js.

## Running locally

Start the API from the Vol_Webapp repo (`npm run dev:api`), and add `http://localhost:5000` to
`CORS_ORIGINS` in `apps/api/.env` once. Then:

```bash
flutter pub get
flutter run -d chrome --web-port 5000
```

Debug builds call `http://localhost:4000`, release builds call the Railway API. Point at any other
API with `--dart-define=API_URL=https://...`.

To try it against the live API locally, `http://localhost:5000` also has to be in Railway's
`CORS_ORIGINS`.

## Layout

The app is a screen-for-screen port of `apps/web`, so a change to one is easy to carry over to the
other.

```
lib/core          API client (bearer token in memory, refresh via the vol_rt cookie), auth state,
                  query cache, uploads, formatting helpers
lib/models        response shapes from packages/api-client/src/types.ts
lib/theme         VÔL tokens and light/dark themes
lib/ui            shared widgets ported from components/ui (buttons, fields, modals, grids, ...)
lib/features      one folder per area: auth, onboarding, shell, home, discover, explore, products,
                  business, profile, settings, workspaces, classrooms, canvas
lib/router.dart   every route from apps/web plus the sign-in/onboarding redirects
```

When the API changes a response shape, update the matching model in `lib/models`.

## Deploying

Vercel deploys straight from this repository. Vercel has no Flutter, so `vercel.json` clones the
pinned Flutter release during install, builds `build/web`, and sends every path to `index.html` so
deep links work. In the Vercel project, leave the framework preset on "Other" and the build settings
empty; `vercel.json` sets them.

Release builds call the Railway API. Add the deployed URL to `CORS_ORIGINS` on Railway, or the app
loads but can't sign in.

`.github/workflows/check.yml` runs `flutter analyze` and `flutter test` on every push.

```bash
flutter analyze
flutter test
flutter build web --release --wasm --pwa-strategy=none
```
