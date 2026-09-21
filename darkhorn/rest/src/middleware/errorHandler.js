function errorHandler(err, req, res, next) {
  console.error(`[ERROR] ${err.message}`);
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'invalid_json', message: 'Request body is not valid JSON.' });
  }
  res.status(err.status || 500).json({
    error: err.code || 'internal_error',
    message: err.message || 'An unexpected error occurred.',
  });
}

module.exports = errorHandler;
