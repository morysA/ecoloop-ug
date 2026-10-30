# EcoLoop UG — Academic MVP Starter

This starter separates the Flutter mobile app, FastAPI backend, and PostgreSQL/PostGIS schema.

## Scope
- Flutter prototype: dashboard, waste listings, collection requests, learning modules.
- FastAPI starter: health check, categories, waste listing creation/listing, collection request status.
- SQL schema: core tables and starter constraints.
- This is a development scaffold, NOT a production-ready service.
- The API currently uses in-memory demo storage. Data disappears when the server restarts.
- Authentication, production database integration, row-level security, file storage, and real GPS tracking are not implemented.

## Prerequisites
- Flutter SDK and Android Studio or an Android device/emulator
- Python 3.11+
- Git (recommended)

## Run the API
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
Open `http://127.0.0.1:8000/docs` to explore the API.

## Run the Flutter app
In another terminal:
```bash
cd mobile
flutter pub get
flutter run
```
Android emulator API base URL is usually `http://10.0.2.2:8000`.
For a physical phone, set `API_BASE_URL` to your computer's LAN IP and ensure both devices share a network.

Example:
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Next implementation steps
1. Connect Flutter listing forms to the API.
2. Replace in-memory API storage with PostgreSQL using SQLAlchemy/Alembic.
3. Add authentication and role-based permissions before using real user data.
4. Configure PostGIS and verify spatial queries.
5. Add automated tests and run them before presenting or deploying.

## Important
Use clearly labelled demonstration data in the academic presentation. Do not claim that sample quantities represent verified recycling or landfill diversion.
