// @ts-check
'use strict'

const assert = require('assert')
const { Octokit } = require('@octokit/rest')

assert(process.env.GH_TOKEN, 'token required')

const octokit = new Octokit({
  auth: process.env.GH_TOKEN
})

async function main () {
  const r = await octokit.repos.listForUser({
    username: 'raynos'
  })

  console.log('r', r)
}

main().catch((err) => {
  process.nextTick(() => { throw err })
})
