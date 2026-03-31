# mobile_app

Default backend address:

```bash
http://47.123.7.235
```

The app still supports overriding the API address at build time:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

If you do not pass `API_BASE_URL`, the app will connect to the deployed server.

## Build for Web

The Flutter project already contains a `web/` target, so you can build a web bundle directly:

```bash
cd mobile_app
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

The generated static files will be written to:

```bash
build/web
```

If you need to deploy under a sub-path such as `/tool-store/`, add a base href:

```bash
flutter build web --release \
  --base-href /tool-store/ \
  --dart-define=API_BASE_URL=https://api.example.com
```

For local preview:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

The backend currently enables CORS for all origins in `app/main.py`, so browser requests can reach the API as long as `API_BASE_URL` points to an accessible server.
