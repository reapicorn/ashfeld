const express = require('express');
const jwt = require('jsonwebtoken');
const { getConfig } = require('../config');
const { getPrivateKey, getPublicKeyJwks } = require('./keys');
const { findUserByUsername } = require('../persistence/store');

const router = express.Router();

// GET /.well-known/openid-configuration
router.get('/.well-known/openid-configuration', (req, res) => {
  const cfg = getConfig();
  const issuer = cfg.auth.oidc.issuer;
  res.json({
    issuer,
    authorization_endpoint: `${issuer}/oauth/authorize`,
    token_endpoint: `${issuer}/oauth/token`,
    userinfo_endpoint: `${issuer}/oauth/userinfo`,
    jwks_uri: `${issuer}/.well-known/jwks.json`,
    response_types_supported: ['code', 'token'],
    grant_types_supported: ['client_credentials', 'password'],
    subject_types_supported: ['public'],
    id_token_signing_alg_values_supported: ['RS256'],
    scopes_supported: ['openid', 'profile', 'users:read', 'users:write'],
    token_endpoint_auth_methods_supported: ['client_secret_post', 'client_secret_basic'],
  });
});

// GET /.well-known/jwks.json
router.get('/.well-known/jwks.json', async (req, res) => {
  try {
    const jwks = await getPublicKeyJwks();
    res.json(jwks);
  } catch (err) {
    res.status(500).json({ error: 'key_error', error_description: err.message });
  }
});

// POST /oauth/token
router.post('/oauth/token', async (req, res) => {
  const cfg = getConfig();
  const { grant_type, client_id, client_secret, username, password, scope } = req.body;

  if (!grant_type) {
    return res.status(400).json({ error: 'invalid_request', error_description: 'grant_type is required' });
  }

  const client = cfg.auth.oidc.clients.find(c => c.clientId === client_id && c.clientSecret === client_secret);
  if (!client) {
    return res.status(401).json({ error: 'invalid_client', error_description: 'Unknown client or wrong secret' });
  }

  if (!client.grantTypes.includes(grant_type)) {
    return res.status(400).json({ error: 'unsupported_grant_type', error_description: `Grant type '${grant_type}' not allowed for this client` });
  }

  let subject = client_id;
  let extraClaims = {};

  if (grant_type === 'password') {
    if (!username || !password) {
      return res.status(400).json({ error: 'invalid_request', error_description: 'username and password required for password grant' });
    }
    const user = findUserByUsername(username);
    if (!user || user.password !== password || user.status === 'suspended') {
      return res.status(401).json({ error: 'invalid_grant', error_description: 'Invalid username or password' });
    }
    subject = user.id;
    extraClaims = { preferred_username: user.username, email: user.email };
  }

  try {
    const privateKey = await getPrivateKey();
    const privateKeyPem = privateKey.toPEM(true);
    const requestedScope = scope || client.scopes.join(' ');

    const token = jwt.sign(
      {
        iss: cfg.auth.oidc.issuer,
        sub: subject,
        aud: client_id,
        scope: requestedScope,
        ...extraClaims,
      },
      privateKeyPem,
      {
        algorithm: 'RS256',
        expiresIn: cfg.auth.oidc.tokenExpiry,
        keyid: privateKey.kid,
      }
    );

    res.json({
      access_token: token,
      token_type: 'Bearer',
      expires_in: cfg.auth.oidc.tokenExpiry,
      scope: requestedScope,
    });
  } catch (err) {
    res.status(500).json({ error: 'server_error', error_description: err.message });
  }
});

// GET /oauth/userinfo  (requires Bearer token)
router.get('/oauth/userinfo', async (req, res) => {
  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'unauthorized', error_description: 'Bearer token required' });
  }
  const token = authHeader.slice(7);
  try {
    const jwks = await getPublicKeyJwks();
    const publicKey = jwks.keys[0];
    const pem = (await require('node-jose').JWK.asKey(publicKey)).toPEM(false);
    const decoded = jwt.verify(token, pem, { algorithms: ['RS256'] });
    res.json({
      sub: decoded.sub,
      preferred_username: decoded.preferred_username,
      email: decoded.email,
      scope: decoded.scope,
    });
  } catch (err) {
    res.status(401).json({ error: 'invalid_token', error_description: err.message });
  }
});

module.exports = router;
