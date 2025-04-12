FROM openjdk:17-jdk-slim
ADD build/libs/*.jar app.jar
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./ugit push origin main --forcerandom","-jar","/app.jar"]
