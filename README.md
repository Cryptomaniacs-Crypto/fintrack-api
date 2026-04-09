# FinTrack API

API to manage financial transactions, track spending, and monitor account activity

## Routes

All routes return JSON

- GET `/`: Root route shows if Web API is running
- GET `api/v1/transactions/`: returns all transaction IDs
- GET `api/v1/transactions/[ID]`: returns details about a single transaction with given ID
- POST `api/v1/transactions/`: creates a new transaction

## Install

Install this API by cloning the repository and installing required gems from `Gemfile.lock`:

```shell
bundle install
```

## Test

Run the test script:

```shell
ruby spec/api_spec.rb
```

## Execute

Run this API using:

```shell
puma
```