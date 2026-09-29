# Tryna 직장·취업 KB v0.1

사회초년생이 자주 놓치는 면접, 첫 출근, 평소와 다른 출근, 외부 업무 미팅의 작은 준비를 제안하는 기초 지식베이스다. 회사명·사람명·장소명만 입력했거나 평범한 매일 출근이라면 추천하지 않는다.

## 파일

- `tryna_work_career_knowledge_base_v0.1.cypher`: Work/Career 노드, 기존 공용 노드 migration, 추천 관계, smoke check
- `../teamProject/tryna_team_project_queries_v0.5.cypher`: embedding 적재 A·B, EventType 조회 C, PlaceType 조회 E
- `../travel/tryna_travel_queries_v0.1.cypher`: Context 조회·확장 A·B, 관계 후보 C, graph-gated 추천 벡터 후보 D

## 범위와 규모

신규 노드는 13개다.

| 라벨 | 개수 | 코드 |
|---|---:|---|
| `Context` | 1 | `work_career` |
| `EventType` | 4 | `job_interview`, `first_day_onboarding`, `nonroutine_commute`, `external_work_meeting` |
| `PlaceType` | 0 | 온라인 일정은 기존 `online` 재사용 |
| `RecommendationTemplate` | 8 | 면접 안내·공고·지원서, 첫 출근 안내·요청 서류, 담당자·복장·출입 관련 추천 |

신규 `RECOMMENDS`는 27개다.

```text
job_interview          8
first_day_onboarding   7
nonroutine_commute     3
external_work_meeting  9
Context 관계           0
```

기존 Academic까지 정확히 적용된 DB에 추가하면 전체 기대값은 다음과 같다.

```text
Context                  7
EventType               16
PlaceType               11
RecommendationTemplate  70
전체 노드              104

RECOMMENDS              189
IS_A                      2
전체 관계              191
```

## 의도적으로 넣지 않은 추천

- 평범한 매일 출근의 교통편 반복 확인
- 물·보조배터리·충전기
- 무조건 신분증 또는 인쇄한 이력서
- 무조건 정장
- 무조건 노트북
- 특정 입사 서류를 임의로 단정
- 고정된 `10~15분 전 도착`

복장과 준비서류는 회사가 실제로 안내했는지 확인하는 수준으로만 제안한다. 제출 지원자료는 실제 제출 여부를 확인할 수 있을 때만 선택하고, 외부 미팅의 노트북도 입력에 사용 단서가 있을 때만 최종 LLM이 선택한다.

## 실행 순서

이 파일에는 독립 Cypher statement가 20개 있다. 파일 전체를 한 번에 실행하지 말고 세미콜론(`;`)을 기준으로 위에서부터 한 statement씩 실행한다.

1. `teamProject → travel → hangout → academic`이 적용된 같은 database를 선택한다.
2. `tryna_work_career_knowledge_base_v0.1.cypher`를 위에서부터 실행한다.
3. 호환 migration 결과를 확인한다.

```text
updatedMeetingCount = 1
updatedContextExclusionCount = 4
updatedEventTypeExclusionCount = 4
generalizedMeetingRelationshipCount = 3
updatedSharedRecommendationCount = 3
gatedOfflineRecommendationCount = 3
```

4. 공용 노드 확인 결과를 확인한다.

```text
missingSharedCodes = []
missingSharedEventTypes = []
missingSharedPlaceTypes = []
```

5. 마지막 smoke check를 확인한다.

```text
Context                 1
EventType               4
RecommendationTemplate 8
RECOMMENDS              27
invalidRelationshipCount 0
workCareerRecommendationCount 8
invalidRecommendationCount 0
```

신규 PlaceType과 Context 추천 관계가 없으므로 해당 행이나 관계가 나오지 않는 것이 정상이다. 재실행해도 `MERGE` 때문에 개수가 늘어나지 않는다.

## Embedding 반영

기존 91개 노드의 embedding이 최신이었다면 최대 17개를 다시 적재한다.

```text
신규 Work/Career 노드 13개
+ embeddingText가 바뀐 기존 노드 4개
  - meeting
  - check_location
  - check_online_link
  - check_microphone
= 17개
```

기존 vector index는 라벨 전체를 대상으로 하므로 새 인덱스는 만들지 않는다. 공용 embedding 조회 쿼리 A처럼 `embeddingSourceText <> embeddingText`를 비교해야 변경된 기존 노드도 빠지지 않는다.

## 시간 정보

각 추천에는 사람에게 보여줄 기본 가이드인 `defaultTiming`만 저장한다. 현재 온톨로지 컨벤션과 D102·D103 전달 계약에는 Neo4j `offsetDays`가 포함되어 있지 않으므로 이 seed가 임의로 추가하지 않는다.

D104에서 시간형 항목을 만들려면 승인된 서버 설정에서 `sourceCode`별 `offsetDays`를 관리한다. v0.1에서 우선 검토할 수 있는 값은 다음과 같다.

| `sourceCode` | 권장 `offsetDays` |
|---|---:|
| `review_interview_notice` | `-1` |
| `review_job_posting` | `-1` |
| `review_submitted_application` | `-1` |
| `review_first_day_notice` | `-1` |
| `check_requested_documents` | `-1` |

위 값은 서버의 승인된 시간 설정으로 관리하며 `defaultTiming` 자연어를 런타임에서 임의 변환하지 않는다. D104의 시간형 항목 최대 2개 제한은 그대로 적용한다.

## 핵심 gate

- `work_career` Context 자체에는 추천 관계가 없다.
- 회사명, 사람명, 장소명만 입력하면 추천 0개다.
- 일반 `출근`도 EventType으로 만들지 않아 추천 0개가 기본이다.
- `nonroutine_commute`는 다른 지점, 새 사무실, 이른 출근처럼 평소와 다른 단서가 있어야 한다.
- `online` PlaceType이 잡히면 `check_location`, `check_travel_time`, `check_transport`, `check_workplace_access`를 Cypher 조회 단계에서 제외한다.

따라서 온라인 면접은 접속 링크와 카메라·마이크 후보를 받고, 물리적 장소와 이동 후보는 받지 않는다.

`exclusionExamples`는 Neo4j가 자동으로 적용하는 규칙이 아니다. EventType·Context 벡터 후보와 함께 LLM 판별 단계에 전달하고 실제 embedding 점수로 임계값을 보정한다.

## 최소 회귀 입력

| 입력 | 기대 분류 | 최소 기대 추천 | 금지 |
|---|---|---|---|
| `삼성전자` | 모두 null 권장 | 0개 | 면접·출근 추천 |
| `김대리` | 모두 null | 0개 | 업무 미팅 추천 |
| `회사` | 모두 null 권장 | 0개 | 첫 출근 준비 |
| `출근` | work_career만 허용 | 0개 | 교통 반복 추천 |
| `면접` | work_career + job_interview | 안내, 채용공고 | Hangout·Academic |
| `온라인 면접` | work_career + job_interview + online | 안내, 접속 링크, 카메라·마이크 | 장소·이동 추천 |
| `면접 스터디` | academic + group_study | 학업 추천 | 실제 면접 물류 추천 |
| `취업 면접 특강` | academic + class_session | 수업 추천 | 채용 면접 준비 추천 |
| `모의면접 연습` | EventType null 권장 | 0개 | 장소·담당자 추천 |
| `첫 출근` | work_career + first_day_onboarding | 첫 출근 안내, 요청 서류 | 일반 출근 추천 |
| `입사 오리엔테이션` | work_career + first_day_onboarding | 시간·장소·담당자 | 학교 수업 추천 |
| `첫날 온라인 오리엔테이션` | 위 분류 + online | 안내, 접속 링크 | 장소·이동 추천 |
| `평소 출근` | EventType null | 0개 | 첫 출근 준비 |
| `다른 지점 출근` | work_career + nonroutine_commute | 장소, 이동시간 | 면접·온보딩 추천 |
| `재택근무` | EventType null | 0개 | 이동 추천 |
| `거래처 미팅` | work_career + external_work_meeting | 시간, 장소, 논의 내용 | TeamProject·Hangout |
| `온라인 거래처 미팅` | 위 분류 + online | 시간, 파일, 접속 링크 | 장소·이동 추천 |
| `회사 주간회의` | work_career + 기존 meeting | 시간, 논의 내용, 파일 | 외부 출입 추천 |
| `팀플 미팅` | team_project + meeting | 기존 팀플 추천 | Work/Career 추천 |
| `친구랑 미팅` | hangout 권장 | 약속 추천 또는 0개 | 업무 추천 |
| `회사에서 친구랑 점심` | hangout + dining_meetup | 식사 약속 추천 | 업무 추천 |
| `노트북 들고 고객사 미팅` | work_career + external_work_meeting | 파일, 노트북 조건부 | 일반 출근 추천 |
| `직장 동료 결혼식` | social_occasion + wedding | 경조사 안내·장소 후보 | 업무 미팅 추천 |
| `회사 선배 조문` | social_occasion + funeral | 부고·빈소·조문 시간 후보 | 업무 미팅 추천 |
| `거래처 장례식장 방문` | social_occasion + funeral | 빈소·장소·이동 후보 | 고객사 미팅 추천 |

각 입력에서 Context·EventType·PlaceType 후보, 관계 후보, 벡터 후보, LLM 최종 결과를 따로 기록한다.

마지막 세 경조사 회귀 입력은 `socialOccasion v0.1`까지 같은 database에 적용한 뒤 검증한다.

## Bloom에서 확인

```cypher
MATCH (n {seedSource: 'work_career_v0.1'})
OPTIONAL MATCH (n)-[r]-()
WHERE r.seedSource = 'work_career_v0.1'
RETURN n, r
LIMIT 250;
```

Bloom scene의 숫자는 database 전체 count가 아니라 현재 불러온 결과 수다. 전체 수는 별도의 count 쿼리로 확인한다.
