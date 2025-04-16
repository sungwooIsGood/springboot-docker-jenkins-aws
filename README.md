# spring server - nginx - aws- jenkins 서버 구축 study

## 1. Nginx 리버스 프록시 설정 (80 → 8080 포트)

### 1. Nginx 기본 설정 파일 열기

Ubuntu 계열에서는 보통 아래 파일을 수정

```bash
sudo vi /etc/nginx/sites-available/default
```

---

### 2. location 설정 수정하기

파일 내 `server {}` 블록 안에 있는 기존 `location /` 부분을 아래와 같이 수정

### 🔹 수정 전

```
location / {
    try_files $uri $uri/ =404;
}
```

### 🔹 수정 후

```
location / {
    proxy_pass http://127.0.0.1:8080/;
    proxy_set_header Host $host; # 원래 요청의 Host 값을 유지해서 전달.
    proxy_set_header X-Real-IP $remote_addr; # 클라이언트의 실제 IP 주소를 전달.
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; # 프록시를 거쳐온 모든 IP 목록을 전달.
    proxy_set_header X-Forwarded-Proto $scheme; # 요청이 HTTP인지 HTTPS인지 알려줌.
}

location /jenkins/ {
    proxy_pass http://127.0.0.1:9999/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

}

```

### 주의 점

**`proxy_pass` 뒤에 슬래시**를 추가하면, nginx가 `/jenkins/` 경로를 Jenkins로 전달할 때 경로를 올바르게 처리할 수 있도록 합니다. 이로 인해 리다이렉트 시에 `/jenkins/login`과 같은 경로가 정상적으로 리다이렉트된다.

---

### 3. 설정 적용

```bash
# 설정 테스트
sudo nginx -t

# Nginx 재시작
sudo systemctl restart nginx
```

---

## ✅ 참고

- `/etc/nginx/sites-enabled/`에는 `/sites-available/default` 파일이 심볼릭 링크로 연결되어 있다.
- 추후 여러 서비스 관리가 필요할 경우, `sites-available/`에 별도의 설정 파일을 만들어 관리하는 것이 권장 된다고 한다.
    - `sites-available/` ⇒ 설정 파일을 두는 곳 (실제 원본)
    - `sites-enabled/` ⇒ 활성화할 설정에 대한 **심볼릭 링크**를 두는 곳으로 이렇게 하면 여러 설정 파일을 관리하기 쉬워진다.
    
    ```scss
    /etc/nginx/
    ├── sites-available/
    │   └── default  ← (실제 설정 파일)
    │   └── my-app  ← (내가 따로 만든 설정 파일)
    ├── sites-enabled/
    │   └── default  ← (sites-available/default 링크)
    │   └── my-app  ← (sites-available/my-app 링크)
    ```
    
- 지금은 실습을 위해 `/etc/nginx/sites-available/default`에 설정했지만, 나중엔 `default` 파일 말고 **내 서비스 전용 설정 파일을 따로 만들어서** 관리하자.

---

## 2. Spring boot 서버에다  Dockerfile 작성

### 1. 서버에 java 17버전 다운

```bash
sudo apt install openjdk-17-jdk -y
```

### 2. Dockerfile 작성

```docker
FROM openjdk:17-jdk-slim
ADD /build/libs/*.jar app.jar
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./ugit push origin main --forcerandom","-jar","/app.jar"]
```

---

## 3. jenkins

- Jenkins를 실행하려면 Java가 필요하지만, 모든 Linux 배포판에 Java가 기본적으로 포함되어 있는 것이 아니기 때문에 설치해주고 시작하자.

### 1. 서버에 젠킨스 다운로드

```bash
# Jenkins 설치 가이드 (Ubuntu 24.04 기준)

## 🔧 Jenkins 설치 (LTS 버전)

# Jenkins GPG 키 등록
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

# Jenkins 저장소 추가
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
/etc/apt/sources.list.d/jenkins.list > /dev/null

# 패키지 정보 업데이트
sudo apt-get update

# Jenkins 설치
sudo apt-get install jenkins
```

### Jenkins 기본 포트

- Jenkins는 기본적으로 **8080번 포트**에서 동작한다.
- 브라우저에서 아래 주소로 접속 가능:

```
http://<your-server-ip>:8080
```

---

### Jenkins 포트 변경 방법

사정상 한대의 서버에 이것저것 설치해서 쓸 경우 8080포트는 사용하기 어렵다. 그렇기때문에 변경해주는 것이 좋다.

```bash
(1) Jenkins Version 2.335 이전일 경우

$ sudo vi /etc/default/jenkins
 

(2) Jenkins Version 2.335 이후일 경우

$ sudo vi /lib/systemd/system/jenkins.service
```

1. 아래와 같이 `HTTP_PORT` 값을 원하는 포트 번호로 변경하면 된다.

```bash
Environment="JENKINS_PORT=9999"
```

1. Jenkins 서비스를 재시작 혹은 시작하면 된다.

```bash
sudo systemctl restart jenkins
```

### Jenkins 서비스 상태 확인

```bash
sudo systemctl status jenkins
```

### 파일 위치와 각 파일의 쓰임새 및 유의 사항

| 파일 경로 | 역할 | 주요 설정 항목 | 수정 시 주의사항 |
| --- | --- | --- | --- |
| `/etc/default/jenkins` | Jenkins **실행 환경 변수 설정 파일**(Ubuntu/Debian 전용) | - HTTP 포트 (`HTTP_PORT`)- Jenkins 홈 (`JENKINS_HOME`)- Java 옵션 (`JAVA_ARGS`)- JAVA_HOME 설정 등 | 수정 후 `sudo systemctl restart jenkins` 필요 |
| `/usr/lib/systemd/system/jenkins.service` | Jenkins의 **systemd 서비스 유닛 파일**(실제 데몬 동작 방식 정의) | - `ExecStart`로 실행 명령 지정- 사용자(`User`), 그룹(`Group`) 설정- 서비스 동작 방식 (Type, Restart 등) | 이 파일 직접 수정하면 나중에 패키지 업데이트 시 덮어씌워질 수 있음.수정 후 `sudo systemctl daemon-reload` 필수 |
| `sudo systemctl edit jenkins`→ `/etc/systemd/system/jenkins.service.d/override.conf` | **공식적으로 권장되는 커스터마이징 방법**기존 systemd 설정의 일부만 오버라이드 | 위 `.service` 파일과 동일한 형식으로 필요한 부분만 덮어쓰기 | 안전하게 수정 가능,패키지 업데이트에 영향 없음.수정 후 `daemon-reload` 및 `restart` 필요 |

### 추천 사용 방식

- **포트, 환경 변수** 등은 → `/etc/default/jenkins` 에서 설정
- **서비스 실행 방식 변경**은 → `sudo systemctl edit jenkins` 로 override
- `jenkins.service` 직접 수정은 가능하지만 **권장되지 않음**
