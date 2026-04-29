# TASK 2: PII Security & Search Services

**Owner:** Person 2  
**Status:** Waiting for Task 1  
**Priority:** High  
**Depends On:** Task 1 (Account model with password fields)

---

## Objectives

1. Implement email/phone/PII encryption with `*_secure` and `*_hash` columns
2. Create search service objects to query accounts by PII
3. Build API routes to retrieve accounts by PII
4. Write integration tests for search functionality
5. Ensure confidentiality while maintaining searchability

---

## Requirements

### 1. Update Account Migration
**File:** `app/db/migrations/001_accounts_create.rb` (UPDATE)

Add these columns to the accounts table:

```ruby
# PII Fields with Encryption Support
String :email_secure, null: false          # Encrypted email
String :email_hash, null: false            # One-way hash for searching
String :phone_secure, null: false          # Encrypted phone (if needed)
String :phone_hash, null: false            # One-way hash for searching
```

**Migration Update:**
```ruby
Sequel.migration do
  up do
    create_table :accounts do
      primary_key :id
      
      String :username, null: false, unique: true
      String :email, null: false, unique: true
      
      # Password fields (from Task 1)
      String :password_salt, null: false
      String :hashed_password, null: false
      
      # PII Encryption (Task 2)
      String :email_secure, null: false
      String :email_hash, null: false
      String :phone_secure
      String :phone_hash
      
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
  
  down do
    drop_table :accounts
  end
end
```

---

### 2. PII Encryption Module
**File:** `app/lib/pii_encryption.rb`

```ruby
# frozen_string_literal: true

module FinanceTracker
  module PIIEncryption
    # Encrypt PII using AES-256-GCM
    # Hash PII using SHA-256 for searching (one-way, not reversible)
    
    def self.encrypt(data, key = nil)
      # Use ENV['PII_ENCRYPTION_KEY'] or provided key
      # Algorithm: AES-256-GCM
      # Return: encrypted data as Base64
    end
    
    def self.decrypt(encrypted_data, key = nil)
      # Decrypt using same key and algorithm
      # Return: original plaintext
    end
    
    def self.hash_for_search(data)
      # One-way hash for searching (cannot decrypt)
      # Use SHA-256
      # Return: hash as hex string
      # Example: Digest::SHA256.hexdigest(data)
    end
  end
end
```

**Configuration Notes:**
- Store encryption key in `ENV['PII_ENCRYPTION_KEY']` (12+ random characters)
- Use `SecureRandom.random_bytes(32)` to generate key
- Store key in `.env` or secrets manager, NOT in code

---

### 3. Account Model Enhancements
**File:** `app/models/account.rb` (UPDATE)

```ruby
# frozen_string_literal: true

module FinanceTracker
  class Account < Sequel::Model
    # Existing code from Task 1...
    
    # PII Encryption Methods
    
    def email=(email)
      self[:email] = email
      self[:email_secure] = PIIEncryption.encrypt(email)
      self[:email_hash] = PIIEncryption.hash_for_search(email)
    end
    
    def email
      # Return decrypted email only to authorized users
      # For now, return from email_secure (stored plaintext)
      self[:email]
    end
    
    def phone=(phone)
      return if phone.nil?
      self[:phone_secure] = PIIEncryption.encrypt(phone)
      self[:phone_hash] = PIIEncryption.hash_for_search(phone)
    end
    
    def phone
      # Return decrypted phone only to authorized users
      # Implement in Task 3 with authorization
      self[:phone_secure]
    end
    
    # Class method for searching by email (without exposing hash)
    def self.find_by_email(email)
      email_hash = PIIEncryption.hash_for_search(email)
      where(email_hash: email_hash).first
    end
    
    def self.find_by_phone(phone)
      phone_hash = PIIEncryption.hash_for_search(phone)
      where(phone_hash: phone_hash).first
    end
  end
end
```

---

### 4. Search Service Objects
**File:** `app/services/account_search_service.rb`

```ruby
# frozen_string_literal: true

module FinanceTracker
  class AccountSearchService
    def initialize(query_type, query_value)
      @query_type = query_type  # :email, :phone, :username
      @query_value = query_value
    end
    
    def call
      case @query_type
      when :email
        Account.find_by_email(@query_value)
      when :phone
        Account.find_by_phone(@query_value)
      when :username
        Account[:username => @query_value]
      else
        raise "Invalid query type: #{@query_type}"
      end
    end
    
    # Alias for readability
    def find
      call
    end
  end
end
```

**Usage:**
```ruby
service = FinanceTracker::AccountSearchService.new(:email, 'user@example.com')
account = service.find
```

---

### 5. API Routes
**File:** `app/controllers/app.rb` (UPDATE)

Add these routes to existing Roda app:

```ruby
# GET /api/v1/accounts/search?type=email&value=user@example.com
route.get 'search' do
  type = route.params['type'].to_sym    # :email, :phone, :username
  value = route.params['value']
  
  if type.nil? || value.nil?
    [400, { 'Content-Type' => 'application/json' }, 
     [{ message: 'Missing type or value' }.to_json]]
  end
  
  service = AccountSearchService.new(type, value)
  account = service.find
  
  if account
    [200, { 'Content-Type' => 'application/json' }, 
     [account_to_json(account).to_json]]
  else
    [404, { 'Content-Type' => 'application/json' }, 
     [{ message: 'Account not found' }.to_json]]
  end
end

# Helper method
def account_to_json(account)
  {
    id: account.id,
    username: account.username,
    email: account.email,
    phone: account.phone,
    created_at: account.created_at
  }
end
```

---

## Testing Requirements

**File:** `spec/integration/api_search_spec.rb`

```ruby
# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Account Search API' do
  before do
    FinanceTracker::Account.delete
    
    @account = FinanceTracker::Account.create(
      username: 'testuser',
      email: 'test@example.com',
      phone: '555-1234'
    )
    @account.set_password('SecurePassword123!')
    @account.save
  end
  
  describe 'GET /api/v1/accounts/search' do
    it 'finds account by email' do
      get '/api/v1/accounts/search', 
          type: 'email', 
          value: 'test@example.com'
      
      _(last_response.status).must_equal 200
      result = JSON.parse(last_response.body)
      result['username'].must_equal 'testuser'
      result['email'].must_equal 'test@example.com'
    end
    
    it 'finds account by phone' do
      get '/api/v1/accounts/search', 
          type: 'phone', 
          value: '555-1234'
      
      _(last_response.status).must_equal 200
      result = JSON.parse(last_response.body)
      result['username'].must_equal 'testuser'
    end
    
    it 'finds account by username' do
      get '/api/v1/accounts/search', 
          type: 'username', 
          value: 'testuser'
      
      _(last_response.status).must_equal 200
      result = JSON.parse(last_response.body)
      result['email'].must_equal 'test@example.com'
    end
    
    it 'returns 404 for non-existent account' do
      get '/api/v1/accounts/search', 
          type: 'email', 
          value: 'nonexistent@example.com'
      
      _(last_response.status).must_equal 404
    end
    
    it 'returns 400 for missing parameters' do
      get '/api/v1/accounts/search', type: 'email'
      
      _(last_response.status).must_equal 400
    end
  end
end

describe FinanceTracker::AccountSearchService do
  before do
    FinanceTracker::Account.delete
    
    @account = FinanceTracker::Account.create(
      username: 'testuser',
      email: 'test@example.com',
      phone: '555-1234'
    )
  end
  
  describe '#find' do
    it 'finds by email' do
      service = FinanceTracker::AccountSearchService.new(
        :email, 
        'test@example.com'
      )
      result = service.find
      
      result.must_equal @account
    end
    
    it 'finds by phone' do
      service = FinanceTracker::AccountSearchService.new(
        :phone, 
        '555-1234'
      )
      result = service.find
      
      result.must_equal @account
    end
    
    it 'finds by username' do
      service = FinanceTracker::AccountSearchService.new(
        :username, 
        'testuser'
      )
      result = service.find
      
      result.must_equal @account
    end
    
    it 'returns nil for non-existent account' do
      service = FinanceTracker::AccountSearchService.new(
        :email, 
        'nonexistent@example.com'
      )
      result = service.find
      
      _(result).must_be_nil
    end
  end
end
```

**File:** `spec/unit/pii_encryption_spec.rb`

```ruby
# frozen_string_literal: true

require_relative '../spec_helper'

describe FinanceTracker::PIIEncryption do
  describe '.encrypt and .decrypt' do
    it 'encrypts and decrypts data correctly' do
      original = 'test@example.com'
      encrypted = FinanceTracker::PIIEncryption.encrypt(original)
      decrypted = FinanceTracker::PIIEncryption.decrypt(encrypted)
      
      decrypted.must_equal original
    end
    
    it 'produces different ciphertexts for same plaintext (IV randomization)' do
      original = 'test@example.com'
      encrypted1 = FinanceTracker::PIIEncryption.encrypt(original)
      encrypted2 = FinanceTracker::PIIEncryption.encrypt(original)
      
      # Ciphertexts should be different (different IVs)
      encrypted1.wont_equal encrypted2
      
      # But both decrypt to same plaintext
      FinanceTracker::PIIEncryption.decrypt(encrypted1).must_equal original
      FinanceTracker::PIIEncryption.decrypt(encrypted2).must_equal original
    end
  end
  
  describe '.hash_for_search' do
    it 'produces consistent hash for same input' do
      data = 'test@example.com'
      hash1 = FinanceTracker::PIIEncryption.hash_for_search(data)
      hash2 = FinanceTracker::PIIEncryption.hash_for_search(data)
      
      hash1.must_equal hash2
    end
    
    it 'produces different hashes for different inputs' do
      hash1 = FinanceTracker::PIIEncryption.hash_for_search('email1@example.com')
      hash2 = FinanceTracker::PIIEncryption.hash_for_search('email2@example.com')
      
      hash1.wont_equal hash2
    end
    
    it 'is one-way (not reversible)' do
      data = 'test@example.com'
      hash = FinanceTracker::PIIEncryption.hash_for_search(data)
      
      # Hash should be different from original
      hash.wont_equal data
    end
  end
end
```

---

## Deliverables Checklist

- [ ] `app/lib/pii_encryption.rb` — PII encryption/decryption module
- [ ] `app/services/account_search_service.rb` — Search service object
- [ ] `app/models/account.rb` — Updated with email/phone encryption methods
- [ ] `app/controllers/app.rb` — Updated with `/api/v1/accounts/search` route
- [ ] Updated migration with email_secure, email_hash, phone_secure, phone_hash columns
- [ ] `spec/integration/api_search_spec.rb` — All integration tests passing
- [ ] `spec/unit/pii_encryption_spec.rb` — All unit tests passing

---

## Key Security Points

✅ **Two-Column Strategy:**
- `*_secure` column: Encrypted data (reversible)
- `*_hash` column: One-way hash (searchable, not reversible)

✅ **Encryption:**
- Algorithm: AES-256-GCM
- Key stored in environment variable
- IV: Random (different for each encryption)

✅ **Searching:**
- Hash the search value using same hash function
- Query by hash (not by encrypted value)
- Hashes are deterministic (same input = same hash)

✅ **No Exposure:**
- Never log encrypted values
- Never return encrypted values in API
- Decrypt only when necessary for authorized users

---

## Configuration

Add to `.env` or environment setup:

```bash
PII_ENCRYPTION_KEY=your_random_32_character_key_here
```

Generate a secure key:
```bash
ruby -e "require 'securerandom'; puts SecureRandom.random_bytes(32).unpack('H*').first"
```

---

## Performance Note

- Hashing is fast (milliseconds)
- Encryption/decryption adds minimal overhead
- Search by hash is as fast as regular DB query
- Consider database indexes on `*_hash` columns for large datasets
