# TASK 1: Password Security & Account Model

**Owner:** Person 1  
**Status:** Not Started  
**Priority:** High (Blocking)

---

## Objectives

1. Create `KeyStretching` module for key-stretching algorithm
2. Create `Password` model to handle salted, hashed passwords
3. Create Account migration with `hashed_password` field
4. Add `set_password()` and `check_password()` methods to Account model
5. Write unit tests for password handling

---

## Requirements

### 1. KeyStretching Module
**File:** `app/lib/key_stretching.rb`

```ruby
# frozen_string_literal: true

module FinanceTracker
  module KeyStretching
    # Use PBKDF2 with SHA256
    # Iterations: 100,000+ (industry standard)
    # Salt: SecureRandom (at least 16 bytes)
    
    def self.hash_password(password, salt = nil)
      # Generate salt if not provided
      salt ||= SecureRandom.random_bytes(16)
      
      # Return both salt and hash
      # { salt: salt_base64, hash: hash_base64 }
    end
    
    def self.verify_password(password, salt, hash)
      # Verify password against stored hash
      # Return boolean
    end
  end
end
```

**Implementation Details:**
- Use Ruby's built-in `OpenSSL::PKCS5.pbkdf2_hmac`
- Iterations: 100,000 (configurable)
- Algorithm: SHA-256
- Salt: 16+ random bytes
- Return hashes and salts as Base64

---

### 2. Password Model (Alternative: Concern)
**File:** `app/models/password.rb`

```ruby
# frozen_string_literal: true

module FinanceTracker
  class Password
    attr_reader :salt, :hashed_password
    
    def initialize(password = nil, salt = nil, hashed_password = nil)
      # Store raw password during creation
      # Store salt + hash when loading from DB
    end
    
    def set(password)
      # Hash password with new salt
      # Update @salt and @hashed_password
    end
    
    def verify(password)
      # Verify password against stored hash
    end
    
    def to_h
      # Return { salt: ..., hashed_password: ... } for DB storage
    end
  end
end
```

---

### 3. Account Migration
**File:** `app/db/migrations/001_accounts_create.rb`

```ruby
# frozen_string_literal: true

Sequel.migration do
  up do
    create_table :accounts do
      primary_key :id
      
      String :username, null: false, unique: true
      String :email, null: false, unique: true
      
      # Password fields
      String :password_salt, null: false     # Base64 encoded
      String :hashed_password, null: false   # Base64 encoded
      
      # Metadata
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

### 4. Account Model
**File:** `app/models/account.rb`

```ruby
# frozen_string_literal: true

module FinanceTracker
  class Account < Sequel::Model
    # Associations will be added in Task 3
    
    def set_password(password)
      # Use KeyStretching module to hash password
      # Store salt and hash in DB columns
      # Update password_salt and hashed_password
    end
    
    def check_password(password)
      # Use KeyStretching module to verify
      # Return boolean (never expose hash)
    end
    
    # IMPORTANT: Never expose raw password or hash
    # No password getter method!
    
    def password=(password)
      set_password(password)
    end
    
    def password
      raise "Password is write-only"
    end
  end
end
```

---

## Testing Requirements

**File:** `spec/unit/password_security_spec.rb`

```ruby
# frozen_string_literal: true

require_relative '../spec_helper'

describe FinanceTracker::KeyStretching do
  describe '.hash_password' do
    it 'generates a salt and hash' do
      password = 'SecurePassword123!'
      result = FinanceTracker::KeyStretching.hash_password(password)
      
      result.must_be_instance_of Hash
      result[:salt].wont_be_nil
      result[:hash].wont_be_nil
    end
    
    it 'generates different hashes for same password (due to random salt)' do
      password = 'SecurePassword123!'
      hash1 = FinanceTracker::KeyStretching.hash_password(password)
      hash2 = FinanceTracker::KeyStretching.hash_password(password)
      
      hash1[:hash].wont_equal hash2[:hash]
    end
    
    it 'accepts existing salt' do
      password = 'SecurePassword123!'
      result1 = FinanceTracker::KeyStretching.hash_password(password)
      result2 = FinanceTracker::KeyStretching.hash_password(password, result1[:salt])
      
      result1[:hash].must_equal result2[:hash]
    end
  end
  
  describe '.verify_password' do
    it 'returns true for correct password' do
      password = 'SecurePassword123!'
      hashed = FinanceTracker::KeyStretching.hash_password(password)
      
      verified = FinanceTracker::KeyStretching.verify_password(
        password, 
        hashed[:salt], 
        hashed[:hash]
      )
      
      verified.must_equal true
    end
    
    it 'returns false for incorrect password' do
      password = 'SecurePassword123!'
      wrong_password = 'WrongPassword456!'
      hashed = FinanceTracker::KeyStretching.hash_password(password)
      
      verified = FinanceTracker::KeyStretching.verify_password(
        wrong_password, 
        hashed[:salt], 
        hashed[:hash]
      )
      
      verified.must_equal false
    end
  end
end

describe FinanceTracker::Account do
  before do
    # Clear accounts before each test
    FinanceTracker::Account.delete
  end
  
  describe '#set_password' do
    it 'stores hashed password and salt' do
      account = FinanceTracker::Account.create(
        username: 'testuser',
        email: 'test@example.com'
      )
      account.set_password('SecurePassword123!')
      
      account.password_salt.wont_be_nil
      account.hashed_password.wont_be_nil
    end
  end
  
  describe '#check_password' do
    it 'returns true for correct password' do
      account = FinanceTracker::Account.create(
        username: 'testuser',
        email: 'test@example.com'
      )
      account.set_password('SecurePassword123!')
      
      account.check_password('SecurePassword123!').must_equal true
    end
    
    it 'returns false for incorrect password' do
      account = FinanceTracker::Account.create(
        username: 'testuser',
        email: 'test@example.com'
      )
      account.set_password('SecurePassword123!')
      
      account.check_password('WrongPassword456!').must_equal false
    end
  end
  
  describe 'password access control' do
    it 'prevents reading password' do
      account = FinanceTracker::Account.create(
        username: 'testuser',
        email: 'test@example.com',
        password: 'SecurePassword123!'
      )
      
      (_ { account.password }).must_raise RuntimeError
    end
  end
end
```

---

## Deliverables Checklist

- [ ] `app/lib/key_stretching.rb` — KeyStretching module with `hash_password` and `verify_password`
- [ ] `app/models/account.rb` — Account model with `set_password()` and `check_password()`
- [ ] `app/db/migrations/001_accounts_create.rb` — Account table migration
- [ ] `spec/unit/password_security_spec.rb` — All tests passing
- [ ] README with usage examples in Account model comments

---

## Key Points

✅ **Security First:**
- Never store raw passwords
- Never expose password hash via getters
- Use industry-standard PBKDF2-SHA256
- Minimum 100k iterations

✅ **No Dependencies Yet:**
- This task is completely independent
- Task 2 & 3 depend on this

✅ **Testing:**
- Unit tests must pass before handoff
- Run: `bundle exec ruby spec/unit/password_security_spec.rb`

---

## Usage Example (for reference)

```ruby
# Creating account
account = FinanceTracker::Account.create(
  username: 'john_doe',
  email: 'john@example.com'
)
account.set_password('MySecurePassword123!')
account.save

# Authenticating
account = FinanceTracker::Account[:username => 'john_doe']
if account.check_password('MySecurePassword123!')
  # Login successful
end
```
