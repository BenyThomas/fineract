# syntax=docker/dockerfile:1

########### Build stage (Gradle) ###########
FROM gradle:8.7.0-jdk17 AS build
WORKDIR /src

# Keep Gradle caches across builds (if BuildKit is on)
ENV GRADLE_USER_HOME=/home/gradle/.gradle

# Copy only Gradle wrapper & settings first for better caching
COPY gradlew gradlew
COPY gradle/ gradle/
COPY settings.gradle* build.gradle* gradle.properties* ./
RUN chmod +x gradlew && ./gradlew --no-daemon --version

# Now copy the rest
COPY . .

# Limit workers and set JVM heap to avoid OOM; build the bootable jar
# Try module path first (common in Fineract), then fall back to root
RUN ./gradlew --no-daemon -Dorg.gradle.workers.max=1 \
    -Dorg.gradle.jvmargs="-Xmx2g -XX:+UseG1GC -Dfile.encoding=UTF-8" \
    :fineract-provider:bootJar || \
    ./gradlew --no-daemon -Dorg.gradle.workers.max=1 \
    -Dorg.gradle.jvmargs="-Xmx2g -XX:+UseG1GC -Dfile.encoding=UTF-8" \
    bootJar

# Find the built jar (non-plain) and copy it to a fixed location
RUN JAR="$(find . -path '*/build/libs/*.jar' -not -name '*-plain.jar' | head -n1)" \
 && echo "Using JAR: $JAR" \
 && cp "$JAR" /tmp/app.jar

########### Runtime stage (JRE only) ###########
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /tmp/app.jar /app/app.jar

ENV JAVA_TOOL_OPTIONS="-XX:+UseG1GC -XX:MaxRAMPercentage=75"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=5 \
  CMD curl -fsS http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java","-jar","/app/app.jar"]
