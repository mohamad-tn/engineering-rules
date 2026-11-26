<!-- rtl -->
<div dir="rtl">

# Ruby وRails

المحرك: `scripts/stacks/ruby.sh`. يُكتشف `Rails` من `Gemfile.lock`.

| البوابة | ما تشغّله |
|---|---|
| `deps` | `BUNDLE_FROZEN=true bundle install` (ويجب رفع `Gemfile.lock`) |
| `lint` | `bundle exec rubocop` عند وجود RuboCop في ملف القفل |
| `sast` | `brakeman` عند وجوده في ملف القفل (ماسح أمان Rails) |
| `test` | `bin/rails test` أو `RSpec` أو `rake test` أو ملفات `test/**/*_test.rb` المجردة |
| `audit` | `bundle-audit check --update` عند وجود `bundler-audit` في ملف القفل |

## الإعداد الموصى به

- أضف `rubocop` و`brakeman` و`bundler-audit` إلى مجموعة `development` في `Gemfile`.
- إعداد اختياري: `templates/stacks/ruby/configs/.rubocop.yml`.

## التكامل المستمر (CI)

الملف `templates/stacks/ruby/ci.yml` (`ruby/setup-ruby`).

</div>
