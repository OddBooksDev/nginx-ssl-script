# 필수 사항!

- 도메인과 서브 도메인이 준비되어 있어야 하며, A 레코드가 올바르게 설정되어 있어야 함
- docker 설치 필수
  - ubuntu 24 버전에서 도커 설치되었습니다.
    - [Move to Docs](https://docs.docker.com/engine/install/ubuntu/)
- docker network를 추가해야합니다. -> uponati-network
  - command
    - docker network create uponati-network
- 성공적인 SSL 인증을 위해, Nginx와 Certbot을 통한 인증서 발급 시 conf 파일에 지정된 백엔드 애플리케이션 컨테이너가 반드시 실행 중이어야 함

# 유의 사항

- certbot을 지원해주는 버전이 정해져있기 때문에 docker compose version 3.3 이하로 해야한다는 단점이 있다. 그 이상 버전은 오류를 발생한다고 함

# 사용 방법

### 1. 처음 도메인을 등록할 때 자동화 스크립트

```
chmod +x init.sh init-letsencrypt.sh

./init.sh
```

### 2. sub domain을 바라보는 CNAME 레코드 도메인들을 추가로 등록할 때 스크립트

### 입력하게 될 내용들

1. 도메인 정보(A 레코드 입력)
2. SSL에 관련된 안내 메일을 받을 이메일
3. 애플리케이션 이름(적절한 이름으로 지정, **[Ex. oddnary]** )
4. 애플리케이션 컨테이너를 띄운 PORTs (Ex. 3000 or 3000, 3001, 3002)

<details>

<summary>출처 README.md 내용 펼치기</summary>

- 참조 링크
  - **[보일러 플레이트 깃 링크 - 클릭 시 이동합니다](https://github.com/wmnnd/nginx-certbot)**

# Boilerplate for nginx with Let’s Encrypt on docker-compose

> This repository is accompanied by a [step-by-step guide on how to
> set up nginx and Let’s Encrypt with Docker](https://medium.com/@pentacent/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71).

`init-letsencrypt.sh` fetches and ensures the renewal of a Let’s
Encrypt certificate for one or multiple domains in a docker-compose
setup with nginx.
This is useful when you need to set up nginx as a reverse proxy for an
application..

## Installation

1. [Install docker-compose](https://docs.docker.com/compose/install/#install-compose).

2. Clone this repository: `git clone https://github.com/wmnnd/nginx-certbot.git .`

3. Modify configuration:

- Add domains and email addresses to init-letsencrypt.sh
- Replace all occurrences of example.org with primary domain (the first one you added to init-letsencrypt.sh) in data/nginx/app.conf

4.  Run the init script:

        ./init-letsencrypt.sh

5.  Run the server:

        docker-compose up

## Got questions?

Feel free to post questions in the xcomment section of the [accompanying guide](https://medium.com/@pentacent/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71)

## License

All code in this repository is licensed under the terms of the `MIT License`. For further information please refer to the `LICENSE` file.

</details>
