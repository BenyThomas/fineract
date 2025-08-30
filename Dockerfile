# syntax=docker/dockerfile:1

# -------- Build stage (Gradle) --------
FROM eclipse-temurin:17-jdk AS build
WORKDIR /src

# Pre-copy Gradle wrapper & settings for better layer caching
COPY gradlew gradlew
COPY gradle gradle
COPY settings.gradle* build.gradle* gradle.properties* ./
RUN chmod +x gradlew && ./gradlew --no-daemon --version

# Copy the rest of the source and build (try module first, then root)
COPY . .
RUN ./gradlew --no-daemon -x test :fineract-provider:bootJar || \
    ./gradlew  --no-daemon -x test bootJar

# Collect the built JAR to a fixed path for the next stage
RUN JAR="$(find . -path "*/build/libs/*.jar" -not -name "*-plain.jar" | head -n1)" \
 && echo "Using JAR: $JAR" \
 && cp "$JAR" /tmp/app.jar

# -------- Runtime stage (slim JRE) --------
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /tmp/app.jar /app/app.jar

ENV JAVA_TOOL_OPTIONS="-XX:+UseG1GC -XX:MaxRAMPercentage=75"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=5 \
  CMD curl -fsS http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java","-jar","/app/app.jar"]
