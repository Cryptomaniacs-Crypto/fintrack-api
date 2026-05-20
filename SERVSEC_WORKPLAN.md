## Team Split (3 People, Minimal Dependency/Clash)
 
 | Person | Scope | Deliverables | Dependencies |
 |---|---|---|---|
 | **Dev 1 – API & Data Platform** | API-only changes | 1. db:bootstrap_admin Rake task  2. Postgres setup + Heroku config  3. API deploy to Heroku | None to start; shares deployed API URL with Dev 3
 |
 | **Dev 2 – App Security & Session Infrastructure** | App security internals | 1. HTTP->HTTPS redirect + HSTS  2. Secure messaging lib (NaCl SimpleBox + `MSG_KEY`)  3. Secure session get/set lib  4. 
Session storage strategy: pool (dev/test), Redis (prod) + RedisCloud | None to start; coordinate final merge with Dev 3 |
 | **Dev 3 – App Registration, Service, Tests, Integration** | App feature + API integration | 1. Registration form + POST handler (`email`, `username`, `password`)  2. Service object to post to API  
3. WebMock tests (no real API)  4. App deploy to Heroku  5. Point App to deployed API and verify create/update in cloud | Needs API URL from Dev 1 near final integration |
 
 ## Suggested Execution Order
 
 1. Dev 1 and Dev 2 start immediately in parallel.
 2. Dev 3 starts registration/service/WebMock using mocked contract.
 3. Final integration:
    - Dev 1 provides deployed API URL.
    - Dev 3 switches App config to deployed API and validates cloud flows.
    - Dev 2 verifies secure sessions and Redis behavior in production.