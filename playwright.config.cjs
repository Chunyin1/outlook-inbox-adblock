const { defineConfig } = require("@playwright/test");
module.exports = defineConfig({
  testDir: "./tests",
  testMatch: "**/*.spec.cjs",
  workers: 1,
  use: {
    browserName: "chromium",
    channel: process.env.TEST_BROWSER_CHANNEL || undefined,
    headless: true,
  },
});
