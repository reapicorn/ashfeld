const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { getConfig } = require('../config');
const { getPublicKeyJwks } = require('./keys');

// Cached JWKS public key PEM
let _publicKeyPem = null;
async function getPublicPem() {
  if (_publicKeyPem) return _publicKeyPem;
  const jose = require('node-jose');
  const jwks = await getPublicKeyJwks();
  const key = await jose.JWK.asKey(jwks.keys[0]);
  _publicKeyPem = key.toPEM(false);
  return _publicKeyPem;
}

async function authMiddleware(req, res, next) {
  const cfg = getConfig();
  const authHeader = req.headers.authorization || '';
  const apiKeyHeader = req.headers['x-api-key'] || '';

  // --- API Key ---
  if (cfg.auth.apiKey.enabled && apiKeyHeader) {
    const match = cfg.auth.apiKey.keys.find(k => k.key === apiKeyHeader);
    if (match) {
      req.authMethod = 'apikey';
      req.authLabel = match.label;
      return next();
    }
    return res.status(401).json({ error: 'invalid_api_key', message: 'The provided API key is not valid.' });
  }

  // --- Basic Auth ---
  if (cfg.auth.basicAuth.enabled && authHeader.startsWith('Basic ')) {
    const b64 = authHeader.slice(6);
    const decoded = Buffer.from(b64, 'base64').toString('utf8');
    const [username, ...rest] = decoded.split(':');
    const password = rest.join(':');
    const userEntry = cfg.auth.basicAuth.users.find(u => u.username === username);
    if (userEntry) {
      const valid = await bcrypt.compare(password, userEntry.passwordHash);
      if (valid) {
        req.authMethod = 'basic';
        req.authUser = username;
        return next();
      }
    }
    res.setHeader('WWW-Authenticate', 'Basic realm="uasme-mock-server"');
    return res.status(401).json({ error: 'invalid_credentials', message: 'Invalid username or password.' });
  }

  // --- Bearer (OIDC JWT) ---
  if (cfg.auth.oidc.enabled && authHeader.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    try {
      const pem = await getPublicPem();
      const decoded = jwt.verify(token, pem, { algorithms: ['RS256'] });
      req.authMethod = 'oidc';
      req.authClaims = decoded;
      return next();
    } catch (err) {
      return res.status(401).json({ error: 'invalid_token', message: err.message });
    }
  }

  // --- No valid auth provided ---
  res.setHeader('WWW-Authenticate', 'Basic realm="uasme-mock-server"');
  return res.status(401).json({
    error: 'unauthorized',
    message: 'Provide one of: Basic Auth (Authorization header), API Key (X-API-Key header), or Bearer token (Authorization header).',
  });
}

module.exports = authMiddleware;
