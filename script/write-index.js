#!/usr/bin/env node

/* This script generates the root contract index based on the contents of build/contracts */

const fs = require('fs')
const glob = require('glob')
const path = require('path')

const PROJECT_DIR = path.join(__dirname, '..')
const CONTRACTS_OUTPUT_DIR = path.join(PROJECT_DIR, 'out')
const GENERATED_FILE = path.join(PROJECT_DIR, 'script', 'generated', 'index.ts')

const files = glob.sync(path.join(CONTRACTS_OUTPUT_DIR, '**/*.json'))

const data = Object.values(files.reduce((m, f) => {
  const relPath = path.relative(CONTRACTS_OUTPUT_DIR, f)
  const fileName = path.basename(f, '.json')
  if (!m[fileName]) {
    m[fileName] = { relPath, fileName }
  }
  return m
}, {}))

const importStatements = data.map(({ relPath, fileName }) => {
  return `const { abi: ${fileName}Abi } = require("../out/${relPath}")`
})

const exportStatments = data.map(({ fileName }) => {
  return `export const ${fileName} = ${fileName}Abi as ContractInterface`
})

fs.writeFileSync(GENERATED_FILE, `
/// ------------------------------------------------------------------------------------------------------------
///
/// NOTE: this file is auto-generated by ${path.basename(__filename)}, please DO NOT modify it directly.
///
/// ------------------------------------------------------------------------------------------------------------

import { ContractInterface } from "@ethersproject/contracts"

${importStatements.join("\n")}

${exportStatments.join("\n")}
`)