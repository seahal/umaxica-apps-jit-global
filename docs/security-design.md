# Security Design Documentation

> **Current UMAXICA contract (2026-10-07):** The OTP/HOTP material below is retained as historical
> generic guidance and is not the authority for the current Email or Telephone implementation. The
> current contract uses separate channel policies and ceremony-owned, purpose-bound keyed
> random-code verifiers. Identifier-owned `otp_private_key`, `otp_counter` and equivalent HOTP proof
> material are retired, and no fallback may reconstruct them. See
> [`adr/realm-separated-identifiers-and-dead-history.md`](../adr/realm-separated-identifiers-and-dead-history.md)
> and [`docs/security/otp-audit.md`](security/otp-audit.md) for the current ownership and migration
> boundary.

## Passcode Design

### High-Entropy Passcode with Argon2 Hashing

This design, combining a high-entropy passcode (non-changeable by the user) with Argon2 hashing, is
excellent and aligns with security best practices.

For long-term safety, as the passcode is permanent, we strongly recommend 32 characters (approx. 208
bits of entropy). This better prepares against future increases in computing power than 24
characters.

Argon2 is the highest-standard hashing algorithm, robust against GPU attacks. Given the passcode is
stored in a password manager, its use is essential.

### Passcode Characteristics

- **Non-changeable**: Passcodes are permanent and cannot be modified by users
- **High entropy**: 32 characters provide approximately 208 bits of entropy
- **Future-proof**: Designed to withstand advances in computing power
- **Password manager storage**: Expected to be stored in secure password managers
- **Argon2 protection**: Resistant to GPU-based brute force attacks

### Implementation Guidelines

1. **Passcode Generation**
   - Generate passcodes with minimum 32 characters
   - Use cryptographically secure random number generators
   - Ensure sufficient entropy (208+ bits)

2. **Passcode Storage**
   - Hash all passcodes with Argon2 before database storage
   - Never store plaintext passcodes
   - Use appropriate Argon2 parameters (memory cost, time cost, parallelism)

3. **Passcode Verification**
   - Verify submitted passcodes against Argon2 hashes
   - Implement rate limiting to prevent brute force attempts
   - Log verification attempts for security monitoring

4. **User Guidance**
   - Instruct users to store passcodes in password managers
   - Emphasize the permanence and importance of the passcode
   - Provide clear warnings about passcode security

### Security Rationale

The combination of high-entropy passcodes and Argon2 hashing provides defense-in-depth:

- **Entropy**: Makes brute force attacks computationally infeasible
- **Argon2**: Adds significant computational cost to each verification attempt
- **GPU resistance**: Argon2's memory-hard design mitigates GPU acceleration
- **Future resilience**: 208-bit entropy accounts for long-term cryptographic advances

This approach ensures that even if the database is compromised, passcodes remain protected against
offline attacks.

---

## Historical OTP/HOTP Security Guidance

### Overview

When implementing One-Time Password (OTP) systems, particularly HMAC-based OTP (HOTP), following
security best practices is critical to prevent unauthorized access and protect user accounts.

### Best Practices

#### 1. Private Key Storage

**Do NOT store private keys in sessions**

- Sessions can be compromised through XSS or CSRF attacks
- Session data may be logged or cached insecurely
- **Recommended**: Store encrypted private keys in the database
- Use strong encryption (e.g., Rails encrypted attributes with AES-256-GCM)
- Associate keys with specific user records, not temporary sessions

```ruby
# ❌ Bad: Storing in session
session[:otp_private_key] = ROTP::Base32.random_base32

# ✅ Good: Storing in database with encryption
user_email.update!(
  otp_private_key: ROTP::Base32.random_base32  # Encrypted attribute
)
```

#### 2. Counter Value Management

**Use simple, sequential counter values**

- Start counters at 0 or use sequential increments
- Avoid complex counter generation schemes
- Do NOT use timestamps or predictable values in counters
- Counter should only increment after successful verification

```ruby
# ❌ Bad: Complex, predictable counter
otp_count_number = [Time.now.to_i, SecureRandom.random_number(1 << 64)].map(&:to_s).join.to_i

# ✅ Good: Simple counter
otp_counter = 0  # Start fresh
# or
otp_counter = previous_counter + 1  # Increment after verification
```

#### 3. Brute Force Protection

**Implement attempt limits**

- Limit verification attempts (recommended: 3-5 attempts)
- Lock out after maximum attempts exceeded
- Reset attempts counter only after successful verification or timeout
- Consider exponential backoff for repeated failures

```ruby
# Example implementation
if verification_attempts >= MAX_ATTEMPTS
  render :error, status: :forbidden
  return
end

if hotp.verify(submitted_code, counter)
  # Success - reset attempts
  update!(verification_attempts: 0)
else
  # Failure - increment attempts
  increment!(:verification_attempts)
end
```

#### 4. Proper HOTP Verification

**Use the verify() method correctly**

- Always use `hotp.verify()` for verification, never string comparison
- Verify against the correct counter value
- Do NOT increment counter on failed attempts
- Implement counter drift tolerance if needed (within reason)

```ruby
# ❌ Bad: String comparison
if submitted_code == hotp.at(counter)

# ✅ Good: Proper verification
if hotp.verify(submitted_code, counter)
  # Valid OTP - increment counter
  update!(otp_counter: counter + 1)
end
```

#### 5. Strict Timeout Enforcement

**Enforce expiration times rigorously**

- Set reasonable expiration periods (10-15 minutes recommended)
- Check expiration BEFORE verification attempts
- Invalidate OTPs immediately after timeout
- Clear all related session/temporary data after expiration

```ruby
# Check expiration first
if Time.current > expires_at
  # Expired - reject immediately
  render :expired, status: :unprocessable_content
  return
end

# Then proceed with verification
if hotp.verify(submitted_code, counter)
  # Success
end
```

### Security Risks of Current Implementation

The following patterns should be avoided:

1. **Session-based key storage**
   - Risk: Key exposure through session hijacking
   - Impact: Attacker can generate valid OTPs

2. **Predictable counters**
   - Risk: Counter values can be guessed or calculated
   - Impact: Reduces effective security of HOTP

3. **Missing attempt limits**
   - Risk: Unlimited brute force attempts
   - Impact: 6-digit OTPs can be brute-forced (1 million possibilities)

4. **Weak verification logic**
   - Risk: Timing attacks, bypass vulnerabilities
   - Impact: Unauthorized access to accounts

5. **Lax timeout enforcement**
   - Risk: Extended attack window
   - Impact: Stolen OTPs remain valid longer

### Recommended Implementation Pattern

```ruby
class EmailVerificationController < ApplicationController
  def create
    # Generate secure private key
    private_key = ROTP::Base32.random_base32

    # Initialize counter
    counter = 0

    # Generate OTP
    hotp = ROTP::HOTP.new(private_key)
    otp_code = hotp.at(counter)

    # Store in database (encrypted)
    verification = EmailVerification.create!(
      email_address: params[:email],
      otp_private_key: private_key,  # Encrypted attribute
      otp_counter: counter,
      expires_at: 15.minutes.from_now,
      verification_attempts: 0
    )

    # Send OTP via email
    EmailMailer.with(code: otp_code, email: params[:email]).deliver_now

    # Store only verification ID in session
    session[:verification_id] = verification.id
  end

  def verify
    verification = EmailVerification.find(session[:verification_id])

    # Check expiration
    if verification.expired?
      render :expired, status: :unprocessable_content
      return
    end

    # Check attempt limit
    if verification.verification_attempts >= 3
      render :locked, status: :forbidden
      return
    end

    # Verify OTP
    hotp = ROTP::HOTP.new(verification.otp_private_key)

    if hotp.verify(params[:code], verification.otp_counter)
      # Success
      verification.mark_as_verified!
      session.delete(:verification_id)
      redirect_to success_path
    else
      # Failed attempt
      verification.increment!(:verification_attempts)
      render :verify, status: :unprocessable_content
    end
  end
end
```

### Conclusion

Current implementations that store private keys in sessions pose security risks. To ensure robust
protection:

- Store encrypted keys in the database
- Use simple, non-predictable counters
- Implement strict attempt limits
- Use proper HOTP verification methods
- Enforce timeout policies rigorously

Following these practices significantly reduces the attack surface and protects user authentication
flows from common vulnerabilities.

---

**Document Version**: 1.1 **Last Updated**: November 11, 2025 **Status**: Active
