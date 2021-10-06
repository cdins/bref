---
layout: home
---

[![Running PHP made simple. Bref provides tools and documentation to easily deploy and run serverless PHP applications. Learn more](docs/readme-screenshot.jpg)](https://bref.sh/)

[![Build Status](https://travis-ci.com/brefphp/bref.svg?branch=master)](https://travis-ci.com/brefphp/bref)
[![Latest Version](https://img.shields.io/github/release/brefphp/bref.svg?style=flat-square)](https://packagist.org/packages/bref/bref)
[![Monthly Downloads](https://img.shields.io/packagist/dm/bref/bref.svg)](https://packagist.org/packages/bref/bref/stats)

Read more on [the website](https://bref.sh/).

# ClarionDoor

1. Add newrelic to new php versions ( if not already there )
2. merge main bref repo in
3. conflicts in runtime/export/opt/bootstrap: do NOT accept changes, but copy changes into this repo's opt/bootstrap-php
4. Run `make runtimes`
