#!/usr/bin/env bash
# shellcheck shell=bash
# Ruby engine: Rails, Sinatra, gems.

run_ruby() {
  have bundle || { notrun deps "bundler is not installed"; return 0; }
  local fw="ruby"
  grep -qs "^    rails (" Gemfile.lock && fw="rails"
  echo "  framework: ${fw}"

  if [[ ! -f Gemfile.lock ]]; then
    fail deps "Gemfile.lock is missing: commit it"
    return 0
  fi
  gate_net deps -- env BUNDLE_FROZEN=true bundle install --jobs 4

  if grep -qs '^    rubocop (' Gemfile.lock; then gate lint -- bundle exec rubocop
  else skip lint "rubocop is not in Gemfile.lock"; fi
  na format "rubocop covers formatting when configured (lint)"
  na types "Ruby has no built-in type checker"

  if grep -qs '^    brakeman (' Gemfile.lock; then gate sast -- bundle exec brakeman -q --no-pager; fi

  if [[ -x bin/rails && -d test ]]; then gate test -- bin/rails test
  elif [[ -d spec ]] && grep -qs '^    rspec' Gemfile.lock; then gate test -- bundle exec rspec
  elif [[ -f Rakefile ]] && grep -qs '^    rake (' Gemfile.lock && [[ -d test ]]; then gate test -- bundle exec rake test
  elif [[ -d test ]]; then
    gate test -- bundle exec ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |f| require File.expand_path(f) }'
  else skip test "no bin/rails test, spec/ or test/ found"; fi

  na build "no build step (assets are built by the node engine)"

  if grep -qs '^    bundler-audit (' Gemfile.lock; then
    gate_net audit -- bundle exec bundle-audit check --update
  else
    notrun audit "bundler-audit is not in Gemfile.lock"
  fi
}
