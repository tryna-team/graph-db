# Tryna 학교·학업·스터디 KB v0.1

짧은 일정 제목에서도 `공부`, `스터디`, `수업`, `시험`, `과제`처럼 실제 행동이 있을 때만 학업 추천을 여는 기초 지식베이스다. `학교`, `도서관`, `카페`, 사람 이름처럼 목적이 불분명한 단독 키워드에는 추천하지 않는다.

## 파일

- `tryna_academic_knowledge_base_v0.1.cypher`: Academic 노드, 추천 관계, 기존 분류 노드 호환 migration, smoke check
- `../teamProject/tryna_team_project_queries_v0.5.cypher`: embedding 적재 A·B, EventType 조회 C, PlaceType 조회 E
- `../travel/tryna_travel_queries_v0.1.cypher`: Context 조회·확장 A·B, 관계 후보 C, graph-gated 추천 벡터 후보 D

## 이번 버전의 구조

신규 노드는 17개다.

| 라벨 | 개수 | 코드 |
|---|---:|---|
| `Context` | 1 | `academic` |
| `EventType` | 4 | `self_study`, `group_study`, `class_session`, `exam` |
| `PlaceType` | 0 | 기존 `school`, `library`, `cafe`, `online` 재사용 |
| `RecommendationTemplate` | 12 | 학습 목표, 자료, 수업, 시험, 과제, 학습 공간 관련 추천 |

신규 `RECOMMENDS`는 36개다.

| 출발 노드 | 관계 수 |
|---|---:|
| `academic` Context | 3 |
| 신규 EventType 4개 | 29 |
| 기존 `assignment` EventType | 2 |
| 기존 `library`, `cafe` PlaceType | 2 |

기존 `assignment`의 추천 관계 4개는 새로 만들지 않고 개인 과제에도 쓸 수 있도록 `requiredContexts = []`로 범용화한다. 따라서 Academic 관계 수에 이 4개를 다시 더하지 않는다.

팀플 v0.5, 여행 v0.1, Hangout v0.1이 정확히 적용된 DB에 추가하면 전체 기대값은 다음과 같다.

```text
Context                  6
EventType               12
PlaceType               11
RecommendationTemplate  62
전체 노드               91
RECOMMENDS              162
IS_A                      2
```

## 실행 순서

이 파일에는 독립 Cypher statement가 24개 들어 있다. Neo4j Query에서 **파일 전체를 한 번에 실행하지 말고**, 세미콜론(`;`)을 기준으로 위에서부터 한 statement씩 실행한다.

1. `teamProject v0.5 → travel v0.1 → hangout v0.1`이 적용된 같은 database를 선택한다.
2. `tryna_academic_knowledge_base_v0.1.cypher`를 위에서부터 실행한다.
3. assignment migration 결과를 확인한다.

```text
updatedEventType = assignment
generalizedAssignmentRelationshipCount = 4
updatedContextExclusionCount = 4
updatedEventTypeExclusionCount = 4
resetSharedRecommendationCount = 1
removedObsoleteRelationshipCount = 0 또는 5
removedObsoleteRecommendationCount = 0 또는 1
```

`updatedContextExclusionCount`나 `updatedEventTypeExclusionCount`가 4보다 작거나 `resetSharedRecommendationCount`가 1이 아니면 선행 카테고리 중 일부가 같은 database에 없는 것이다. 삭제 count는 이 수정본을 처음 실행하면 `0 / 0`, 학생증·계산기·물 추천이 있던 직전 초안을 이미 실행했다면 최대 `5 / 1`이 정상이다.

4. 공용 노드 확인 결과를 확인한다.

```text
missingSharedCodes = []
missingSharedEventTypes = []
missingSharedPlaceTypes = []
```

배열에 코드가 하나라도 나오면 뒤의 관계 생성으로 넘어가지 말고 선행 seed부터 확인한다. `MATCH`는 대상이 없을 때 오류 대신 관계 0개를 만들기 때문에 이 확인이 중요하다.

5. 마지막 smoke check의 기대값을 확인한다.

```text
Context                 1
EventType               4
RecommendationTemplate 12
RECOMMENDS              36
invalidRelationshipCount 0
academicRecommendationCount 12
invalidRecommendationCount 0
```

신규 PlaceType이 없으므로 첫 smoke check 결과에 `PlaceType` 행이 나오지 않는 것이 정상이다. 같은 파일을 다시 실행해도 `MERGE` 때문에 노드와 관계 수는 늘어나지 않는다.

## Embedding 반영

기존 74개 노드의 embedding이 최신이었다면 이번 적재 대상은 보통 18개다.

```text
신규 Academic 노드 17개
+ embeddingText가 바뀐 기존 assignment 1개
= 18개
```

직전 초안의 범용 `pack_id` embedding까지 이미 저장했다면 여행용 원문으로 되돌린 `pack_id`도 한 번 다시 임베딩해 총 19개가 된다.

`assignment`는 기존 노드라서 `seedSource = 'academic_v0.1'`로 찾으면 누락된다. 반드시 공용 쿼리 A처럼 `embeddingSourceText <> embeddingText`까지 비교해 대상을 조회한다.

기존 vector index는 라벨 전체를 대상으로 하므로 새 인덱스를 만들 필요가 없다. Upstage embedding을 저장한 뒤 실제 점수 분포로 Context·EventType·PlaceType 임계값을 각각 보정한다.

`exclusionExamples`는 Neo4j가 자동 차단하는 규칙이 아니다. 벡터 후보와 함께 LLM 판별 단계에 전달하거나, 아래 회귀 입력의 점수와 top-1/top-2 차이를 보면서 임계값을 조정해야 한다.

## 추천 gate

- Context와 EventType이 둘 다 없으면 PlaceType만 잡혀도 추천 결과는 0개다.
- `library → check_study_space_access`, `cafe → check_study_space_access` 관계는 `requiredContexts = ['academic']`이다.
- 추천 벡터 검색도 현재 확정된 Context·EventType·PlaceType에서 실제로 이어지는 추천 노드만 허용한다.
- 강의실·건물 확인은 첫 수업, 신입생, 익숙하지 않은 강의동 같은 단서가 있을 때만 선택하는 contextual 추천이다.
- 충전기와 보조배터리는 후보에 들어갈 수 있지만 노트북 사용이나 장시간 외부 학습 단서가 없으면 최종 LLM이 선택하지 않는다.

즉, 아래처럼 처리한다.

```text
카페          → cafe만 가능, 추천 0개
카페 약속     → hangout + cafe, Hangout 추천
카페 공부     → academic + self_study + cafe, 학업 추천
```

## 최소 회귀 입력

| 입력 | 기대 분류 | 최소 기대 추천 | 금지 |
|---|---|---|---|
| `민수` | 모두 null | 0개 | 모든 학업 추천 |
| `학교` | school만 가능 | 0개 | 수업 자동 추론 |
| `도서관` | library만 가능 | 0개 | 개인 공부 자동 추론 |
| `스터디카페` | PlaceType만 가능 | 0개 | 그룹 스터디 자동 추론 |
| `일본어 공부` | academic + self_study | 학습 범위, 교재 | 해외여행·여권 |
| `카페 공부` | academic + self_study + cafe | 학습 준비, 공간 운영시간 | 약속·예약 추천 |
| `민수 스터디` | academic + group_study | 시간·장소, 자료 | 식사·영화 추천 |
| `시험 공부` | academic + self_study | 학습 범위, 자료 | 시험 당일 준비물 자동 확정 |
| `중간고사` | academic + exam | 시험 시간, 범위, 준비물 | 여행·티켓 추천 |
| `수업` | academic + class_session | 시간·강의실, 공지 | Hangout 추천 |
| `온라인 강의` | academic + class_session + online | 수업 공지·자료 | 온라인 회의 추천 |
| `과제` | academic + assignment | 마감, 요구사항 | team_project 강제 |
| `팀플 제출` | team_project + assignment | 마감, 요구사항, 파일 | 같은 code 중복 행 |
| `일본 여행` | travel | 여행 추천 | Academic 추천 |
| `친구랑 카페` | hangout + cafe | 약속 추천 | 공부 공간 추천 |
| `도서관 책 반납` | library만 가능 | 0개 | 개인 공부 추천 |

## Assignment migration 확인

기존 4개 관계의 gate가 제거됐는지 확인한다.

```cypher
MATCH (:EventType {code: 'assignment'})-[rel:RECOMMENDS]->(r:RecommendationTemplate)
WHERE r.code IN [
  'check_deadline',
  'check_submission_location',
  'open_final_file',
  'save_final_backup'
]
RETURN
  r.code AS code,
  rel.requiredContexts AS requiredContexts,
  rel.academicCompatibilityVersion AS version
ORDER BY code;
```

네 행 모두 `requiredContexts = []`, `version = '0.1'`이어야 한다. `assignment`의 전체 추천 관계는 6개다.

## 전체 DB와 Bloom 확인

전체 라벨 수와 관계 수:

```cypher
MATCH (n)
WHERE n:Context OR n:EventType OR n:PlaceType OR n:RecommendationTemplate
WITH labels(n)[0] AS label, count(*) AS nodeCount
RETURN label, nodeCount
ORDER BY label;
```

```cypher
MATCH ()-[r]->()
RETURN type(r) AS relationshipType, count(*) AS relationshipCount
ORDER BY relationshipType;
```

Bloom에서 Academic 신규 노드와 재사용한 `assignment`까지 한 장면으로 확인하려면 다음 쿼리를 사용한다.

```cypher
MATCH (n)
WHERE n.seedSource = 'academic_v0.1'
   OR (n:EventType AND n.code = 'assignment')
OPTIONAL MATCH (n)-[r]-()
WHERE r.seedSource = 'academic_v0.1'
   OR r.academicCompatibilityVersion = '0.1'
RETURN n, r
LIMIT 250;
```

Bloom 화면에 보이는 수는 database 전체 count가 아니라 현재 scene에 로드된 결과 수다. 노드 수 검증은 위 count 쿼리 결과를 기준으로 한다.
