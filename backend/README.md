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

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| **GET** | `/` | Welcome root route | No |
| **POST** | `/api/v1/users/register` | Register a new user | No |
| **POST** | `/api/v1/auth/login` | Login to retrieve JWT Access Token | No |
| **GET** | `/api/v1/users/me` | Fetch profile details of logged-in user | Yes (Bearer Token) |
