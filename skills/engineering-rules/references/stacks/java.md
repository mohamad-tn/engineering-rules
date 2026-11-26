# Java and Kotlin: Spring Boot, Maven, Gradle

Engine: `scripts/stacks/java.sh`. Uses the Maven or Gradle wrapper when present.

| Gate | Runs |
|---|---|
| deps | `mvn dependency:resolve` / `gradlew dependencies` |
| format | Spotless (`spotless:check` / `spotlessCheck`) when the plugin is configured |
| lint | Checkstyle (Maven) when configured |
| test | `mvn verify` / `gradlew check` |
| build | `mvn -DskipTests package` / `gradlew assemble` |
| audit | OWASP dependency-check when the plugin is configured |

## Recommended setup

- Commit the wrapper (`mvnw` or `gradlew`) so everyone builds with the same version; the engine warns without it.
- Enable Gradle dependency locking (`gradle.lockfile`).
- Add Spotless and the OWASP dependency-check plugin to your build.
- Spring Boot is detected from the build file and reported; no extra gates are needed.

## CI

`templates/stacks/java/ci.yml` (setup-java, Temurin 21).
