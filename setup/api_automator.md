---
description: API 테스트 자동화 진입점. 실행 후 부모 Jira 이슈 URL/키를 입력받아 검증한 뒤, 워킹 디렉토리에서 실행 가능한 테스트(pytest/playwright/cypress/npm test 등)를 직접 발견·실행하고, 실패를 분석해 부모의 하위 작업(Sub-task)으로 Jira 이슈를 생성한다.
---

# /api_automator

API 테스트 자동화 진입점 — 부모 Jira 이슈 등록 → **테스트 자동 실행** → 실패 분석 → Sub-task 등록.

## Behavior

플러그인 `qa-jira-tracker` 의 skill `qa-test-error-jira` 의 **진입점 A (능동 모드)** 를 호출한다.
사용자에게 에러 보고를 받지 않는다. skill 이 직접 테스트를 찾아 실행하고 결과를 분석한다.

### Step 1. 부모 이슈 입력 (필수)

명령어 실행 즉시 다음을 묻는다.

```
이번 테스트의 결과 이슈를 어떤 Jira 부모 이슈 아래로 등록할까요?
URL 또는 이슈 키를 입력해주세요. (예: https://doverunner.atlassian.net/browse/FWM-4022 또는 FWM-4022)
```

- URL이면 `?` 이후 쿼리 제거 → `browse/` 뒤의 키만 사용.
- 키만 입력되면 그대로 사용.
- 프로젝트 키는 `-` 앞 부분에서 추출.
- `mcp__atlassian__read_jira_issue` 로 존재 검증 후 결과(키 / Summary / 상태) 회신.
- 세션 내내 부모 키 기억, 재질문 금지.

### Step 2. 테스트 자동 발견 & 실행

워킹 디렉토리에서 실행 가능한 테스트 프레임워크를 자동 탐색한다.

| 발견 신호 | 프레임워크 | 실행 명령 |
|---|---|---|
| `pytest.ini`, `pyproject.toml`의 `[tool.pytest]`, `conftest.py` | pytest | `python3 -m pytest` |
| `playwright.config.{js,ts}` | Playwright | `npx playwright test` |
| `cypress.config.{js,ts}` | Cypress | `npx cypress run` |
| `package.json`의 `scripts.test` | npm test | `npm test` |
| `Makefile`의 `test` target | make | `make test` |

여러 후보가 있으면 루트에 가까운 1개 선택. 모호하면 사용자에게 한 번만 확인. 발견 실패 시 사용자에게 실행 명령을 묻는다.

### Step 3. 결과 분석 & 실패 분류

테스트 출력에서 passed/failed/skipped 집계 + 각 실패의 TC ID, expected vs actual 추출. `results.xml`, `summary_report.html` 등 결과 파일이 있으면 활용.

5건 이상 실패면 패턴 그룹화(같은 endpoint, 같은 error_code 등).

### Step 4. 등록 전략 결정

- 0건: 통과 보고 후 종료
- 1~4건: 그대로 개별 초안 작성
- 5건 이상: 사용자에게 그룹/개별/우선순위 전략 묻기 (임의 결정 금지)

### Step 5. 초안 작성 → 사용자 일괄 승인 → 이슈 일괄 생성

`mcp__atlassian__create_jira_issue` 다중 병렬 호출. 자동 생성 금지(승인 필수).

**Description "기타" 표준 항목** (자동화 컨텍스트):
- `자동화 TC` — TC ID + 파일/함수 경로
- `환경` — 사이트, env 변수, base URL
- `추정 원인` — 1~2줄 가설 (선택)
- `관련` — 동일 패턴 다른 이슈 키 (선택)

### Step 6. 결과 보고

모든 생성된 Jira 키 + URL 을 표 형태로 회신.

## Usage

```
/api_automator
  → 부모 이슈 URL/키 입력 요청
  → 입력 → 검증
  → 워킹 디렉토리에서 테스트 발견 → 실행
  → 결과 분석 → 실패 그룹화
  → 사용자에게 등록 전략 확인 → 일괄 승인
  → Sub-task 일괄 생성 → 결과 회신
```

명령어 인자는 받지 않는다.

Skill 호출: `qa-jira-tracker:qa-test-error-jira`
