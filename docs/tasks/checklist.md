# Release Checklist

[] All new controllers have test coverage [] Integration tests cover boundary-specific routing and
ownership [] Edge cases tested for invalid host names, malformed cookies, and cross-boundary
redirects [] Run full test suite: `bundle exec rails test` [] Run linting: `bundle exec rubocop` []
Run ERB lint: `bundle exec erb_lint .` [] Run JS checks: `pnpm check` [] Confirm docs and plans
match the current surface/repository boundary model

## API Design Anti-Patterns (AVOID THESE)

### HTTP Status Codes

[] Do NOT return 200 OK for errors - use appropriate status codes (4xx for client errors, 5xx for
server errors) [] Ensure error responses use correct HTTP status codes (400, 401, 403, 404, 422,
500, etc.)

### Endpoint Naming

[] Do NOT use RPC-style endpoint names like /getUser, /createUser, /deleteUser [] Use RESTful
conventions: GET /users, POST /users, DELETE /users/{id} [] Use nouns (resources) not verbs in
endpoint paths

### Security

[] Do NOT return passwords in API responses (even hashed) [] Do NOT return sensitive tokens in
responses (use secure cookies or headers) [] Do NOT pass authentication tokens in query parameters
(use headers or secure cookies) [] Avoid exposing internal IDs or implementation details [] Ensure
all User and Staff DB operations are recorded in Audit logs

### Consistency

[] Do NOT mix naming conventions in the same response (user_id, UserId, idUser) [] Use consistent
casing throughout the API (prefer snake_case for JSON in Rails) [] Maintain consistent field naming
across all endpoints

### Data Types

[] Do NOT return null for collections - return empty arrays [] instead [] Use appropriate data types
(arrays for lists, objects for structured data) [] Be consistent with null vs empty values

### Error Handling

[] Do NOT return generic error messages like { "error": "Something went wrong" } [] Provide
structured error responses with error codes and detailed messages [] Include validation errors with
field-level details [] Example good error format:

```json
{
  "errors": [
    {
      "code": "VALIDATION_ERROR",
      "message": "Invalid email format",
      "field": "email",
      "details": "Email must be a valid email address"
    }
  ]
}
```

### Resource Design

[] Do NOT create ambiguous endpoints like GET /user (singular) and GET /users/{id} [] Be clear: use
GET /users/me for current user, GET /users/{id} for specific user [] Avoid resource naming conflicts

### Query Parameters

[] Do NOT pass sensitive data in query strings (passwords, tokens, personal data) [] Use request
body for sensitive data in POST/PUT/PATCH requests [] Keep query parameters for filtering, sorting,
pagination only
