'use strict'

const assert = require('node:assert/strict')
const { describe, before, after, it } = require('node:test')
const Asciidoctor = require('@asciidoctor/core')()
const ospath = require('node:path')

const FIXTURES_DIR = ospath.join(__dirname, 'fixtures')

describe('reducer smoke test', () => {
  it('should reduce document with includes', async () => {
    const registry = Asciidoctor.Extensions.create()
    require('@asciidoctor/reducer').register(registry)
    const input = ospath.join(FIXTURES_DIR, 'smoke.adoc')
    const expected = [
      '= Smoke Test',
      '',
      'Text in main document.',
      '',
      'Text in include.',
      '',
      'Text in main document.',
    ]
    const actual = Asciidoctor.loadFile(input, { extension_registry: registry, safe: 'safe' }).getSourceLines()
    assert.deepEqual(actual, expected)
  })

  it('should provide access to header attributes defined in source', async () => {
    const registry = Asciidoctor.Extensions.create()
    require('@asciidoctor/reducer').register(registry)
    const input = [
      '= Smoke Test',
      ':icons: font',
      ':toc:',
      '',
      'body text',
    ]
    const expected = { icons: 'font', toc: '' }
    const actual = Asciidoctor.load(input, { extension_registry: registry, safe: 'safe' }).source_header_attributes
    assert.deepEqual(actual.$$smap, expected)
  })
})
