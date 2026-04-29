# FinTrack API - Project Status

**Last Updated:** April 29, 2026

## Project Overview
FinTrack API is a comprehensive financial management service for:
1. **Personal Finance Tracking** — Record and manage individual transactions
2. **Split Bill Management** — Track shared expenses and calculate who owes whom

Built with:
- **Framework:** Roda (Rack-based routing)
- **Language:** Ruby 4.0.1
- **Storage:** File-based JSON persistence transitioning to database
- **Architecture:** RESTful API with models and controllers

---

## Current Structure

```
fintrack-api/
├── app/
│   ├── controllers/app.rb       # Main API routes (Roda DSL)
│   ├── db/
│   │   └── migrations/          # Migration files (001-003)
│   ├── lib/
│   │   └── secure_db.rb         # Database security layer
│   └── models/
│       ├── account.rb           # Account model
│       ├── category.rb          # Category model
│       └── transaction.rb       # Transaction model
├── config/
│   ├── environments.rb          # Environment configuration
│   └── secrets.yml              # Secret configuration
├── db/
│   ├── local/                   # File-based persistence (JSON files)
│   └── seeds/                   # Seed data for testing
├── spec/
│   ├── integration/             # Integration tests (api_*_spec.rb)
│   └── unit/                    # Unit tests (*_spec.rb)
├── config.ru                    # Rack configuration
├── Gemfile                      # Ruby dependencies
└── require_app.rb               # Application loader
```

---

## Key Models

### 1. **Transaction** (`app/models/transaction.rb`)
- Attributes: `id`, `amount`, `date`, `title`
- File-based storage (one JSON file per transaction)
- UUID-based identifiers

### 2. **Account** (`app/models/account.rb`)
- Manages user financial accounts
- Part of new account management feature

### 3. **Category** (`app/models/category.rb`)
- Categorizes transactions
- Part of new categorization feature

---

## Important Note: Database Migration
The project is transitioning from **file-based storage to a real database**:
- Migration files exist: `001_accounts_create.rb`, `002_categories_create.rb`, `003_transactions_create.rb`
- New `secure_db.rb` module handles database security
- Models now support database persistence (in addition to or instead of file-based)

---

## Common Commands

### Setup
```bash
bundle install              # Install dependencies
```

### Running
```bash
puma                        # Start API server (http://localhost:9292)
rerun 'puma'               # Start with file watching
```

### Testing
```bash
bundle exec ruby spec/integration/api_spec.rb                    # Test transactions API
bundle exec ruby spec/integration/api_accounts_spec.rb           # Test accounts API
bundle exec ruby spec/integration/api_categories_spec.rb         # Test categories API
bundle exec ruby spec/integration/api_transactions_spec.rb       # Test transactions API
bundle exec ruby spec/unit/transactions_spec.rb                  # Test transaction model
bundle exec ruby spec/unit/accounts_spec.rb                      # Test account model
bundle exec ruby spec/unit/categories_spec.rb                    # Test category model
bundle exec ruby spec/unit/secure_db_spec.rb                     # Test database security
```

### Linting & Quality
```bash
rubocop                    # Run RuboCop linter
rubocop -a                # Fix violations automatically
bundler-audit            # Check dependencies for vulnerabilities
```

---

## API Endpoints

### Transactions (Original)
- `GET /api/v1/transactions` — List all transactions
- `GET /api/v1/transactions/:id` — Get transaction by ID
- `POST /api/v1/transactions` — Create new transaction
- `PUT /api/v1/transactions/:id` — Update transaction
- `DELETE /api/v1/transactions/:id` — Delete transaction

### Accounts (New)
- `GET /api/v1/accounts` — List all accounts
- `GET /api/v1/accounts/:id` — Get account by ID
- `POST /api/v1/accounts` — Create new account
- `PUT /api/v1/accounts/:id` — Update account
- `DELETE /api/v1/accounts/:id` — Delete account

### Categories (New)
- `GET /api/v1/categories` — List all categories
- `GET /api/v1/categories/:id` — Get category by ID
- `POST /api/v1/categories` — Create new category
- `PUT /api/v1/categories/:id` — Update category
- `DELETE /api/v1/categories/:id` — Delete category

---

## Development Notes

### Code Conventions
- All files start with `# frozen_string_literal: true`
- Classes wrapped in `FinanceTracker` module namespace
- IDs are UUIDs (generated via `SecureRandom.uuid`)
- JSON responses with status codes: 200 (GET), 201 (POST), 404 (not found), 400 (bad request)

### Testing Approach
- Uses Minitest with Rack::Test for HTTP assertions
- Seed data from YAML files in `db/seeds/`
- Tests clean up local files between runs

### Security
- `secure_db.rb` provides database security layer
- Secrets managed in `config/secrets.yml`
- Environment-specific config in `config/environments.rb`

---

## Current Development Status

**Active Areas:**
- Database migration implementation (accounts, categories, transactions)
- Security layer for database access
- Expanding API to support accounts and categories
- Building foundation for split bill functionality

**Next Steps (if applicable):**
- Finalize database migrations
- Test new account/category endpoints
- Ensure backward compatibility with transaction endpoints
- Design and implement split bill models (shared expenses, participant tracking, settlement calculations)
- Create split bill API endpoints
- Deploy to production

---

## References
See `.github/copilot-instructions.md` for detailed build and architecture documentation.
