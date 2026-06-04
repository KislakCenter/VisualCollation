module.exports = {
  jest(config) {
    config.roots = ['<rootDir>'];
    config.testMatch = [
      '**/__tests__/**/*.{js,jsx,ts,tsx}',
      '**/*.{spec,test}.{js,jsx,ts,tsx}'
    ];
    return config;
  }
};
