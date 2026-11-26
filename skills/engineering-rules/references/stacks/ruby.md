# Ruby and Rails

Engine: `scripts/stacks/ruby.sh`. Rails is detected from `Gemfile.lock`.

| Gate | Runs |
|---|---|
| deps | `BUNDLE_FROZEN=true bundle install` (`Gemfile.lock` must be committed) |
| lint | `bundle exec rubocop` when RuboCop is in the lockfile |
| sast | `brakeman` when it is in the lockfile (Rails security scanner) |
| test | `bin/rails test`, RSpec, `rake test`, or plain `test/**/*_test.rb` |
| audit | `bundle-audit check --update` when `bundler-audit` is in the lockfile |

## Recommended setup

- Add `rubocop`, `brakeman` and `bundler-audit` to the `development` group of your `Gemfile`.
- Opt-in config: `templates/stacks/ruby/configs/.rubocop.yml`.

## CI

`templates/stacks/ruby/ci.yml` (ruby/setup-ruby).
