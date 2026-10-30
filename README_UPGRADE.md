# EcoLoop UG — Authentication and onboarding upgrade

This patch preserves the modern EcoLoop Flutter screens and replaces the preview-only login form with API-backed registration/login.

## What changed
- Distinctive responsive welcome + sign-in/register layout.
- Register: full name, unique username, email, password + confirmation, account type, current area/town.
- Account types: household/resident, waste collector, recycling business, community organization.
- Login is checked by the backend; invalid/unknown account is rejected and the form switches to registration with an explanation.
- FastAPI stores users in SQLite at `backend/ecoloop.db`; passwords use PBKDF2-HMAC-SHA256 with random salts; bearer tokens are opaque, hashed in storage and expire after seven days.
- `GET /api/v1/users` gives a public directory with profile name, username, role, location and creation date; it does not expose emails/passwords/tokens. Supports `role`, `q`, `limit`, `offset`.
- Existing dashboard, learn, impact and support UI are retained.

## Important limits
- This is an academic MVP, not production-ready identity infrastructure. Before public deployment add HTTPS, rate limiting, email verification, password reset, privacy/consent controls and stronger operational logging.
- Current-location field is an area/town entered by the user; it does not silently collect GPS.
- Existing waste listings/collection data in the inherited backend remain in-memory. Registration is persisted in SQLite. We should migrate listings to SQLite next.
- Chat UI is still a preview; shared real-time chat is a separate backend task.

## Install safely
1. Back up your local files first (commands below).
2. Copy `mobile/lib/main.dart` into `~/Downloads/ecoloop starter/mobile/lib/main.dart`.
3. Copy `backend/app/main.py` into `~/Downloads/ecoloop starter/backend/app/main.py`.
4. Restart the backend and run the Flutter app.

```bash
cd "$HOME/Downloads/ecoloop starter"
cp mobile/lib/main.dart mobile/lib/main.dart.before-auth-upgrade.bak
cp backend/app/main.py backend/app/main.py.before-auth-upgrade.bak
# after copying the patch files into the folders above:
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

For the phone over Wi-Fi, use your laptop Wi-Fi IP, not 127.0.0.1:
```bash
cd "$HOME/Downloads/ecoloop starter/mobile"
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_LAPTOP_WIFI_IP:8000
```

## API endpoints
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me` (Bearer token required)
- `POST /api/v1/auth/logout`
- `GET /api/v1/users?role=collector&q=Kampala&limit=50&offset=0`
