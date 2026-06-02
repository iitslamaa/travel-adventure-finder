const upstreamTransformer = require('@expo/metro-config/babel-transformer');

module.exports.transform = function transform({ src, filename, options }) {
  if (filename.endsWith('.xcstrings')) {
    return upstreamTransformer.transform({
      src: `module.exports = ${src};`,
      filename,
      options,
    });
  }

  return upstreamTransformer.transform({ src, filename, options });
};
