# Backend API Specification for Statelessor

## SSH Key Generation API

### POST /api/ssh/generate

**Purpose**: Generate a unique SSH key pair for Git repository access

**Request**:
```json
{
  "sessionId": "optional-session-identifier"
}
```

**Response**:
```json
{
  "success": true,
  "keyId": "unique-key-identifier-uuid",
  "publicKey": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQw7+kPn8QJvmM8hX9zK5J2L3mN4pQ8rS6tU7vW8xY9 statelessor@app",
  "expiresAt": "2024-01-01T12:00:00Z"
}
```

**Error Response**:
```json
{
  "success": false,
  "error": "Failed to generate SSH key",
  "code": "KEY_GENERATION_FAILED"
}
```

## ExpressJS Implementation

```javascript
const express = require('express');
const crypto = require('crypto');
const { generateKeyPair } = require('crypto');
const app = express();

// In-memory storage (use Redis/Database in production)
const sshKeys = new Map();

app.post('/api/ssh/generate', async (req, res) => {
  try {
    // Generate ED25519 key pair
    const { publicKey, privateKey } = await new Promise((resolve, reject) => {
      generateKeyPair('ed25519', {
        publicKeyEncoding: {
          type: 'spki',
          format: 'pem'
        },
        privateKeyEncoding: {
          type: 'pkcs8',
          format: 'pem'
        }
      }, (err, publicKey, privateKey) => {
        if (err) reject(err);
        else resolve({ publicKey, privateKey });
      });
    });

    // Convert to SSH format
    const sshPublicKey = convertToSSHFormat(publicKey);
    
    // Generate unique key ID
    const keyId = crypto.randomUUID();
    
    // Store key pair (encrypt private key in production)
    sshKeys.set(keyId, {
      publicKey: sshPublicKey,
      privateKey: privateKey,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours
    });

    res.json({
      success: true,
      keyId: keyId,
      publicKey: sshPublicKey,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
    });

  } catch (error) {
    console.error('SSH key generation failed:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to generate SSH key',
      code: 'KEY_GENERATION_FAILED'
    });
  }
});

// Helper function to convert PEM to SSH format
function convertToSSHFormat(pemPublicKey) {
  // This is a simplified version - use a proper SSH key library like 'ssh-keygen'
  const keyData = pemPublicKey
    .replace('-----BEGIN PUBLIC KEY-----', '')
    .replace('-----END PUBLIC KEY-----', '')
    .replace(/\n/g, '');
  
  return `ssh-ed25519 ${keyData} statelessor@app`;
}

// Cleanup expired keys (run periodically)
setInterval(() => {
  const now = new Date();
  for (const [keyId, keyData] of sshKeys.entries()) {
    if (keyData.expiresAt < now) {
      sshKeys.delete(keyId);
    }
  }
}, 60 * 60 * 1000); // Every hour

module.exports = app;
```

## Production Considerations

### Security:
- **Encrypt private keys** at rest using AES-256
- **Use Redis/Database** instead of in-memory storage
- **Implement rate limiting** for key generation
- **Add authentication** to prevent abuse

### Dependencies:
```bash
npm install express crypto uuid ssh-keygen
```

### Environment Variables:
```env
SSH_KEY_EXPIRY_HOURS=24
ENCRYPTION_KEY=your-256-bit-encryption-key
REDIS_URL=redis://localhost:6379
```

This API provides secure, on-demand SSH key generation with proper cleanup and error handling.