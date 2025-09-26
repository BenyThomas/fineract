# syntax=docker/dockerfile:1

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app

# Path where the CI step produced jars
ARG JAR_PATH=fineract-provider/build/libs

# Copy the first non-plain jar we find (boot jar)
# If your artifact naming differs, adjust the glob below.
COPY ${JAR_PATH}/*.jar /app/

# Pick the jar at runtime
RUN JAR="$(ls -1 /app/*.jar | grep -v -- '-plain.jar' | head -n1)" && \
    ln -s "$JAR" /app/app.jar

EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
