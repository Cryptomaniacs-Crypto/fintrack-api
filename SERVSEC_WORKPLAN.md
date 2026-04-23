# SERVSEC Database Hardening - 3-Person Work Breakdown

## Project Overview
**Objective**: Harden the FinTrack API database against common vulnerabilities including mass assignment, SQL injection, and unauthorized data access.

**Current Architecture**:
- Ruby 4.0.2, Sequel ORM, SQLite3
- 3 Models: Account, Category, Transaction
- 3 REST API endpoints: `/api/v1/accounts`, `/api/v1/categories`, `/api/v1/transactions`
- Minitest with Rack::Test for testing

---

## 🎯 MINIMUM OVERLAP STRATEGY

| Person | Tasks | Files They Own | Dependencies | Can Start Day 1? |
|--------|-------|-----------------|-------------|------------------|
| **A** | Task 0 (Setup) + Task 4a (Encryption library) | `config/environments.rb`, `app/lib/secure_db.rb`, `config/example-secrets.yml` | None | ✅ YES |
| **B** | Task 1 (Mass assignment) + Task 5 (Logging) | `app/models/*.rb` (whitelist), `spec/*_spec.rb` (MA tests) | **None** | ✅ YES |
| **C** | Task 2 (SQL injection) + Task 3 (UUIDs) [**Task 4b last**] | `app/controllers/app.rb`, `app/db/migrations/*`, `spec/api_spec.rb` | Only for Task 4b | ✅ YES (complete Tasks 2-3 first) |

**Person B has ZERO dependencies** ✓ | **Person C can work independently for 80% of their tasks** ✓

---

## 📋 Person A: Infrastructure, Dependencies & Encryption Foundation

### Task 0: Ruby & Dependencies Setup
- [ ] Verify Ruby version is 4.0.2 (check `.ruby-version`)
- [ ] Run `bundle update` to update all gems
- [ ] Run `bundler-audit` to check for security vulnerabilities
- [ ] Verify all tests pass: `bundle exec ruby spec/spec_helper.rb`

### Task 4a: Encryption Library & Secrets Management (Blocking task for Person C)
- [ ] Create `app/lib/secure_db.rb` - SecureDB encryption library class:
  - Implement `encrypt(value)` method using RbNaCl
  - Implement `decrypt(value)` method
  - Handle key loading from environment
- [ ] Create `config/example-secrets.yml` template:
  ```yaml
  development:
    DATABASE_URL: sqlite://db/local/development.db
    DB_ENCRYPTION_KEY: [example-base64-key]
  
  test:
    DATABASE_URL: sqlite://db/local/test.db
    DB_ENCRYPTION_KEY: [example-base64-key]
  ```
- [ ] Update `.gitignore` to exclude `config/secrets.yml`
- [ ] Generate encryption keys for development and test environments
- [ ] Update `config/environments.rb` to load DB_ENCRYPTION_KEY from Figaro

### Deliverables
- ✅ SecureDB library (`app/lib/secure_db.rb`) ready for Person C to use
- ✅ Example secrets file for developers
- ✅ Encryption keys generated for dev/test
- ✅ `.gitignore` updated
- **→ Person C can now proceed with Task 4b**

---

## 👤 Person B: Input Validation, Mass Assignment Protection & Logging

### Task 1: Prevent Mass Assignment Vulnerabilities
- [ ] Modify `app/models/account.rb`:
  - Add `set_allowed_columns` (whitelist: `:name`, `:account_number`, `:balance`)
  - Implement validation to prevent non-whitelisted attributes
- [ ] Modify `app/models/category.rb`:
  - Add `set_allowed_columns` (whitelist: `:name`, `:description`)
- [ ] Modify `app/models/transaction.rb`:
  - Add `set_allowed_columns` (whitelist: `:title`, `:amount`, `:transaction_date`, `:note`, `:account_id`, `:category_id`)
- [ ] Update `app/controllers/app.rb` POST routes to catch mass assignment errors:
  - Return 400 Bad Request with message: `{ message: "Forbidden attributes: [keys]" }`
  - Log the attempt (see Task 5)

### Task 1: Test Mass Assignment Prevention
- [ ] Create tests in `spec/accounts_spec.rb`:
  - Test POST with forbidden field (e.g., `id`, `created_at`) → expects 400
  - Test POST with valid whitelist fields → expects 201
- [ ] Create tests in `spec/categories_spec.rb`:
  - Same pattern as accounts
- [ ] Create tests in `spec/transactions_spec.rb`:
  - Same pattern, include testing foreign keys in whitelist

### Task 5: Add Logging Infrastructure (No overlap - unique to Person B)
- [ ] Add logger initialization in `config/environments.rb`:
  - Create logger instance that writes to `log/` directory (create if needed)
  - Include timestamp, severity, and message format
- [ ] Add mass assignment error logging in controller:
  - Log: `"[WARN] Mass assignment attempt: route=?, attempted_keys=[...], time=?"`
  - Do NOT log actual values, only the attempted field names
  - Use logger.warn for clarity
- [ ] Add unknown error logging for 500 responses:
  - Log: `"[ERROR] Unexpected error: #{error.class} - #{error.message} - #{backtrace}"`
  - Use logger.error
- [ ] Create `log/` directory and add to `.gitignore`:
  - Add `log/*.log` to ignore

### Deliverables
- ✅ Mass assignment whitelists in all 3 models
- ✅ 400 Bad Request responses for mass assignment attempts  
- ✅ 6+ test cases for mass assignment prevention
- ✅ Logging infrastructure with configuration
- ✅ Mass assignment attempt logs with sanitized keys
- ✅ Error logging for unexpected exceptions
- **No dependencies on other team members** ✓

---

## 🔐 Person C: SQL Injection Prevention, UUIDs & Sensitive Data Encryption

### Task 2: Prevent SQL Injection Attacks (INDEPENDENT - Start Day 1)
- [ ] Review `app/controllers/app.rb` for all user input in queries
- [ ] Convert dynamic string concatenation to parameterized queries using Sequel:
  - Example: Change `where("id = '#{id}'")` to `first(id: id)` or `where(id: id)`
  - Affected routes: All GET by ID, POST with body parameters
- [ ] Create SQL injection tests in `spec/api_spec.rb`:
  - Test Account GET with SQL payload: `GET /api/v1/accounts/1' OR '1'='1`
  - Test Category POST with SQL payload in name field
  - Test Transaction GET with SQL payload
  - All should return 400 or 404, never execute injected SQL

### Task 3: UUID Implementation (INDEPENDENT - Start Day 1)
- [ ] Modify migrations:
  - `001_accounts_create.rb`: Change `primary_key :id` to use UUID type
  - `002_categories_create.rb`: Same UUID change
  - `003_transactions_create.rb`: Same UUID change, update foreign keys to UUID
- [ ] Update models to use UUID plugin:
  - Add `plugin :uuid` to Account, Category, Transaction models
- [ ] Write UUID tests:
  - Verify created records have valid UUID primary keys
  - Verify API returns UUID in responses
  - Test GET with UUID IDs works correctly

### Task 4b: Encrypt Sensitive Columns (BLOCKED - Requires Person A's Task 4a)
**⏸️ DO NOT START UNTIL Person A completes Task 4a**

**Optional Early Approach** (to minimize waiting):
- [ ] Create a placeholder `app/lib/secure_db.rb` stub in your branch with basic methods:
  ```ruby
  module FinanceTracker
    class SecureDB
      def self.encrypt(value)
        value  # placeholder - will be replaced when A completes
      end
      
      def self.decrypt(value)
        value  # placeholder - will be replaced when A completes
      end
    end
  end
  ```
- [ ] This lets you complete encryption integration without waiting for Person A

**Full Implementation** (after Person A completes Task 4a):
- [ ] Team decision: Which columns are most sensitive?
  - **Account**: `account_number` (PII - MOST SENSITIVE)
  - **Category**: None (optional)
  - **Transaction**: `note` (potentially sensitive)
- [ ] Modify migrations:
  - `001_accounts_create.rb`: Rename `account_number` → `secure_account_number`
  - `003_transactions_create.rb`: Rename `note` → `secure_note`
  - **Note**: Database must be dropped/remigrated after migration changes
- [ ] Add reader/writer methods in models using SecureDB (from Person A):
  - In Account:
    ```ruby
    def account_number=(value)
      self.secure_account_number = FinanceTracker::SecureDB.encrypt(value) if value
    end
    
    def account_number
      FinanceTracker::SecureDB.decrypt(self.secure_account_number) if self.secure_account_number
    end
    ```
  - In Transaction: Same pattern for `note`
- [ ] Update model `to_json` methods to expose decrypted values (transparent to API)
- [ ] Replace placeholder SecureDB stub with Person A's real implementation
- [ ] Create encryption tests:
  - Verify encrypted data in DB cannot be read as plaintext
  - Verify decryption on retrieval works
  - Verify to_json exposes decrypted values

### Deliverables
- ✅ All user input properly parameterized (no SQL string concatenation)
- ✅ 5+ SQL injection test cases covering all routes
- ✅ UUID primary keys in all 3 tables
- ✅ UUID plugin in all 3 models
- ✅ 4+ UUID functionality tests
- ✅ Encrypted columns with reader/writer methods
- ✅ Migration column renames for sensitive data
- ✅ 3+ encryption functionality tests
- **Task 2 & 3**: Zero dependencies ✓
- **Task 4b**: Depends only on Person A Task 4a (can stub placeholder)

---

## 🎯 Task Dependencies & Workflow

### Independence Matrix
```
ZERO DEPENDENCIES:
- Person A: Task 0 → Task 4a [BLOCKING]
- Person B: Task 1 + Task 5 [100% INDEPENDENT] ✅

MOSTLY INDEPENDENT:
- Person C: Task 2 + Task 3 [100% INDEPENDENT] ✅
           Task 4b [BLOCKED by A's Task 4a - can use stub pattern]
```

**Person C Early Strategy** (Recommended to minimize wait time):
1. Start with Task 2 (SQL injection) Day 1 ✓
2. Continue with Task 3 (UUIDs) Day 1-2 ✓  
3. Create placeholder SecureDB stub while waiting for Person A
4. Implement Task 4b with stub, swap in real encryption when Person A done

### File Ownership (Zero Conflicts)
- **Person A only**: `config/environments.rb`, `app/lib/secure_db.rb`, `config/example-secrets.yml`
- **Person B only**: `app/models/*.rb` (mass assignment), `spec/*_spec.rb` (mass assignment tests)
- **Person C only**: `app/controllers/app.rb`, `app/db/migrations/*`, `spec/api_spec.rb`

---

## 📅 Timeline Suggestion

### Phase 1 (Day 1) - All 3 Start Together (NO WAITING)
- **Person A**: 
  - ✅ Task 0: Update Ruby & dependencies (quick)
  - 🔄 Task 4a: Build SecureDB encryption library
  
- **Person B** (ZERO DEPENDENCIES):
  - ✅ Task 1: Implement mass assignment prevention + tests
  - 🔄 Task 5: Add logging infrastructure
  
- **Person C** (ZERO BLOCKING):
  - ✅ Task 2: SQL injection prevention + tests  
  - 🔄 Task 3: UUID implementation + tests

### Phase 2 (Day 2-3) - Full Parallelization
- **Person A finishes** Task 4a → Passes SecureDB to Person C
- **Person B** *(continues independently)* → Finishes Task 1 & 5
- **Person C** *(continues independently)* → Finishes Tasks 2 & 3, then upgrades Task 4b stub with real encryption

### Phase 3 (Day 4) - Integration & Final Testing
- All tasks complete
- Run full test suite
- Final code review and verification

---

## 🎯 Integration Checklist (All Team Members)

After individual tasks:
- [ ] Run full test suite: `bundle exec minitest spec/**/*_spec.rb`
- [ ] Run RuboCop: `rubocop`
- [ ] Verify API starts: `puma` on http://localhost:9292
- [ ] Test each endpoint manually with curl or Postman
- [ ] Verify database encryption keys are NOT in git
- [ ] Verify `.gitignore` includes secrets and logs
- [ ] Document any schema changes in README.md

---

## ⚠️ Important Notes

1. **Database Migrations**: Changing column names requires dropping and remigrating:
   ```bash
   rake db:drop
   rake db:migrate
   ```

2. **Secrets Management**: After Person A creates encryption keys:
   - Copy `config/example-secrets.yml` → `config/secrets.yml`
   - Update DB_ENCRYPTION_KEY in secrets.yml
   - Never commit `config/secrets.yml`

3. **Testing**: All teams should run tests after each major change:
   ```bash
   bundle exec ruby spec/spec_helper.rb
   ```

4. **Code Style**: Ensure RuboCop passes:
   ```bash
   rubocop -a  # auto-fix issues
   ```

---

