# Tryna 여행 KB v0.1

팀프로젝트 v0.5와 같은 Neo4j 데이터베이스에 추가하는 여행 카테고리 MVP다. 짧은 입력을 지원하되, 국내여행에 여권을 추천하거나 장소명만으로 탑승 목적을 지어내는 오추천을 우선 막는 구조다.

## 구성

- `tryna_travel_knowledge_base_v0.1.cypher`: 여행 노드와 추천 관계 seed
- `tryna_travel_queries_v0.1.cypher`: Context 확장 및 관계·벡터 후보 조회 보완

신규 데이터는 다음과 같다.

- `Context`: 3
- `EventType`: 3
- `PlaceType`: 4
- `RecommendationTemplate`: 21
- `RECOMMENDS`: 58
- `IS_A`: 2

기존 팀프로젝트 v0.5의 공용 추천 4개(`check_travel_time`, `check_transport`, `pack_power_bank`, `pack_water`)는 새로 만들거나 수정하지 않고 관계에서만 재사용한다.

팀프로젝트 v0.5만 있던 DB에 정상 추가하면 전체는 노드 56개, `RECOMMENDS` 81개가 된다.

## 실행 순서

1. `teamProject/tryna_team_project_knowledge_base_v0.5.cypher`가 적용된 DB인지 확인한다.
2. `tryna_travel_knowledge_base_v0.1.cypher`를 위에서부터 statement 단위로 실행한다.
3. 파일의 공용 추천 확인 결과가 `missingSharedCodes = []`인지 확인한다.
4. 마지막 smoke check에서 `3 / 3 / 4 / 21`, `RECOMMENDS 58`, `IS_A 2`가 나오는지 확인한다.
5. 기존 팀프로젝트 런타임 쿼리 A·B를 다시 사용해 신규 노드의 embedding을 생성하고 저장한다. 기존 노드의 embedding이 최신이면 신규 31개만 대상이 된다.
6. 기존 vector index는 라벨 전체를 대상으로 하므로 새로 만들 필요가 없다. embedding 저장 후 기존 인덱스에 자동 반영된다.
7. 런타임에서는 이 폴더의 보완 쿼리 C·D를 기존 F·G 대신 사용한다.

Seed는 `MERGE` 기반이라 같은 파일을 두 번 실행해도 노드와 관계가 늘어나지 않는다. 삭제된 seed 항목을 자동 제거하지는 않으므로 이후 삭제는 별도 migration으로 관리한다.

## Context 정규화

`domestic_travel`과 `international_travel`은 동시에 확정하면 안 된다.

```text
travel
├─ domestic_travel
└─ international_travel
```

분류 결과는 다음처럼 서버에서 정규화한다.

- 일반 여행 → `['travel']`
- 국내여행 → `['travel', 'domestic_travel']`
- 해외여행 → `['travel', 'international_travel']`
- 두 subtype이 모두 임계값을 넘으면 점수가 높은 하나만 선택
- 점수 차가 작거나 임계값이 불확실하면 subtype을 버리고 `travel`만 쓰거나 전체를 비운다

국가·도시 한 단어는 실제 Upstage embedding 결과를 보고 top-1 점수와 top-1/top-2 차이를 함께 보정해야 한다. top-K라는 이유만으로 Context를 확정하면 안 된다.

## 핵심 안전장치

- 해외 전용 6종은 `international_travel`이 있어야만 관계 후보와 벡터 후보에 들어간다.
- `airport`에서 여권으로 직접 가는 관계는 없다. 공항은 국내선이거나 마중 일정일 수 있다.
- PlaceType만 잡히고 EventType과 Context가 모두 없으면 추천 결과는 0개다.
- `check_baggage_rules`는 공항·항공 맥락에서만 쓴다.
- `pack_toiletries`는 숙소·체크인·숙박 단서가 있을 때만 쓴다.
- `pack_regular_medicine`은 질환을 추론하지 않고 항상 조건형으로 표현한다.
- `check_entry_documents`는 공식 안내를 확인하자는 과업일 뿐, 비자나 입국 요건을 KB나 LLM이 단정하지 않는다.
- 최종 LLM은 후보 밖의 항목을 만들지 않고 0~3개만 선택한다.

해외 전용 6종:

```text
check_passport_validity
pack_passport
prepare_roaming
check_power_adapter
prepare_overseas_payment
check_entry_documents
```

## 최소 회귀 입력

| 입력 | 기대 맥락/이벤트 | 최소 기대 후보 | 금지 |
|---|---|---|---|
| `여행` | travel / travel_departure 가능 | check_travel_dates, check_weather | 해외 전용 6종 |
| `제주도` | travel + domestic_travel | check_weather, check_travel_time 가능 | 해외 전용 6종 |
| `부산 KTX` | domestic_travel / transport_departure | check_transport_ticket, check_departure_time | 해외 전용 6종, check_baggage_rules |
| `일본 여행` | travel + international_travel | pack_passport, check_passport_validity | 없음 |
| `인천공항 출국` | international_travel / transport_departure / airport | pack_passport, check_transport_ticket, check_departure_point | 없음 |
| `인천공항 친구 마중` | airport만 허용 | 최종 0개 | 여권, 항공권, 수하물 준비 |
| `호텔 체크인` | accommodation_checkin / accommodation | check_accommodation_booking, check_checkin_time | 항공편 전용 추천 |
| `호텔 결혼식` | 여행 EventType/Context 없음 | 최종 0개 | 숙소 예약·체크인 추천 |
| `일본어 공부` | 여행 EventType/Context 없음 | 최종 0개 | 해외 전용 6종 |
| `민수` | 모두 없음 | 최종 0개 | 모든 여행 추천 |

후보 포함 여부와 LLM 최종 선택은 분리해서 기록한다. 각 입력마다 EventType·Context·PlaceType의 top-1/top-2 점수, 임계값 통과 여부, 관계 후보, 벡터 후보, 최종 0~3개를 남기면 된다.
