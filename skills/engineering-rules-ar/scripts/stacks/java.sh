#!/usr/bin/env bash
# shellcheck shell=bash
# Java / Kotlin engine: Maven and Gradle projects (Spring Boot, Quarkus, Android libs...).

run_java() {
  local fw="java"
  grep -qsE 'spring-boot' pom.xml build.gradle build.gradle.kts && fw="spring-boot"
  if [[ -f pom.xml ]]; then
    local mvn="mvn"
    [[ -x ./mvnw ]] && mvn="./mvnw"
    echo "  framework: ${fw}, build tool: maven"
    have "${mvn#./}" || [[ "$mvn" == "./mvnw" ]] || { notrun deps "maven is not installed and there is no mvnw"; return 0; }
    [[ "$mvn" == "./mvnw" ]] || warn wrapper "no mvnw: commit the Maven wrapper so everyone builds the same way"

    gate_net deps -- "$mvn" -B -ntp -q dependency:resolve
    if grep -q 'spotless' pom.xml; then gate format -- "$mvn" -B -ntp -q spotless:check
    elif grep -q 'checkstyle' pom.xml; then gate lint -- "$mvn" -B -ntp -q checkstyle:check
    else skip format "no spotless or checkstyle plugin in pom.xml"; fi
    gate test -- "$mvn" -B -ntp verify
    gate build -- "$mvn" -B -ntp -q -DskipTests package
    if grep -q 'dependency-check' pom.xml; then
      gate_net audit -- "$mvn" -B -ntp org.owasp:dependency-check-maven:check
    else
      skip audit "add the OWASP dependency-check plugin or rely on your dependency bot"
    fi
  elif any_file "build.gradle" "build.gradle.kts"; then
    local gw="./gradlew"
    echo "  framework: ${fw}, build tool: gradle"
    if [[ ! -x ./gradlew ]]; then
      have gradle || { notrun deps "no gradlew and gradle is not installed"; return 0; }
      gw="gradle"
      warn wrapper "no gradlew: commit the Gradle wrapper"
    fi
    gate_net deps -- "$gw" --no-daemon -q dependencies
    if grep -qs 'spotless' build.gradle build.gradle.kts; then gate format -- "$gw" --no-daemon -q spotlessCheck
    else skip format "no spotless plugin"; fi
    gate test -- "$gw" --no-daemon check
    gate build -- "$gw" --no-daemon -q assemble
    if grep -qs 'dependencyCheck\|dependency-check' build.gradle build.gradle.kts; then
      gate_net audit -- "$gw" --no-daemon dependencyCheckAnalyze
    else
      skip audit "add the OWASP dependency-check plugin or rely on your dependency bot"
    fi
    [[ -f gradle.lockfile ]] || warn lockfile "no gradle.lockfile: enable dependency locking"
  else
    fail deps "no pom.xml or build.gradle(.kts) in this directory"
  fi
}
