# `wiki-source-check`
[![CI](https://github.com/snood1205/wiki-source-check/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/snood1205/wiki-source-check/actions/workflows/ci.yml)

## The problem
[Wikipedia](https://en.wikipedia.org) is a fantastic resource; however, its citations are rather complicated and often issues can arise when writing an article that are hard to track by hand.

## The solution
This tool, when completed, will be able to validate Wikipedia sources from a wikitext input in a variety of ways that can lead to far better sources being on Wikipedia.

## Requirements
* Ruby: [4.0.6](https://www.ruby-lang.org/en/news/2026/07/14/ruby-4-0-6-released/)
* Bundler: [4.0.16](https://github.com/ruby/rubygems/releases/tag/bundler-v4.0.16)

## Installation
The tool will eventually have an install script that can be run as `./install.sh`, but for the time being the install instructions are:
```bash
bundle install
```

## Tests
The tests can be run with
```bash
bundle exec rspec
```

## Linting
Rubocop can be run with
```bash
bundle exec rubocop
```

## License
This is licensed under the MIT License. The license text can be viewed at [LICENSE.txt](LICENSE.txt).
