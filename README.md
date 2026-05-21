# qa-jira-tracker

API/QA 테스트 중 발견된 에러를 사용자가 지정한 Jira 부모 이슈의 **하위 작업(Sub-task)** 으로 등록하는 Claude Code 플러그인.

## 기능

- **`/api_automator`** — API 테스트 자동화 진입점. 실행 후 부모 Jira URL/키를 입력받아 검증한 뒤, **워킹 디렉토리에서 실행 가능한 테스트(pytest / playwright / cypress / npm test / make test)를 직접 발견·실행**하고, 실패를 분석해 부모의 하위 작업으로 Jira 이슈를 일괄 생성. **인자는 받지 않는다.**
- **두 가지 모드**
  - **능동 모드 (진입점 A)** — `/api_automator` 또는 "API 테스트 시작" 같은 발화. skill 이 직접 테스트를 찾아 실행하고 결과를 분석한다.
  - **수동 모드 (진입점 B)** — 사용자가 자연어로 에러를 보고할 때. 자동화가 아닌 탐색/수동 테스트용.

## 이슈 포맷 (DEMO-3385 기반)

**Summary:**
```
[QA] {모듈/기능 경로} > {시나리오} > {발생 현상}
```

**Description (한국어, 4단 구조):**
```
재현 스텝 : {HTTP method + URL, headers/body 요약}
발생 현상 : {HTTP status, error_code, error_message}
기대 현상 : {기대 error_code/message}
기타 :
  - 자동화 TC : {TC ID} ({파일경로}::{함수명}[{param}])
  - 환경 : {환경명 + env var}
  - 추정 원인 : {짧은 가설}   ← 선택
  - 관련 : {동일 패턴 다른 이슈 키}   ← 선택
```

자동화 컨텍스트에서 등록할 때는 "기타" 에 **자동화 TC ID + 파일/함수 경로 + 환경**을 반드시 포함한다 (재현 가능성을 위해).

## 설치

플러그인은 두 위치를 사용합니다.

```
~/.claude/plugins/marketplaces/qa-jira-tracker/     # 플러그인 (skill, marketplace)
~/.claude/commands/api_automator.md                 # 글로벌 슬래시 명령어
```

### A. 새 PC에 처음 설치 — 한 줄 부트스트랩

```bash
curl -fsSL https://raw.githubusercontent.com/SayAkhan/api_automator/main/bootstrap.sh | bash
```

`bootstrap.sh` 는 다음을 수행합니다:
1. `~/.claude/plugins/marketplaces/qa-jira-tracker/` 가 없으면 git clone, 있으면 git pull
2. 내부의 `install.sh` 호출 → 글로벌 명령어 `~/.claude/commands/api_automator.md` 설치
3. Claude Code 안에서 실행할 명령 안내

수동으로 단계 분리하고 싶다면:

```bash
git clone https://github.com/SayAkhan/api_automator.git ~/.claude/plugins/marketplaces/qa-jira-tracker
cd ~/.claude/plugins/marketplaces/qa-jira-tracker
./install.sh
```

그 다음 Claude Code 안에서:

```
/plugin marketplace add ~/.claude/plugins/marketplaces/qa-jira-tracker
/plugin install qa-jira-tracker@qa-jira-tracker
/reload-plugins
/api_automator
```

`install.sh` 는 `setup/api_automator.md` 를 `~/.claude/commands/` 로 복사합니다. 기존 파일이 있으면 timestamp backup 후 갱신합니다. `~/.claude/settings.json` 이나 plugin DB 는 건드리지 않습니다.

### B. 업데이트 (이미 설치된 PC)

```bash
# 한 줄 (bootstrap 이 pull + install 까지 처리)
curl -fsSL https://raw.githubusercontent.com/SayAkhan/api_automator/main/bootstrap.sh | bash
```

또는:

```bash
cd ~/.claude/plugins/marketplaces/qa-jira-tracker
git pull && ./install.sh
```

그 다음 Claude Code 안에서 `/reload-plugins`.

### C. 변경 사항을 원본 PC에서 push (개발자용)

```bash
cd ~/.claude/plugins/marketplaces/qa-jira-tracker
git add -A
git commit -m "..."
git push
```

## 사용 예 — 능동 모드 (실제 검증 사례)

```
/api_automator
→ "어떤 Jira 부모 이슈 아래로 등록할까요? URL 또는 이슈 키를 입력해주세요."

(사용자: https://yourcompany.atlassian.net/browse/DEMO-4022)
→ read_jira_issue 로 검증 → "부모 이슈 확인됨: DEMO-4022 [QA] Test ..."

→ 워킹 디렉토리에서 pytest.ini 발견 → `python3 -m pytest` 실행
→ 22 failed, 104 passed, 2 skipped, 2 xfailed (26.94s)
→ 5건 초과 → 패턴 그룹화 후 사용자에게 등록 전략 묻기
→ 사용자 승인 → mcp__atlassian__create_jira_issue 병렬 호출
→ DEMO-4023 ~ DEMO-4044 일괄 생성 → 결과 표로 회신
```

## 사용 예 — 수동 모드

```
(부모 이슈가 이미 세션에 등록되어 있다고 가정)

"width 6826, height 3840으로 Create Job API 호출했는데 작업이 등록됐어. E2123 에러가 나야 하는데."
→ skill이 모듈/시나리오/재현 스텝/발생/기대를 추출 (부족하면 한 번에 질문)
→ 초안 제시 → 사용자 승인 → Sub-task 생성
```

## 의존성

- MCP 서버: `mcp__atlassian` (Jira API 접근)
- Jira 프로젝트: `DEMO` (또는 부모 이슈에서 추출되는 임의 프로젝트)

## 행동 원칙

1. **자동 생성 금지** — 이슈 생성 직전 항상 사용자에게 Summary/Description 초안 확인.
2. **부모 이슈 검증** — 입력받은 키는 항상 `read_jira_issue`로 존재 확인.
3. **세션 1회 입력** — 부모 이슈는 세션 시작 시 1회 입력 후 재사용.
4. **능동 실행** — 능동 모드에서는 결과 보고를 사용자에게 미루지 않고 skill 이 직접 테스트를 실행한다.
5. **대량 실패 단독 결정 금지** — 5건 이상이면 그룹/개별 전략을 사용자에게 묻는다.
6. **언어** — Description 은 한국어 (회사 컨벤션).

## 구조

```
~/.claude/plugins/marketplaces/qa-jira-tracker/      # 플러그인 본체 (skill)
├── .claude-plugin/
│   ├── marketplace.json
│   └── plugin.json
├── skills/
│   └── qa-test-error-jira/
│       └── SKILL.md
├── setup/
│   └── api_automator.md                             # 글로벌 명령어 소스 (배포용)
├── bootstrap.sh                                     # 새 PC 한 줄 설치 (curl | bash)
├── install.sh                                       # 글로벌 명령어 자동 설치 (bootstrap 이 호출)
├── .gitignore
└── README.md

~/.claude/commands/api_automator.md                  # install.sh 가 복사하는 위치
```

> 명령어를 플러그인 내부 `commands/` 에 두면 `/qa-jira-tracker:api_automator` 처럼 네임스페이스 prefix 가 강제되므로, `setup/` 아래에 두고 `install.sh` 가 사용자 글로벌 디렉토리(`~/.claude/commands/`) 에 복사합니다. 결과적으로 `/api_automator` 짧은 형태로 호출되며, 둘 다 같은 skill(`qa-jira-tracker:qa-test-error-jira`) 을 호출합니다.

