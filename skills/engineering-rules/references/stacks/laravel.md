# PHP: Laravel, Symfony, Composer packages

Engine: `scripts/stacks/php.sh`. Detects Laravel from `artisan`.

| Gate | Runs |
|---|---|
| deps | `composer validate --strict` and `composer install`; `composer.lock` must be committed |
| syntax | `php -l` on every PHP file outside `vendor/` |
| format | Laravel Pint (`--test`), else PHP-CS-Fixer, else PHP_CodeSniffer |
| types | PHPStan (Larastan for Laravel) when `phpstan.neon(.dist)` exists, else Psalm |
| test | `php artisan test` (Laravel), else Pest, else PHPUnit |
| audit | `composer audit` |

Laravel tests get `APP_ENV=testing` and a throw-away `APP_KEY`, so no `.env` file is needed or created.

## Recommended setup

- Commit `composer.lock`. Never commit `.env` (the secret scan blocks it).
- `composer require --dev laravel/pint larastan/larastan`.
- Opt-in configs: `templates/stacks/php/configs/` (`phpstan.neon.dist`, `pint.json`).
- Assets: Laravel's Vite build is covered by the Node engine (the repository has a `package.json`).

## CI

`templates/stacks/php/ci.yml` (setup-php with Composer). Add the extensions and a database service your tests need.
