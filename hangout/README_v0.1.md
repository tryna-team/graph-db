# Tryna Hangout KB v0.1

친구, 가족, 연인 또는 지인과의 사적인 약속을 위한 추가 지식베이스다. 사람·장소 이름만 적힌 입력에서는 추천하지 않고, `만나기`, `약속`, `식사`, `영화` 같은 활동 단서가 있을 때 후보를 연다.

## 구성

- `tryna_hangout_knowledge_base_v0.1.cypher`: Hangout 노드, 교차 카테고리 migration, 추천 관계
- 공통 런타임 조회: `../travel/tryna_travel_queries_v0.1.cypher`

이번 버전의 신규 데이터:

- `Context`: 1
- `EventType`: 3
- `PlaceType`: 3
- `RecommendationTemplate`: 11
- `RECOMMENDS`: 38
- 신규 노드 합계: 18

기존 `cafe` PlaceType과 공용 추천 6개는 새로 만들거나 수정하지 않고 재사용한다.

```text
check_location
check_travel_time
check_transport
charge_phone
pack_power_bank
pack_water
```

팀프로젝트 v0.5와 여행 v0.1이 적용된 DB에 추가하면 전체는 노드 74개, `RECOMMENDS` 119개가 된다.

## 실행 순서

1. `tryna_hangout_knowledge_base_v0.1.cypher`를 위에서부터 statement 단위로 실행한다.
2. 공용 노드 확인 결과가 `missingSharedCodes = []`인지 확인한다.
3. 여행 Place gate migration 결과는 처음 실행하면 일반적으로 `18`, 수정된 여행 seed를 다시 실행했다면 `0`이어도 정상이다.
4. 마지막 smoke check에서 `1 / 3 / 3 / 11`, `RECOMMENDS 38`, invalid 값 `0`을 확인한다.
5. 기존 embedding 적재 쿼리 A·B를 다시 실행한다. 기존 노드가 최신이면 Hangout 신규 18개만 embedding 대상이다.
6. 기존 vector index는 라벨 전체를 대상으로 하므로 새로 만들 필요가 없다.
7. 앱 조회에는 수정된 공통 쿼리 C·D를 사용한다. D는 현재 graph source와 연결된 추천 안에서만 벡터 순위를 계산하므로 다른 카테고리 후보가 섞이는 것을 줄인다.

Seed를 재실행해도 같은 code와 관계가 중복 생성되지 않는다.

## 분류 원칙

`민수`, `성수` 같은 고유명 자체에는 Hangout 의미가 없다.

```text
민수              → 분류 근거 없음
민수랑 약속        → hangout + social_meetup
민수 영화          → ticketed_outing, hangout은 선택적
성수               → 분류 근거 없음
성수 저녁 약속     → hangout + dining_meetup
카페               → PlaceType cafe만 가능
친구랑 카페        → hangout + social_meetup/dining_meetup + cafe
```

사람·장소 단독 입력에서 Context와 EventType이 모두 비어 있다면 PlaceType이 잡혀도 후보를 반환하지 않는다. 이후 개인화 데이터가 쌓이면 특정 이름과 `hangout`의 사용자 전용 관계를 추가할 수 있다.

## 교차 카테고리 안전장치

카테고리가 늘어나면 PlaceType 하나가 엉뚱한 추천을 여는 문제가 생긴다.

- `호텔 결혼식`: accommodation이 잡혀도 `travel` Context가 없으면 숙소 예약·체크인 추천 금지
- `인천공항 친구 마중`: airport가 잡혀도 `travel` Context가 없으면 항공권·수하물 추천 금지
- `카페 공부`: cafe가 잡혀도 `hangout` Context/EventType이 없으면 Hangout 추천 금지

Hangout Place 관계에는 `requiredContexts: ['hangout']`을 넣었고, 이 seed 안의 migration이 기존 여행 Place 관계에도 `travel` gate를 추가한다.

## 최소 회귀 입력

| 입력 | 기대 분류 | 최소 기대 후보 | 금지 |
|---|---|---|---|
| `민수` | 모두 null | 0개 | 모든 Hangout 추천 |
| `성수` | PlaceType 또는 null만 허용 | 0개 | 모든 Hangout 추천 |
| `카페` | cafe만 허용 | 0개 | 약속 시간·예약 추론 |
| `민수랑 약속` | hangout / social_meetup | 시간, 장소, 최근 대화 확인 | 여행·티켓 추천 |
| `성수 저녁 약속` | hangout / dining_meetup | 시간, 장소, 예약 조건부 | 영화·여행 추천 |
| `민수랑 카페` | hangout / social_meetup 또는 dining_meetup / cafe | 시간, 장소, 이동시간 | 숙소·항공 추천 |
| `민수 영화` | ticketed_outing | 시작 시각, 입장권, 입장 위치 | 식당·숙소 추천 |
| `밤 11시 공연` | ticketed_outing | 시작 시각, 티켓, 귀가 교통편 | 여행 준비 |
| `한강 피크닉` | hangout / park_outdoor | 장소, 날씨, 이동시간 | 영화·숙소 추천 |
| `인천공항 친구 마중` | hangout 가능 / airport | 장소·이동시간만 조건부 | 항공권, 수하물, 여권 |
| `호텔 결혼식` | Hangout은 보수적으로 null | 0개 또는 일반 시간·장소만 | 숙소 예약, 체크인, 세면도구 |
| `카페 공부` | cafe만 허용 | 0개 | Hangout 추천 |
| `넷플릭스 영화 보기` | ticketed_outing 금지 | 0개 | 영화관 티켓·입장 추천 |
| `회사 회의` | 기존 meeting만 허용 | 팀플 후보만 | Hangout 추천 |

`엄마 생일 저녁`은 이번 버전에서 일반 식사 약속까지만 처리한다. 선물·축하 메시지·결혼식 준비는 추후 별도의 기념일 카테고리로 분리한다.

각 입력마다 Context·EventType·PlaceType top-1/top-2 점수, 임계값 통과 여부, 관계 후보, 벡터 후보, LLM 최종 0~3개를 따로 기록한다.

## Bloom에서 새 데이터 보기

```cypher
MATCH (n {seedSource: 'hangout_v0.1'})
OPTIONAL MATCH (n)-[r]-()
WHERE r.seedSource = 'hangout_v0.1'
RETURN n, r
LIMIT 200;
```
