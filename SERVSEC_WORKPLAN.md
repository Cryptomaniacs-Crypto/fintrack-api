# SERVSEC Crypto Project - User Accounts & Roles

**Objective**: Implement secure user accounts with password management, roles, and many-to-many associations.

---

## 🎯 3-Person Work Breakdown

| Person | Tasks | Files | Dependencies | Start? |
|--------|-------|-------|-------------|--------|
| **A** | Passwords + Key Stretching | `app/lib/key_stretching.rb`, `app/models/password.rb`, migration, tests | None | ✅ |
| **B** | Roles + Service Objects | `app/models/role.rb`, `app/services/`, migrations, tests | Account model exists | ✅ | 
| **C** | Many-to-Many + Seeding + API | Join tables, seeders, API routes, tests | Depends on A & B | ⏱️ |

**A & B have zero dependencies** ✓

---

## 👤 Person A: Password Security

**Create Files**:
- `app/lib/key_stretching.rb` — KeyStretching module with `hash_password()` & `verify()` using bcrypt
- `app/db/migrations/004_passwords_create.rb` — passwords table with account_id (FK), hashed_password, salt
- `app/models/password.rb` — Model with `create_for()` and `verify()` methods

**Modify**:
- `app/models/account.rb` — Add `one_to_one :password`, `set_password()`, `verify_password()`
  - NO `get_password` method (security best practice)

**Tests** (`spec/unit/password_spec.rb`):
- Hash creates different outputs (salt), verify works, cost affects timing, no plaintext in DB

**Deliverable**: 12+ tests passing, passwords hashed & salted ✓

---

## 🛡️ Person B: Roles & RBAC

**Create Files**:
- `app/db/migrations/005_roles_create.rb` — roles table (name, description, UUID)
- `app/db/migrations/006_account_roles_join.rb` — account_roles join table with unique constraint
- `app/models/role.rb` — Model with `many_to_many :accounts`, `find_or_create()`
- `app/services/account_service.rb` — `create_account()`, `authenticate()`, `find_by_email()`
- `app/services/role_service.rb` — `setup_system_roles()`, `assign_role()`, `remove_role()`

**Modify**:
- `app/models/account.rb` — Add `many_to_many :roles`, `add_role()`, `remove_role()`, `has_role?()`, `admin?()`, `member?()`

**Tests** (`spec/unit/roles_spec.rb`):
- Create/find roles, add/remove from accounts, many-to-many works, validations pass

**Deliverable**: 10+ tests, system roles (admin, member, guest), service objects ✓

---

## 🔗 Person C: Many-to-Many, Seeding & API

**Migrations**:
- `007_user_categories_join.rb` — user_categories table (account_id, category_id)
- `008_user_transactions_join.rb` — user_transactions table (account_id, transaction_id)

**Models**:
- Account: add `many_to_many :owned_categories`, `many_to_many :owned_transactions`
- Category: add `many_to_many :owner_accounts`
- Transaction: add `many_to_many :owner_accounts`
- Add `association_dependencies` for proper deletion

**Seeding** (`lib/tasks/db.rake`, `db/seeds/`):
- `001_create_roles.rb` — System roles via RoleService
- `002_create_accounts.rb` — 3 accounts (admin, member, guest) via AccountService
- `003_create_categories.rb` — Sample categories (Groceries, Utilities, etc.)
- `004_create_transactions.rb` — Sample transactions with links

**API Routes** (`app/controllers/app.rb`):
- POST `/api/v1/accounts/register` — Create account + password + default role (201 or 400)
- POST `/api/v1/accounts/login` — Authenticate account (200 or 401)
- GET `/api/v1/accounts/:id` — Get account by UUID (200 or 404)
- GET `/api/v1/accounts/:id/categories` — Get owned categories
- GET `/api/v1/accounts/:id/transactions` — Get owned transactions

**Tests** (`spec/integration/api_accounts_spec.rb`):
- Register/login validation, account retrieval, owned associations filtering

**Deliverable**: 15+ tests, full seeding workflow, 5 API endpoints ✓

---

## 📋 Quick Tasks Checklist

### Day 1 (All Start)
- [ ] **A**: KeyStretching module + Password model + migration + tests
- [ ] **B**: Role model + join table + Account role methods + service objects + tests  
- [ ] **C**: Plan join tables, start many-to-many design

### Day 2 (Integration)
- [ ] **A**: ✅ Complete password implementation
- [ ] **B**: ✅ Complete roles + services
- [ ] **C**: Implement many-to-many + seeding + API routes + tests

### Day 3 (Finalize)
- [ ] All: Run full suite: `bundle exec ruby spec/spec_helper.rb`
- [ ] All: RuboCop: `rubocop -a`
- [ ] All: Seed works: `rake db:migrate && rake db:seed`
- [ ] All: Verify API endpoints respond correctly

---

## ✅ Verification Checklist

- [ ] Tests pass: `bundle exec ruby spec/spec_helper.rb`
- [ ] No RuboCop violations: `rubocop`
- [ ] Passwords never exposed in API responses
- [ ] Passwords salted & stretched (bcrypt)
- [ ] Roles properly assigned & checked
- [ ] Many-to-Many bidirectional
- [ ] Service objects reused in controllers/tests/seeders
- [ ] `bundle install && rake db:migrate && rake db:seed` works end-to-end

