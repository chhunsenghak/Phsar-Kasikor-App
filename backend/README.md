# Phsar Kasikor Backend API

This is the Python FastAPI backend for the **Phsar Kasikor App**, structured using clean, layered architecture principles. It provides user authentication (JWT-based) and registration out of the box, ready to connect with the Flutter frontend application.

## 🚀 Tech Stack

- **Core Framework**: [FastAPI](https://fastapi.tiangolo.com/) (Fast, asynchronous web framework for building APIs with Python 3.10+)
- **ASGI Server**: [Uvicorn](https://www.uvicorn.org/) (Lightning-fast ASGI server implementation)
- **Database ORM**: [SQLAlchemy 2.0](https://www.sqlalchemy.org/) (SQL toolkit and Object Relational Mapper)
- **Validation & Settings**: [Pydantic v2](https://docs.pydantic.dev/) (Data validation and settings management using python type annotations)
- **Authentication & Security**:
  - JWT Tokens: [python-jose](https://github.com/mpdavy/python-jose) (Cryptographic signatures)
  - Hashing: [passlib](https://passlib.readthedocs.io/) with `bcrypt` (Secure password storage)
- **Database (Development)**: SQLite (Default local file-based database)

---

## 📂 Project Structure

The project follows a modular, layered structure separating core settings, database access, business services, validation schemas, data models, and API routing.

```text
backend/
├── app/
│   ├── api/                  # API routes and dependency injection
│   │   ├── deps.py           # Common endpoint dependencies (e.g. get_current_user)
│   │   └── v1/               # API version 1 router
│   │       ├── api.py        # Version 1 router aggregator
│   │       └── endpoints/    # Feature-specific router modules
│   │           ├── auth.py   # Login and token generation
│   │           └── users.py  # Registration and profile details
│   ├── core/                 # App configurations and core initializations
│   │   ├── config.py         # Pydantic Settings loaders for env variables
│   │   ├── database.py       # DB engine, session maker, get_db session dependency
│   │   └── security.py       # Password hashing & JWT helpers
│   ├── models/               # SQLAlchemy Database Models (Declarative Base)
│   │   ├── base.py           # Declares Base instance
│   │   └── user.py           # User entity model
│   ├── schemas/              # Pydantic Validation & Serialization Schemas
│   │   └── user.py           # Request/response schemas for authentication/users
│   ├── services/             # Business Logic & Database operations (Repository)
│   │   └── user_service.py   # DB query & transactional logic for Users
│   └── main.py               # Entry point of the FastAPI application
├── .env                      # Local environment variable overrides (Ignored by git)
├── .env.example              # Development environment variable template
├── .gitignore                # File exclusion patterns for Git
└── pyproject.toml            # Project packaging and dependency definitions
```

---

## 🛠️ Setup & Installation

### 1. Prerequisites
- **Python 3.10+** installed on your system.

### 2. Create Virtual Environment
Open your terminal in the `backend` directory:
```bash
python -m venv .venv
```

Activate the virtual environment:
- **Windows (PowerShell)**:
  ```powershell
  .venv\Scripts\Activate.ps1
  ```
- **macOS / Linux**:
  ```bash
  source .venv/bin/activate
  ```

### 3. Install Dependencies
Install all required packages specified in `pyproject.toml`:
```bash
pip install .
```
*(Or install manually: `pip install fastapi uvicorn sqlalchemy pydantic pydantic-settings python-jose[cryptography] passlib[bcrypt] bcrypt python-multipart python-dotenv`)*

### 4. Configure Environment Variables
Copy `.env.example` to `.env` and configure your settings:
```bash
cp .env.example .env
```
In `.env`, you can customize:
- `SECRET_KEY`: A cryptographically secure secret key for signing JWT tokens.
- `DATABASE_URL`: The SQLite database filename (e.g., 
  `postgresql://postgres:1234567890@[IP_ADDRESS]/phsar_kasikor_db`)

The following are optional — each feature they back degrades gracefully (falls
back to a no-op) when left blank, so you don't need them for local dev unless
you're testing that specific feature:
- `FIREBASE_SERVICE_ACCOUNT_PATH`: path to a Firebase service-account JSON
  (Firebase console → Project Settings → Service Accounts → Generate new
  private key). Enables push notifications; without it, notifications still
  save to the DB but nothing gets pushed to a device.
- `SMTP_HOST` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` /
  `SMTP_FROM_EMAIL` / `SMTP_USE_TLS`: enables real email delivery for
  password-reset and email-verification codes. For Gmail, `SMTP_PASSWORD`
  must be an [App Password](https://myaccount.google.com/apppasswords), not
  the account's regular login password.
- `BAKONG_API_BASE_URL` / `BAKONG_MERCHANT_ACCOUNT_ID` / `BAKONG_MERCHANT_NAME`
  / `BAKONG_MERCHANT_CITY`: enables real KHQR code generation for checkout —
  this part works fully offline once the merchant fields are set, no token
  needed. `BAKONG_BEARER_TOKEN` is separate and optional again: it only
  enables automatic "was this paid?" verification, and it's short-lived
  (expires and must be refreshed via the Bakong developer portal), so leaving
  it blank just means payment confirmation stays manual.

---

## 🏃 Running the Application

### Option A: Running with Docker Compose (Recommended for PostgreSQL)
To spin up both the PostgreSQL database and the FastAPI backend automatically in container environments:
```bash
# Build and start services in the background
docker compose up --build -d

# View service logs
docker compose logs -f
```

### Option B: Running Locally with Uvicorn
Ensure you have a local PostgreSQL instance running or switch the `DATABASE_URL` in `.env` to SQLite, then start the Uvicorn development server:
```bash
uvicorn app.main:app --reload
```

The application will run at:
- **API Server URL**: [http://localhost:8000](http://localhost:8000)
- **Interactive Swagger Documentation**: [http://localhost:8000/docs](http://localhost:8000/docs) (Allows you to view all available endpoints and test them directly in the browser)
- **Alternative Redoc Documentation**: [http://localhost:8000/redoc](http://localhost:8000/redoc)

---

## 🗄️ Database Migrations with Alembic

We use **Alembic** to manage database schema updates programmatically without losing existing data.

### Option A: Running inside Docker (Recommended)
Since the database runs inside Docker, running migration tasks inside the container ensures hostnames and networks resolve correctly:

1. **Autogenerate a new migration script** (run this after modifying any model inside `app/models/`):
   ```bash
   docker compose exec backend alembic revision --autogenerate -m "description of changes"
   ```
2. **Apply migrations to the database**:
   ```bash
   docker compose exec backend alembic upgrade head
   ```
3. **View current database schema version**:
   ```bash
   docker compose exec backend alembic current
   ```

### Option B: Running Locally (Non-Docker)
If you are running the backend natively outside Docker, run the commands directly in your activated virtual environment:

1. **Autogenerate migration**:
   ```bash
   alembic revision --autogenerate -m "description of changes"
   ```
2. **Apply migration**:
   ```bash
   alembic upgrade head
   ```

---

## 🌱 Seeding & Resetting the Database

### Seed baseline data
`app/seed.py` creates the base roles, product categories, and 4 test accounts
(admin / farmer / buyer / cooperative — see the file for credentials) if they
don't already exist. It's idempotent — safe to run repeatedly, it only fills
in what's missing and updates the 4 seeded users, it never touches products,
orders, or anything else you've created:
```bash
docker exec phsarkasikor_backend python -m app.seed
```

### Full reset (⚠️ destructive)
To wipe **everything** — every product, order, user account beyond the 4
seeded ones, all of it — and start from a clean schema:
```bash
# 1. Drop and recreate the schema (deletes every table)
docker exec phsarkasikor_db psql -U postgres -d phsarkasikor -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# 2. Rebuild all tables directly from the current models — NOT `alembic
#    upgrade head`. The migration history has a pre-existing gap (a
#    `contracts` migration references `users` via FK, but no migration
#    actually creates `users` — the original schema was bootstrapped once via
#    create_all() before that call was commented out in main.py in favor of
#    Alembic, so replaying the full chain from empty has never actually
#    worked). This sidesteps that broken replay entirely:
docker exec phsarkasikor_backend python -c "from app.core.database import engine; from app.models.base import Base; import app.models; Base.metadata.create_all(bind=engine)"

# 3. Sync Alembic's bookkeeping to match, without replaying the chain
docker exec phsarkasikor_backend alembic stamp head

# 4. Re-seed the 4 base accounts
docker exec phsarkasikor_backend python -m app.seed
```
Note that `seed.py` doesn't re-create any product listings, so the app starts
with zero products after this until some are added again through the API/app.

> **Known issue**: the migration chain can't be replayed from an empty
> database (see step 2 above). If you want this fixed properly instead of
> worked around — e.g. by adding the missing `users` table creation to the
> right point in history, or squashing everything into one clean baseline
> migration — that's a separate, deliberate change someone should make and
> test on a throwaway DB first, not something to do casually.

---

## 🛠️ Code Compilation & Syntax Verification

Although Python is interpreted and Uvicorn hot-reloads automatically, you can manually compile files to verify syntax and catch compile errors early:

### Compile a single file
Verify syntax for a specific file:
* **Inside Docker:**
  ```bash
  docker compose exec backend python -m py_compile app/api/v1/endpoints/users.py
  ```
* **Locally (Active Venv):**
  ```bash
  python -m py_compile app/api/v1/endpoints/users.py
  ```

### Compile the entire project
Check for compilation errors across all modules:
* **Inside Docker:**
  ```bash
  docker compose exec backend python -m compileall .
  ```
* **Locally (Active Venv):**
  ```bash
  python -m compileall .
  ```

---

## 🔑 Key API Endpoints

The full, always-current list of endpoints — with request/response schemas
you can try directly — is at the [Swagger docs](http://localhost:8000/docs)
once the server is running. The table below covers only the core
auth/account flow; everything else (products, orders, contracts, chat,
cooperatives, reviews, disputes, payments, notifications, forum, and more)
lives under `app/api/v1/endpoints/` as one router file per feature area, all
mounted in `app/api/v1/api.py`.

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| **GET** | `/` | Welcome root route | No |
| **POST** | `/api/v1/users/register` | Register a new user | No |
| **POST** | `/api/v1/auth/login` | Login to retrieve JWT Access Token | No |
| **POST** | `/api/v1/auth/forgot-password` | Request a password-reset code by email | No |
| **POST** | `/api/v1/auth/reset-password` | Complete a password reset with the emailed code | No |
| **GET** | `/api/v1/users/me` | Fetch profile details of logged-in user | Yes (Bearer Token) |
