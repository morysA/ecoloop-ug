<<<<<<< HEAD
# EcoLoop UG — Academic MVP StarteThis starter separates the Flutter mobile app, FastAPI backend, and PostgreSQL/PostGIS schema.

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
=======
# ecoloop-ug
>>>>>>> 564e70b9d9bba1194bf1ec092551464778cd3a2e
^\
# EcoLoop UG 🌱
### Waste Has Value.

EcoLoop UG is a community-focused recycling and waste management platform designed to connect households, waste collectors, recycling businesses and community organizations in Uganda.

Our goal is to make waste collection more accessible, encourage responsible disposal, support recycling initiatives and help communities recognize the value of recyclable materials.

## Project Overview

EcoLoop UG aims to provide a digital platform where users can:

- Register and manage their accounts.
- Discover recyclable waste listings.
- Connect households with waste collectors and recycling businesses.
- Participate in community discussions.
- Access environmental education.
- Track recycling activities and environmental impact.

## Technology Stack

| Component | Technology |
|---|---|
| Mobile application | Flutter / Dart |
| Backend API | Python / FastAPI |
| Database | SQLite (development) |
| Authentication | Token-based authentication |
| API documentation | FastAPI / OpenAPI |

## Project Structure

```text
ecoloop-ug/
├── backend/
│   ├── app/
│   ├── tests/
│   └── requirements.txt
├── mobile/
│   ├── lib/
│   ├── assets/
│   └── pubspec.yaml
├── docs/
├── .gitignore
└── README.md
```

## Development Status

EcoLoop UG is under active development.

Implemented components include initial mobile application screens, backend registration and login functionality, account storage and a public user directory.

Additional modules, including complete waste collection workflows, community features, media uploads and persistent messaging, remain under development.

## Interactive Showcase

Explore the frontend demonstration:

https://ecoloop-ug-jtzviz.v2.appdeploy.ai/

Note: This is a separate interactive frontend demonstration. It is not yet connected to the Flutter/FastAPI backend.

## Running the Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Backend health check:

```text
http://127.0.0.1:8000/health
```

## Running the Mobile Application

```bash
cd mobile
flutter pub get
flutter run
```

## Project Vision

To contribute to a cleaner Uganda by using technology to connect communities, improve recycling participation and create opportunities around recyclable waste.

## Contribution

EcoLoop UG is a developing project. Contributions, feedback and collaboration are welcome.

## License

A license has not yet been selected.

