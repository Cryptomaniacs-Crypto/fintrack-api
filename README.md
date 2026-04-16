# FinTrack API

API to manage transactions, accounts, and categories for personal finance tracking.

## Routes

All routes return JSON.

- GET  `/`: Root route shows if Web API is running
- GET  `api/v1/transactions`: Get list of all transactions
- POST `api/v1/transactions`: Create a new transaction
- GET  `api/v1/transactions/[transaction_id]`: Get a single transaction
- GET  `api/v1/transactions/[transaction_id]/accounts`: Get list of accounts for a transaction
- POST `api/v1/transactions/[transaction_id]/accounts`: Create a new account for a transaction
- GET  `api/v1/transactions/[transaction_id]/accounts/[account_id]`: Get a single account
- GET  `api/v1/transactions/[transaction_id]/categories`: Get list of categories for a transaction
- POST `api/v1/transactions/[transaction_id]/categories`: Create a new category for a transaction
- GET  `api/v1/transactions/[transaction_id]/categories/[category_id]`: Get a single category

## Install

Install this API by cloning the repository and using bundler to install gems from `Gemfile.lock`:

```shell
bundle install
```

Create `config/secrets.yml` from this template:

```yml
---
development:
  DATABASE_URL: sqlite://db/local/development.db

test:
  DATABASE_URL: sqlite://db/local/test.db

production:
  DATABASE_URL: <do not set - assigned by production service>
```

Setup development database once:

```shell
rake db:migrate
```

## Execute

Run this API using:

```shell
puma
```

## Test

Setup test database once:

```shell
RACK_ENV=test rake db:migrate
```

Run the full test suite:

```shell
rake spec
```

## Release check

Before submitting pull requests, check specs, style, and dependency audits:

```shell
rake release_check
```