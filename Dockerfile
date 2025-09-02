
# syntax=docker/dockerfile:1
FROM gradle:8.10.2-jdk21 AS build
WORKDIR /src
ENV GRADLE_USER_HOME=/home/gradle/.gradle
COPY gradlew gradlew
COPY gradle/ gradle/
COPY settings.gradle* build.gradle* gradle.properties* ./
RUN chmod +x gradlew && ./gradlew --no-daemon --version
COPY . .
RUN ./gradlew --no-daemon -Dorg.gradle.workers.max=1 \
    -Dorg.gradle.jvmargs="-Xmx2g -XX:+UseG1GC -Dfile.encoding=UTF-8" \
    :fineract-provider:bootJar || \
    ./gradlew  --no-daemon -Dorg.gradle.workers.max=1 \
    -Dorg.gradle.jvmargs="-Xmx2g -XX:+UseG1GC -Dfile.encoding=UTF-8" \
    bootJar
RUN JAR="$(find . -path '*/build/libs/*.jar' -not -name '*-plain.jar' | head -n1)" \
 && echo "Using JAR: $JAR" && cp "$JAR" /tmp/app.jar

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /tmp/app.jar /app/app.jar
ENV JAVA_TOOL_OPTIONS="-XX:+UseG1GC -XX:MaxRAMPercentage=75 -Dfile.encoding=UTF-8"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=5 \
  CMD curl -fsS http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java","-jar","/app/app.jar"]