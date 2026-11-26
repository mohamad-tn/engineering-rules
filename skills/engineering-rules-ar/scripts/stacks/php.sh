#!/usr/bin/env bash
# shellcheck shell=bash
# PHP engine: Laravel, Symfony, WordPress plugins, plain Composer packages.

run_php() {
  have php || { notrun deps "php is not installed"; return 0; }
  have composer || { notrun deps "composer is not installed"; return 0; }
  local laravel=0
  [[ -f artisan ]] && laravel=1
  echo "  framework: $([[ $laravel == 1 ]] && echo laravel || echo php)"

  if [[ ! -f composer.lock ]]; then
    fail deps "composer.lock is missing: commit it"
  else
    gate_net deps -- bash -c "composer validate --strict --no-check-publish --no-interaction && composer install --no-interaction --prefer-dist --no-progress"
  fi

  gate syntax -- bash "${STACK_TOOLS_DIR}/php-syntax-check.sh"

  # format
  if [[ -x vendor/bin/pint ]]; then
    gate format -- vendor/bin/pint --test
  elif [[ -x vendor/bin/php-cs-fixer ]]; then
    gate format -- vendor/bin/php-cs-fixer fix --dry-run --diff --no-interaction
  elif [[ -x vendor/bin/phpcs ]]; then
    gate format -- vendor/bin/phpcs
  else
    skip format "no pint, php-cs-fixer or phpcs installed"
  fi

  # static analysis
  if [[ -x vendor/bin/phpstan ]] && any_file "phpstan.neon" "phpstan.neon.dist"; then
    gate types -- vendor/bin/phpstan analyse --no-progress --memory-limit=1G
  elif [[ -x vendor/bin/psalm ]] && [[ -f psalm.xml ]]; then
    gate types -- vendor/bin/psalm --no-progress
  else
    skip types "no phpstan.neon (Larastan) or psalm.xml"
  fi

  # tests
  if ((laravel)) && grep -q 'laravel/framework' composer.json && [[ -d vendor/laravel/framework ]]; then
    gate test -- env APP_ENV=testing APP_KEY="${APP_KEY:-base64:$(head -c 32 /dev/urandom | base64)}" php artisan test
  elif [[ -x vendor/bin/pest ]]; then
    gate test -- vendor/bin/pest
  elif [[ -x vendor/bin/phpunit ]]; then
    gate test -- vendor/bin/phpunit
  else
    skip test "no artisan test, pest or phpunit (or run STACK_CMD_TEST=\"...\")"
  fi

  na build "PHP has no build step (assets are built by the node engine)"

  # Audit the lockfile. Composer 2.8+ exits 1 when there are no packages
  # ("No installed packages found"); that is N/A, not a vulnerability.
  if [[ -f composer.lock ]] && php -r '$l=json_decode((string)file_get_contents("composer.lock"), true); exit((!empty($l["packages"]) || !empty($l["packages-dev"])) ? 0 : 1);'; then
    gate_net audit -- composer audit --no-interaction --locked
  else
    na audit "no Composer packages in the lockfile"
  fi
}
