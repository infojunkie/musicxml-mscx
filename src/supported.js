#!/usr/bin/env node

/**
 * Merge latest version of the supported table (xsl) into the existing one (doc/supported.md).
 *
 * - Replace first column if match found
 * - Keep other columns untouched
 * - TODO Add new row if first column text not found
 *
 * Usage: cat doc/supported.md | src/supported.js > /tmp/supported.md; cp /tmp/supported.md doc/supported.md
 *
 */

import { readFileSync } from 'fs'
import SaxonJS from 'saxon-js'

const REGEX = new RegExp(/\s(-*)[^@a-z]*(@?[a-z:-]+)\b/mi)

// Generate the latest version of the supported table from xsl.
// We build a map where keys are the element path and the entries are the columns.
const supported = SaxonJS.transform({
  stylesheetFileName: 'build/supported.sef.json',
  sourceText: readFileSync('src/musicxml.xsd').toString(),
  destination: 'serialized'
}, 'sync')
const latest = supported.principalResult.split("\n").reduce((tree, line) => {
  const columns = line.trim().split('|').filter(Boolean)
  if (columns.length !== 3) {
    console.error(`Latest: No match for "${line}". Skipping.`)
    return tree
  }
  const matches = columns[0].match(REGEX)
  if (!matches) {
    console.error(`Latest: No match for "${columns[0]}". Skipping.`)
    return tree
  }
  const element = matches[2]
  const level = matches[1].length
  if (level < tree.path.length) {
    tree.path.splice(level)
  }
  tree.path.push(element)
  tree.map.set(tree.path.join('/'), columns)
  return tree
}, {
  map: new Map(),
  path: [],
}).map

// Parse and merge the existing table from stdin.
let path = [];
readFileSync(0).toString().split("\n").forEach(line => {
  const columns = line.trim().split('|').filter(Boolean)
  if (columns.length !== 3) {
    console.error(`Existing: No match for "${line}". Passing through.`)
    console.log(line)
    return
  }
  const matches = columns[0].match(REGEX)
  if (!matches) {
    console.error(`Existing: No match for "${columns[0]}". Passing through.`)
    console.log(line)
    return
  }
  const element = matches[2]
  const level = matches[1].length
  if (level < path.length) {
    path.splice(level)
  }
  path.push(element)
  const entry = latest.get(path.join('/'))
  if (entry) {
    console.log(['', entry[0], ...columns.slice(1), ''].join('|'))
  }
  else {
    console.log(line)
  }
})
