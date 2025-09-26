# syntax=docker/dockerfile:1

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app

# The workflow stages a single file: docker-context/app.jar
COPY app.jar /app/app.jar

EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
