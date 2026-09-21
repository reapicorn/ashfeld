const fs = require('fs');
const path = require('path');

const configPath = path.resolve(__dirname, '..', 'config.json');

let _config = null;

function getConfig() {
  if (!_config) {
    const raw = fs.readFileSync(configPath, 'utf8');
    _config = JSON.parse(raw);
  }
  return _config;
}

module.exports = { getConfig };
