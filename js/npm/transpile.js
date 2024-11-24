'use strict'

const { env: ENV } = require('node:process')
const fs = require('node:fs')
const ospath = require('node:path')

let opalCompilerPath = 'opal-compiler'
try {
  require.resolve(opalCompilerPath)
} catch {
  const npxInstallDir = ENV.PATH.split(':')[0]
  if (npxInstallDir?.endsWith('/node_modules/.bin') && npxInstallDir.startsWith(ENV.npm_config_cache + '/')) {
    opalCompilerPath = require.resolve('opal-compiler', { paths: [ospath.dirname(npxInstallDir)] })
  }
}

const transpiled = require(opalCompilerPath).Builder
  .create()
  .build('../lib/asciidoctor/reducer/conditional_directive_tracker.rb')
  .build('../lib/asciidoctor/reducer/include_directive_tracker.rb')
  .build('../lib/asciidoctor/reducer/header_attribute_tracker.rb')
  .build('../lib/asciidoctor/reducer/preprocessor.rb')
  .build('../lib/asciidoctor/reducer/tree_processor.rb')
  .build('../lib/asciidoctor/reducer/extensions.rb')
  .toString()
fs.mkdirSync('dist', { recursive: true })
fs.writeFileSync('dist/index.js', transpiled)
