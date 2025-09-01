# syntax=docker/dockerfile:1

########### Build stage (Gradle, JDK 21) ###########
FROM gradle:8.10.2-jdk21 AS build
WORKDIR /src
ENV GRADLE_USER_HOME=/home/gradle/.gradle

# Cache-friendly: copy wrapper & settings first
COPY gradlew gradlew
COPY gradle/ gradle/
COPY settings.gradle* build.gradle* gradle.properties* ./
RUN chmod +x gradlew && ./gradlew --no-daemon --version

# Project sources
COPY . .

# Constrain Gradle to avoid OOMs on small VMs
# Try module bootJar first (common for Fineract), then fallback to root
RUN ./gradlew --no-daemon -Dorg.gradle.workers.max=1 \
    -Dorg.gradle.jvmargs="-Xmx2g -XX:+UseG1GC -Dfile.encoding=UTF-8" \
    :fineract-provider:bootJar || \
    ./gradlew  --no-daemon -Dorg.gradle.workers.max=1 \
    -Dorg.gradle.jvmargs="-Xmx2g -XX:+UseG1GC -Dfile.encoding=UTF-8" \
    bootJar

# Pick the first non-plain jar produced
RUN JAR="$(find . -path '*/build/libs/*.jar' -not -name '*-plain.jar' | head -n1)" \
 && echo "Using JAR: $JAR" \
 && cp "$JAR" /tmp/app.jar

########### Runtime stage (JRE 21) ###########
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /tmp/app.jar /app/app.jar

ENV JAVA_TOOL_OPTIONS="-XX:+UseG1GC -XX:MaxRAMPercentage=75 -Dfile.encoding=UTF-8"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=5 \
  CMD curl -fsS http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java","-jar","/app/app.jar"]
