<!-- rtl -->
<div dir="rtl">

# PHP: Laravel وSymfony وحزم Composer

المحرك: `scripts/stacks/php.sh`. يكتشف `Laravel` من وجود `artisan`.

| البوابة | ما تشغّله |
|---|---|
| `deps` | `composer validate --strict` ثم `composer install`؛ ويجب رفع `composer.lock` |
| `syntax` | `php -l` على كل ملف PHP خارج `vendor/` |
| `format` | `Laravel Pint` (`--test`)، وإلا `PHP-CS-Fixer`، وإلا `PHP_CodeSniffer` |
| `types` | `PHPStan` (و`Larastan` لـ Laravel) عند وجود `phpstan.neon(.dist)`، وإلا `Psalm` |
| `test` | `php artisan test` (Laravel)، وإلا `Pest`، وإلا `PHPUnit` |
| `audit` | `composer audit` |

اختبارات Laravel تأخذ `APP_ENV=testing` ومفتاح `APP_KEY` مؤقتًا، فلا يلزم ملف `.env` ولا يُنشأ.

## الإعداد الموصى به

- ارفع `composer.lock`. ولا ترفع `.env` أبدًا (فحص الأسرار يمنعه).
- `composer require --dev laravel/pint larastan/larastan`.
- إعدادات اختيارية: `templates/stacks/php/configs/` (الملفان `phpstan.neon.dist` و`pint.json`).
- الأصول (Assets): بناء `Vite` في Laravel يغطيه محرك Node (لأن المستودع فيه `package.json`).

## التكامل المستمر (CI)

الملف `templates/stacks/php/ci.yml` (`setup-php` مع Composer). أضف الإضافات وخدمة قاعدة البيانات التي تحتاجها اختباراتك.

</div>
