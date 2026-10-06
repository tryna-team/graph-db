# Tryna 경조사 KB v0.1

생일·생신, 결혼식, 돌잔치, 조문처럼 경조사 일정에서 놓치기 쉬운 작은 준비를 제안하는 기초 지식베이스다. 사람 이름이나 장소 이름만 입력했거나 `경조사`처럼 구체 유형이 없는 입력에는 추천하지 않는다.

## 파일

- `tryna_social_occasion_knowledge_base_v0.1.cypher`: 경조사 분류 노드, 기존 카테고리 호환 migration, 추천 항목과 관계, smoke check
- `../teamProject/tryna_team_project_queries_v0.5.cypher`: embedding 적재 A·B, EventType 조회 C, PlaceType 조회 E
- `../travel/tryna_travel_queries_v0.1.cypher`: Context 조회·확장 A·B, 관계 후보 C, graph-gated 추천 벡터 후보 D

## 범위와 규모

신규 노드는 17개다.

| 라벨 | 개수 | 코드 |
|---|---:|---|
| `Context` | 1 | `social_occasion` |
| `EventType` | 4 | `birthday`, `wedding`, `first_birthday`, `funeral` |
| `PlaceType` | 0 | 장소 유형만으로 경조사를 추론하지 않음 |
| `RecommendationTemplate` | 12 | 경조사 안내·선물·케이크·축하금·조의금·복장·빈소 관련 추천 |

신규 `RECOMMENDS`는 23개다.

```text
birthday          5
wedding           5
first_birthday    5
funeral           8
Context 관계      0
```

기존 Work/Career까지 정확히 적용된 DB에 추가하면 전체 기대값은 다음과 같다.

```text
Context                   8
EventType                20
PlaceType                11
RecommendationTemplate   82
전체 노드                121

RECOMMENDS               212
IS_A                       2
전체 관계                214
```

## 지원 범위

### 생일·생신

- 선물 준비 여부
- 주문한 선물의 배송 예정일
- 케이크 예약·수령 여부
- 함께 식사하는 경우 예약 여부
- 당일 축하 메시지 준비

`내 생일`과 `내 생일 파티 준비`는 다른 사람을 챙기는 추천과 맞지 않으므로 v0.1에서 제외한다.

### 결혼식

- 청첩장과 안내 내용 확인
- 정확한 장소와 이동시간 확인
- 축하금·봉투 준비 여부
- 별도로 안내된 복장 확인

`내 결혼식`, 웨딩 촬영, 상견례, 예식장 계약처럼 직접 결혼을 준비하는 일정은 범위가 크므로 제외한다.

### 돌잔치

- 초대 안내와 장소 확인
- 이동시간 확인
- 선물 또는 축하금 준비 여부

`우리 아이 돌잔치 준비`, 돌상 준비, 장소 계약처럼 행사를 주최하는 일정은 제외한다.

### 조문·장례식장 방문

장례식은 사전 며칠 전에 계획하기보다 당일 잡히는 경우가 많으므로 다음처럼 출발 전에 확인할 수 있는 최소 후보만 둔다.

- 부고 안내 확인
- 장례식장과 빈소 호실 확인
- 조문 가능 시간과 발인 시각 확인
- 장소와 이동시간 확인
- 조의금·봉투 준비 여부
- 단정한 조문 복장 준비

조의금 액수, 조문 문구, 고인과 사용자의 관계, 유가족에게 할 행동은 추론하거나 생성하지 않는다.

## 실행 순서

이 파일에는 독립 Cypher statement가 14개 있다. 파일 전체를 한 번에 실행하지 말고 세미콜론(`;`)을 기준으로 위에서부터 한 statement씩 실행한다.

1. `teamProject → travel → hangout → academic → workCareer`가 적용된 같은 database를 선택한다.
2. `tryna_social_occasion_knowledge_base_v0.1.cypher`를 위에서부터 실행한다.
3. 기존 분류 노드 migration 결과를 확인한다.

```text
updatedContextExclusionCount = 3
updatedEventTypeExclusionCount = 3
```

4. 공용 노드 확인 결과를 확인한다.

```text
missingSharedCodes = []
```

5. 마지막 smoke check를 확인한다.

```text
Context                         1
EventType                       4
RecommendationTemplate        12
RECOMMENDS                     23
invalidRelationshipCount        0
socialOccasionRecommendationCount 12
invalidRecommendationCount      0
```

재실행해도 `MERGE` 때문에 같은 code의 노드와 관계가 중복 생성되지 않는다.

## 시간 정보

각 추천에는 사람에게 보여줄 기본 가이드인 `defaultTiming`만 저장한다. 현재 온톨로지 컨벤션과 D102·D103 전달 계약에는 Neo4j `offsetDays`가 포함되어 있지 않으므로 이 seed가 임의로 추가하지 않는다.

D104에서 시간형 항목을 만들려면 승인된 서버 설정에서 `sourceCode`별 `offsetDays`를 관리한다. 장례식 관련 추천은 당일 갑자기 잡히는 상황을 고려해 기본적으로 비시간형 준비 항목으로 처리하는 것을 권장한다.

## 분류 및 추천 원칙

- `social_occasion` Context 자체에는 추천 관계가 없다.
- 구체적인 EventType이 없으면 추천을 열지 않는다.
- 사람 이름이나 장소 이름만으로 경조사를 추론하지 않는다.
- 사용자의 역할을 임의로 명명하지 않고 일정에 필요한 준비 행동으로만 표현한다.
- 선물 품목과 금액은 추천하지 않는다.
- 축하금·조의금은 준비 여부만 확인한다.
- 공용 장소·이동 추천은 기존 `check_location`, `check_travel_time`, `check_transport`를 재사용한다.

## 최소 회귀 입력

| 입력 | 기대 분류 | 최소 기대 후보 | 금지 |
|---|---|---|---|
| `민영이` | 모두 null | 0개 | 생일·선물 추천 |
| `경조사` | social_occasion만 허용 | 0개 | 구체 준비 추론 |
| `민영이 생일` | social_occasion + birthday | 축하 메시지, 선물 조건부 | 구체 선물 품목·관계 추론 |
| `엄마 생신 저녁` | social_occasion + birthday | 메시지, 선물·식사 예약 조건부 | 일반 Hangout 우선 분류 |
| `내 생일` | birthday 제외 권장 | 0개 | 타인을 위한 선물·메시지 |
| `친구 결혼식` | social_occasion + wedding | 안내, 장소, 축하금 조건부 | 여행·Hangout 추천 |
| `호텔 결혼식` | social_occasion + wedding | 안내, 장소, 이동시간 | 숙소 예약·체크인 추천 |
| `내 결혼식 준비` | wedding 제외 | 0개 | 축하금·봉투 추천 |
| `조카 돌잔치` | social_occasion + first_birthday | 안내, 장소, 선물 조건부 | 생일 케이크 추천 |
| `우리 아이 돌잔치 준비` | first_birthday 제외 | 0개 | 일반 선물·축하금 추천 |
| `회사 선배 조문` | social_occasion + funeral | 부고, 빈소, 조문 시간 | 업무 미팅 추천 |
| `장례식장 방문` | social_occasion + funeral | 빈소, 조문 시간, 복장 | 금액·조문 문구 생성 |
| `서울대병원` | PlaceType 또는 null | 0개 | 장례식 추론 |
| `친구랑 저녁` | hangout + dining_meetup | 기존 약속 추천 | 생일·경조사 추천 |

각 입력에서 Context·EventType·PlaceType 후보, 임계값 통과 여부, 관계 후보, 추천 벡터 후보와 LLM 최종 0~3개를 분리해서 기록한다.

## Embedding 반영

기존 노드의 embedding이 최신이었다면 신규 경조사 노드 17개가 기본 적재 대상이다. migration으로 `exclusionExamples`만 바뀐 기존 노드는 현재 `embeddingText`가 바뀌지 않으므로 재임베딩 대상이 아니다.

기존 vector index는 라벨 전체를 대상으로 하므로 새 인덱스를 만들 필요가 없다.

## Bloom에서 확인

```cypher
MATCH (n {seedSource: 'social_occasion_v0.1'})
OPTIONAL MATCH (n)-[r]-()
WHERE r.seedSource = 'social_occasion_v0.1'
RETURN n, r
LIMIT 250;
```

Bloom scene의 숫자는 database 전체 count가 아니라 현재 불러온 결과 수다. 전체 수는 별도의 count 쿼리로 확인한다.
