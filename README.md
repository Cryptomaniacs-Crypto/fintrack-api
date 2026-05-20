# FinTrack API

API to manage transactions, accounts, and categories for personal finance tracking.

## Routes

All routes return JSON.

- GET  `/`: Root route shows if Web API is running
- GET  `api/v1/transactions`: Get list of all transactions
- POST `api/v1/transactions`: Create a new transaction
- GET  `api/v1/transactions/[transaction_id]`: Get a single transaction
- GET  `api/v1/wallets?current_account_id=[account_id]`: Get payment methods for an account
- POST `api/v1/wallets`: Create a payment method for current account
- GET  `api/v1/wallets/[wallet_id]?current_account_id=[account_id]`: Get a single payment method
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

Setup development database once:

```shell
rake db:migrate
```

## Execute

Run this API using:

```shell
puma
```

## Security and deployment configuration

The API does not manage browser sessions; session encryption and Redis session
storage are handled by `fintrack-app`.

Required API environment variables are listed in `config/secrets-example.yml`:

- `DATABASE_URL`
- `SECURE_DB_KEY`
- `SECURE_HASH_KEY`
- `SECURE_SCHEME` (`HTTP` for local/test, `HTTPS` for production)

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