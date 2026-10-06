# Tryna 팀프로젝트 KB v0.5 MVP

이 버전은 맥락 질문, 개인 패턴, 복잡한 Condition/Rule 노드를 도입하지 않고 현재 파이프라인에 바로 연결하기 위한 최소 지식베이스다.

## 파일

- `tryna_team_project_knowledge_base_v0.5.cypher`: 제약조건, 지식 노드, 기본 추천 관계
- `tryna_team_project_vector_indexes_v0.5.cypher`: 벡터 인덱스 생성
- `tryna_team_project_queries_v0.5.cypher`: 임베딩 적재 및 런타임 조회 레퍼런스
- `tryna_team_project_knowledge_base_v0.4.cypher`: 수정하지 않은 기존 버전

## 실행 순서

1. `tryna_team_project_knowledge_base_v0.5.cypher`를 statement 단위로 실행한다.
2. 런타임 쿼리 A로 embedding이 필요한 노드를 가져온다.
3. 모든 `embeddingText`를 사용자 입력과 호환되는 Upstage embedding 공간으로 변환한다. API가 query/passage 역할을 구분하면 KB에는 passage 역할을, 사용자 입력에는 호환되는 query 역할을 사용한다.
4. 런타임 쿼리 B로 embedding과 모델 정보를 저장한다.
5. 실제 출력 차원을 `$embeddingDimension`으로 전달해 vector index 파일을 실행한다.
6. `SHOW VECTOR INDEXES`에서 모든 인덱스가 `ONLINE`인지 확인한다.
7. 실제 입력 데이터로 각 인덱스의 최소 유사도 임계값을 보정한다.

Seed smoke check의 기대값은 다음과 같다.

- `Context`: 1
- `EventType`: 2
- `PlaceType`: 4
- `RecommendationTemplate`: 18
- `RECOMMENDS`: 21
- 잘못된 추천/관계 속성 개수: 0

## 온라인 조회

```text
사용자 원문 + 명확한 파싱 정보
→ 동일한 Upstage 모델로 query embedding 1개 생성
→ EventType / Context / PlaceType 벡터 분류
→ 관계 기반 기본 추천 후보 조회
→ RecommendationTemplate 벡터 후보 조회
→ code 기준 결합·중복 제거
→ LLM이 후보 중 0~3개 선택하고 문구 정제
```

PlaceType은 필수가 아니다. 임계값을 넘지 못하면 `null`로 넘긴다. `민수`처럼 의미 맥락이 없는 입력에서 모든 분류와 추천이 비어도 정상이다.

장소명 단독 입력도 같은 원칙을 적용한다. `성수`, `가천대`처럼 PlaceType만 잡히고 EventType과 Context가 모두 비어 있으면 관계 추천과 RecommendationTemplate 벡터 추천을 실행하지 않는다.

Seed는 `MERGE` 기반이므로 재실행해도 같은 code와 관계가 중복 생성되지 않는다. 다만 이후 seed 파일에서 삭제한 노드나 관계를 자동으로 비활성화하지는 않으므로, 삭제·폐기 작업은 별도 migration으로 관리한다.

## 임계값 보정용 최소 입력 세트

- `팀플`
- `온라인 팀플`
- `가천대 팀플`
- `카페에서 프로젝트 회의`
- `오래 팀플`
- `5시간 팀플`
- `팀플 제출`
- `최종 보고서 제출`
- `민수`
- `성수`
- `저녁 먹기`
- 완전히 관련 없는 임의 문자열

각 입력에 대해 다음을 기록한다.

- 각 인덱스의 top-1/top-2 score
- 기대 EventType, Context, PlaceType
- 기대 추천과 추천하면 안 되는 항목
- LLM 최종 선택 결과

고정 임계값은 이 결과를 확인한 뒤 모델별로 결정한다.

## MVP에서 의도적으로 제외한 항목

- 맥락 확인 질문 UI
- 사용자별 PersonalPattern
- Situation/SituationExample 계층
- 지도 기반 이동시간 계산
- 상세 조건 규칙 엔진
- 사용자 피드백의 전역 지식 자동 승격

## LLM 출력 원칙

- 입력으로 전달받은 candidate code만 반환한다.
- 근거가 부족하면 빈 배열을 반환할 수 있다.
- `conditional` 후보는 단정하지 않고 `~할 예정이라면` 형식으로 표현한다.
- 사람 이름이나 장소 이름만 보고 일정 목적이나 준비물을 만들어내지 않는다.
