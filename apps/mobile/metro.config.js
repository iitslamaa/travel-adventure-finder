const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

config.watchFolders = [
  ...(config.watchFolders ?? []),
  path.resolve(__dirname, '..'),
];
config.resolver.sourceExts.push('xcstrings');
config.transformer.babelTransformerPath = require.resolve(
  './metro.xcstrings-transformer.js'
);

module.exports = config;
