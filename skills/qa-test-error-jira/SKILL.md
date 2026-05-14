---
name: qa-test-error-jira
description: API/QA/자동화 테스트를 직접 실행해 발견된 에러·버그·예상치 못한 동작을 Jira 하위 작업(Sub-task)으로 등록한다. 부모 이슈는 테스트 시작 전 사용자가 입력한 Jira URL/키로 동적 지정한다. 트리거 — "API 테스트 시작", "QA 이슈 등록", "버그 티켓 생성", "Jira에 올려", "FWM 이슈 만들어" 등. 워킹 디렉토리에서 pytest/playwright/npm test 등 실행 가능한 테스트를 자동 발견·실행한 뒤, FWM-3385 포맷(4단 description)으로 이슈를 등록한다.
---

# QA Test Error → Jira (Auto-Run + Dynamic Parent Sub-task)

## When to use

다음 두 가지 진입점이 있다.

### 진입점 A — 테스트 세션 시작 (능동 모드)

`/api_automator` 명령 또는 다음과 같은 발화로 진입한다.

- "API 테스트 시작할게"
- "QA 테스트 진행하자"
- "이제부터 테스트 들어간다"

이 모드에서는 skill 이 **직접 워킹 디렉토리에서 테스트를 찾아 실행하고**, 그 결과를 분석해 이슈를 등록한다. 사용자에게 결과 보고를 받지 않는다.

### 진입점 B — 사용자가 자연어로 에러 보고 (수동 모드)

사용자가 "이거 이슈로 등록해줘", "버그 티켓 만들어" 라고 발화할 때. 자동화가 아닌 수동/탐색 테스트에서 발견한 케이스용. 부모 이슈가 세션에 없으면 먼저 묻는다.

### 스킵 조건

- 단순 디버깅/질문 (이슈 등록 의도 없음)
- 즉시 코드로 해결되는 사소한 사항
- 사용자가 "이슈 만들지 마"라고 명시한 경우

## Constants & Variables

| 종류 | 값 |
|---|---|
| Project key | 부모 키에서 동적 추출 (예: `FWM-4022` → `FWM`) |
| Issue type | 하위 작업 (Sub-task) — fallback "Sub-task" |
| Parent issue | **세션마다 사용자 입력** |
| Sample format | `FWM-3385` (포맷 참조) |

## Workflow (능동 모드 / 진입점 A)

### Step 1. 부모 이슈 수집 (세션 1회)

```
이번 테스트의 결과 이슈를 어떤 Jira 부모 이슈 아래로 등록할까요?
URL 또는 이슈 키를 입력해주세요. (예: https://doverunner.atlassian.net/browse/FWM-4022 또는 FWM-4022)
```

사용자 응답에서 **부모 키** 추출:

- 전체 URL: `https://doverunner.atlassian.net/browse/FWM-4022?...` → `FWM-4022`
- 이슈 키만: `FWM-4022`
- 프로젝트 키: 키의 `-` 앞 부분 (`FWM-4022` → `FWM`)

추출 즉시 `mcp__atlassian__read_jira_issue` 로 **존재 확인** 후 결과(키 / Summary / 상태) 회신. 이슈가 존재하지 않거나 접근 불가능하면 다시 입력받는다. 세션 내내 이 **parent_key**, **project_key** 를 기억하고 재질문 금지.

### Step 2. 테스트 발견 (Auto-discovery)

워킹 디렉토리에서 실행 가능한 테스트 프레임워크를 다음 우선순위로 탐색:

| 발견 신호 | 프레임워크 | 실행 명령 (작업 디렉토리 기준) |
|---|---|---|
| `pytest.ini`, `pyproject.toml`의 `[tool.pytest]`, `conftest.py` | pytest | `cd <dir> && python3 -m pytest` |
| `playwright.config.{js,ts}` | Playwright | `cd <dir> && npx playwright test` |
| `cypress.config.{js,ts}` | Cypress | `cd <dir> && npx cypress run` |
| `package.json` 의 `scripts.test` | npm test | `cd <dir> && npm test` |
| `Makefile` 의 `test` target | make | `cd <dir> && make test` |

여러 후보가 있으면 가장 가까운(루트에 가까운) 것 1개 선택. 모호하면 사용자에게 한 번만 확인.

발견 실패 시 사용자에게 **테스트 파일/실행 명령**을 묻는다.

### Step 3. 테스트 실행

발견된 명령을 Bash 로 실행. 긴 실행이 예상되면 `run_in_background` 권장. 출력은 결과 분석에 필요한 정도만 캡처(tail).

환경 변수(예: `PALLYCON_SITE`, `BASE_URL`)가 보이면 기록해 둠 → 이후 description "기타" 에 포함.

### Step 4. 결과 분석 & 실패 분류

테스트 출력에서 다음을 추출:

- 통계: passed / failed / skipped / xfailed
- 각 실패의 식별자(TC ID / 노드 ID / spec 이름)
- 실패 메시지 / assert 비교 (expected vs actual)
- 결과 파일이 있으면 활용: `results.xml`(JUnit), `summary_report.html`, `report.html`

실패가 **5건 이상**이면 패턴 그룹화 시도(같은 endpoint, 같은 error_code, 같은 메시지 차이 등). 그룹은 보고용으로만 사용하고, 등록 단위는 다음 Step 에서 사용자가 결정.

### Step 5. 등록 전략 결정 (대량 실패용)

실패 건수에 따라 분기:

- **0건**: "테스트가 모두 통과했습니다." 보고 후 종료.
- **1~4건**: 그대로 개별 이슈 초안 작성 → Step 6.
- **5건 이상**: 사용자에게 묻는다.
  - 패턴별 그룹 이슈
  - 가장 심각한 것 우선 (예: HTTP 500 / `E9999` / 서버 internal error)
  - 모두 개별 이슈
  - 일부 그룹만 우선

선택을 SKILL 이 임의로 내리지 말 것. 항상 사용자에게 묻고 그 답을 따른다.

### Step 6. 초안 작성

**Summary:**
```
[QA] {모듈/기능 경로} > {시나리오} > {발생 현상}
```

예시:
```
[QA] Session-API > JWT > Common > watermarkUrl/BNQA(트라이얼) > E9999 Internal Error 반환되는 현상
```

**Description (한국어, 4단 구조):**
```
재현 스텝 :
1. {HTTP method + URL}
2. Headers : {요약}
3. Body / Query : {요약}

발생 현상 :
- HTTP status: {코드}
- error_code: {코드}
- error_message: "{메시지}"

기대 현상 :
- error_code: {기대 코드}
- error_message: "{기대 메시지}"

기타 :
- 자동화 TC : {TC ID} ({파일경로}::{함수명}[{param}])
- 환경 : {환경명 + env var, 예: SQA REI8 (PALLYCON_SITE=REI8)}
- 추정 원인 : {짧은 가설}  ← 선택
- 관련 : {동일 패턴 이슈 키, 예: API_0039와 동일 원인}  ← 선택
```

**"기타" 표준 항목:** 자동화 컨텍스트에서 등록하는 이슈는 다음을 가능한 포함한다.

- `자동화 TC` — TC ID + 파일/함수 경로 (재현 가능성을 위해 필수)
- `환경` — 호출 대상 사이트, 환경변수, base URL
- `추정 원인` — 1~2줄 가설 (선택)
- `관련` — 같은 패턴의 다른 이슈 키 (있으면)

### Step 7. 사용자 확인 (필수)

이슈 생성 **직전**에 표/리스트 형태로 정리해 보여주고 승인받는다.

- 단일 이슈: Summary + Description 전체
- 다수 이슈: 표(TC / Summary 요약 / 기대→발생) 보여주고 "이대로 N개 일괄 생성할까요?" 질문

**자동 생성 절대 금지.** 사용자가 명시적으로 "확인 없이 바로 생성해" 라고 했을 때만 예외.

### Step 8. 이슈 생성

`mcp__atlassian__create_jira_issue` 호출:

```
projectKey: "{project_key from parent}"
issueType: "하위 작업"      # 실패 시 "Sub-task" 재시도
summary: "{초안 summary}"
description: "{초안 description}"
customFields: { "parent": { "key": "{parent_key}" } }
```

여러 건은 단일 메시지 내 **병렬 호출**로 일괄 생성 가능.

**Fallback 순서:**

1. `issueType="하위 작업"` + `customFields.parent.key`
2. 실패 시 `issueType="Sub-task"` 재시도
3. parent 필드 거부 시 → 일반 이슈로 생성 후 link API 안내
4. 모두 실패 시 사용자에게 원본 에러 그대로 보고

### Step 9. 결과 보고

- 단일: 키 + URL + 부모 키 회신
- 다수: 표 형태로 모든 키 + URL 회신

## Workflow (수동 모드 / 진입점 B)

사용자 발화에서 모듈/시나리오/재현 스텝/발생 현상/기대 현상/기타를 추출. 부족하면 **한 번에 모아서** 질문. 이후 Step 6~9 동일.

## Success criteria

- ✅ 능동 모드: 워킹 디렉토리에서 테스트를 직접 발견·실행함 (사용자에게 결과 보고를 받지 않음)
- ✅ 부모 이슈가 검증된 상태에서 등록
- ✅ Summary 가 `[QA] {경로} > {시나리오} > {현상}` 패턴
- ✅ Description 이 **재현 스텝 / 발생 현상 / 기대 현상 / 기타** 4단
- ✅ "기타" 에 자동화 TC ID, 파일·함수 경로, 환경 정보 포함
- ✅ 사용자가 초안을 사전 승인함 (대량은 일괄 승인)
- ✅ 새 이슈 키와 URL 회신
- ✅ 세션 내 동일한 부모 이슈로 재질문 없이 반복 등록 가능

## Pitfalls

- **결과 보고 의존** — "에러 보고해주세요"라고 사용자에게 미루지 말 것. 능동 모드에서는 skill 이 테스트를 직접 실행한다.
- **테스트 발견 가정** — pytest.ini 가 있어도 venv 부재로 실패할 수 있음. 의존성 누락이면 사용자에게 알리고 진행 여부 확인.
- **대량 실패 단독 결정** — 5건 이상은 임의로 그룹화/필터링하지 말고 사용자에게 전략을 물을 것.
- **부모 이슈 검증 누락** — 입력받은 키를 검증 없이 사용 금지. 반드시 `read_jira_issue` 호출.
- **세션 중 부모 변경** — 사용자가 명시할 때만 부모 변경.
- **URL 파싱** — `?atlOrigin=...` 같은 쿼리는 제거.
- **projectKey 추측** — 부모 키 prefix 에서 추출. 하드코딩 금지.
- **자동 생성 금지** — 이슈 생성 직전 항상 초안 확인.
- **issueType 명칭** — 한국어 로케일 "하위 작업" 우선, 실패 시 영문 fallback.
- **Description 언어** — 한국어 (회사 컨벤션).
- **재현 정보 부족** — "에러가 났어요" 만으로는 부족. 자동화 컨텍스트에서는 TC ID 와 파일 경로를 반드시 기록.

## Related

- Sample issue format: https://doverunner.atlassian.net/browse/FWM-3385
- Plugin: `qa-jira-tracker`
- Memory: `feedback_qa_test_error_jira.md`
