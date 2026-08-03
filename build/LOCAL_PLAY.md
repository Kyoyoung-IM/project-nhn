# Web 빌드 로컬 실행

Godot Web 빌드는 브라우저 보안 정책 때문에 `web/index.html`을 직접 더블클릭해서 실행할 수 없다. `file://`로 열면 `Failed to fetch` 또는 `NetworkError when attempting to fetch resource`가 발생한다.

## Windows 실행

1. ZIP을 원하는 폴더에 전부 압축 해제한다.
2. `play-web.cmd`를 더블클릭한다.
3. 브라우저에서 `http://127.0.0.1:8060/`이 열리면 플레이한다.
4. 플레이를 마치면 서버 창에서 `Ctrl+C`를 눌러 종료한다.

기본 포트가 사용 중이면 터미널에서 다음처럼 다른 포트를 지정할 수 있다.

```powershell
.\play-web.cmd -Port 8061
```

팀원에게 공개 URL로 공유하려면 `web/` 폴더의 내용물을 정적 Web 호스팅 서비스에 배포해야 한다.
