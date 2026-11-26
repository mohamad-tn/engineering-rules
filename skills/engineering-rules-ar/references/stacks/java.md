<!-- rtl -->
<div dir="rtl">

# Java وKotlin: Spring Boot وMaven وGradle

المحرك: `scripts/stacks/java.sh`. يستخدم غلاف Maven أو Gradle (wrapper) عند وجوده.

| البوابة | ما تشغّله |
|---|---|
| `deps` | `mvn dependency:resolve` أو `gradlew dependencies` |
| `format` | `Spotless` (`spotless:check` أو `spotlessCheck`) عند ضبط الإضافة |
| `lint` | `Checkstyle` (في Maven) عند ضبطه |
| `test` | `mvn verify` أو `gradlew check` |
| `build` | `mvn -DskipTests package` أو `gradlew assemble` |
| `audit` | `OWASP dependency-check` عند ضبط الإضافة |

## الإعداد الموصى به

- ارفع الغلاف (`mvnw` أو `gradlew`) حتى يبني الجميع بالإصدار نفسه؛ والمحرك يحذّر عند غيابه.
- فعّل قفل الاعتمادات في Gradle (`gradle.lockfile`).
- أضف `Spotless` وإضافة `OWASP dependency-check` إلى بنائك.
- يُكتشف `Spring Boot` من ملف البناء ويُذكر في التقرير؛ ولا يلزم بوابات إضافية.

## التكامل المستمر (CI)

الملف `templates/stacks/java/ci.yml` (`setup-java` مع `Temurin 21`).

</div>
