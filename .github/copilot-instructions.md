# FinTrack API - Copilot Instructions

## Build & Test

**Environment:**
- Ruby 4.0.1 (see `.ruby-version`)
- Uses Roda framework (lightweight Rack-based web framework)

**Setup & Installation:**
```bash
bundle install
```

**Run Tests:**
```bash
# Run full test suite
bundle exec ruby spec/api_spec.rb

# Run a single test (by description pattern)
bundle exec ruby spec/api_spec.rb -n "/pattern/"
```

**Run the Server:**
```bash
# Start the API server (runs on http://localhost:9292 by default)
puma

# With file watching for development
rerun 'puma'
```

**Linting & Code Quality:**
```bash
# Run RuboCop (with minitest plugin)
rubocop

# Fix RuboCop violations automatically
rubocop -a

# Check for dependency vulnerabilities
bundler-audit
```

## Architecture

**Framework:**
- Roda is a lightweight routing framework built on Rack
- Routes are defined using a DSL in `app/controllers/app.rb`
- No database layer—transactions are stored as JSON files in `db/local/`

**Structure:**
- `app/controllers/app.rb` — Main API controller with all route definitions
- `app/models/transaction.rb` — Transaction model with file-based persistence
- `spec/api_spec.rb` — Integration tests using Minitest and Rack::Test
- `db/seeds/transaction_seed.yml` — Seed data for testing

**Data Flow:**
1. HTTP requests enter via Roda routes (`/api/v1/transactions`)
2. Controller parses JSON request bodies
3. Transaction model handles file I/O (UUID-keyed `.txt` files in `db/local/`)
4. Responses are JSON-serialized

## Key Conventions

**Code Style:**
- All files start with `# frozen_string_literal: true`
- Namespace: `FinanceTracker` module wraps all classes
- Target Ruby version 4.0 (enforced by RuboCop in `.rubocop.yml`)

**Naming:**
- Transaction IDs are UUIDs (generated via `SecureRandom.uuid`)
- File storage uses UUIDs as basenames (e.g., `6f785f1f-1049-4f54-a271-5527284dcf9a.txt`)

**Testing:**
- Use Minitest with Rack::Test for HTTP assertions
- Test files use `describe` blocks and assertion methods (`must_equal`, etc.)
- Tests clean up `db/local/*.txt` files before running (see `before` hook in `spec/api_spec.rb`)
- YAML seed data in `db/seeds/transaction_seed.yml` provides consistent test data

**API Responses:**
- All responses are JSON (Content-Type: application/json)
- Status codes: 200 (GET/found), 201 (created), 404 (not found), 400 (bad request)
- Error responses include a `message` field

**Transaction Model:**
- Attributes: `id`, `amount`, `date`, `title`
- Stored as individual JSON files in `db/local/` (one file per transaction)
- File contents are raw JSON (no headers or metadata)
