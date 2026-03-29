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
