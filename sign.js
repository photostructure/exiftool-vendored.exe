#!/usr/bin/env node

const { sign } = require('@electron/windows-sign');

sign({
  appDirectory: 'bin',
  automaticallySelectCertificate: true,
  website: 'https://photostructure.com'
})