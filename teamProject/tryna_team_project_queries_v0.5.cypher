// Tryna 팀프로젝트 지식베이스 v0.5 - 런타임/운영 쿼리 모음
//
// 주의: 이 파일은 여러 독립 쿼리의 레퍼런스다.
// 파일 전체를 한 번에 실행하지 말고 필요한 쿼리를 애플리케이션에서 개별 실행한다.


// ============================================================
// A. embedding 생성이 필요한 노드 조회
// params: $embeddingModel, $embeddingProfile
// embeddingProfile 예: passage, default
// ============================================================

MATCH (n)
WHERE (n:EventType OR n:Context OR n:PlaceType OR n:RecommendationTemplate)
  AND n.isActive = true
  AND n.embeddingText IS NOT NULL
  AND (
    n.embedding IS NULL
    OR n.embeddingSourceText IS NULL
    OR n.embeddingSourceText <> n.embeddingText
    OR n.embeddingModel IS NULL
    OR n.embeddingModel <> $embeddingModel
    OR n.embeddingProfile IS NULL
    OR n.embeddingProfile <> $embeddingProfile
  )
RETURN
  labels(n)[0] AS label,
  n.code AS code,
  n.embeddingText AS embeddingText
ORDER BY label, code;


// ============================================================
// B. Upstage에서 생성한 embedding 저장
// params: $label, $code, $embeddingText, $embedding,
//         $embeddingModel, $embeddingProfile, $embeddingDimension
// 조회 이후 embeddingText가 바뀌었거나 차원이 다르면 아무 행도 갱신하지 않는다.
// ============================================================

MATCH (n {code: $code})
WHERE $label IN labels(n)
  AND n.embeddingText = $embeddingText
  AND size($embedding) = $embeddingDimension
SET n.embedding = $embedding,
    n.embeddingModel = $embeddingModel,
    n.embeddingProfile = $embeddingProfile,
    n.embeddingSourceText = $embeddingText,
    n.embeddingUpdatedAt = datetime()
RETURN labels(n)[0] AS label, n.code AS code, size(n.embedding) AS dimensions;


// ============================================================
// C. EventType 벡터 분류
// params: $embedding, $minEventTypeScore
// 임계값을 넘지 않으면 eventType은 null로 처리한다.
// ============================================================

CALL db.index.vector.queryNodes(
  'event_type_embedding_idx',
  5,
  $embedding
)
YIELD node, score
WHERE node.isActive = true
  AND score >= $minEventTypeScore
RETURN
  node.code AS code,
  node.name AS name,
  node.exclusionExamples AS exclusionExamples,
  score
ORDER BY score DESC
LIMIT 2;


// ============================================================
// D. Context 벡터 분류
// params: $embedding, $minContextScore
// 임계값을 넘지 않으면 contexts는 빈 배열로 처리한다.
// ============================================================

CALL db.index.vector.queryNodes(
  'context_embedding_idx',
  5,
  $embedding
)
YIELD node, score
WHERE node.isActive = true
  AND score >= $minContextScore
RETURN
  node.code AS code,
  node.name AS name,
  node.exclusionExamples AS exclusionExamples,
  score
ORDER BY score DESC
LIMIT 2;


// ============================================================
// E. PlaceType 벡터 분류
// params: $embedding, $minPlaceTypeScore
// 장소 분류는 선택 사항이다. 확신도가 낮으면 placeType은 null로 처리한다.
// ============================================================

CALL db.index.vector.queryNodes(
  'place_type_embedding_idx',
  10,
  $embedding
)
YIELD node, score
WHERE node.isActive = true
  AND score >= $minPlaceTypeScore
RETURN
  node.code AS code,
  node.name AS name,
  node.attendanceMode AS attendanceMode,
  node.exclusionExamples AS exclusionExamples,
  score
ORDER BY score DESC
LIMIT 2;


// ============================================================
// F. 관계 기반 기본 추천 후보
// params: $eventType, $contexts, $placeType
// 동일 추천이 여러 소스에서 발견돼도 code 기준 한 행으로 집계한다.
// ============================================================

MATCH (source)-[rel:RECOMMENDS]->(r:RecommendationTemplate)
WHERE source.isActive = true
  AND r.isActive = true
  AND coalesce(rel.isActive, true) = true
  AND (
    (source:EventType
      AND $eventType IS NOT NULL
      AND source.code = $eventType)
    OR
    (source:Context
      AND $eventType IS NULL
      AND source.code IN coalesce($contexts, []))
    OR
    (source:PlaceType
      AND $placeType IS NOT NULL
      AND source.code = $placeType
      AND (
        $eventType IS NOT NULL
        OR size(coalesce($contexts, [])) > 0
      ))
  )
  AND (
    size(coalesce(rel.requiredContexts, [])) = 0
    OR all(
      requiredContext IN rel.requiredContexts
      WHERE requiredContext IN coalesce($contexts, [])
    )
  )
  AND (
    $placeType IS NULL
    OR NOT ($placeType IN coalesce(r.excludedPlaceTypes, []))
  )
WITH
  r,
  min(coalesce(rel.defaultRank, 999)) AS defaultRank,
  collect(DISTINCT {
    sourceLabels: labels(source),
    sourceCode: source.code,
    suggestionMode: coalesce(rel.suggestionMode, r.suggestionLevel),
    reason: rel.reason
  }) AS matchedBy
RETURN
  r.code AS code,
  r.name AS name,
  r.conditionalText AS conditionalText,
  r.description AS description,
  r.actionType AS actionType,
  r.targetType AS targetType,
  r.suggestionLevel AS suggestionLevel,
  r.defaultTiming AS defaultTiming,
  defaultRank,
  matchedBy
ORDER BY defaultRank, code
LIMIT 8;


// ============================================================
// G. RecommendationTemplate 벡터 후보
// params: $embedding, $minRecommendationScore, $eventType, $contexts, $placeType
// top-K를 무조건 사용하지 말고 반드시 모델별로 보정한 임계값을 적용한다.
// 인물명/장소명 단독 입력의 오추천을 막기 위해 EventType 또는 Context가 필요하다.
// ============================================================

CALL db.index.vector.queryNodes(
  'recommendation_embedding_idx',
  20,
  $embedding
)
YIELD node, score
WHERE node.isActive = true
  AND score >= $minRecommendationScore
  AND (
    $eventType IS NOT NULL
    OR size(coalesce($contexts, [])) > 0
  )
  AND (
    $placeType IS NULL
    OR NOT ($placeType IN coalesce(node.excludedPlaceTypes, []))
  )
RETURN
  node.code AS code,
  node.name AS name,
  node.conditionalText AS conditionalText,
  node.description AS description,
  node.actionType AS actionType,
  node.targetType AS targetType,
  node.suggestionLevel AS suggestionLevel,
  node.defaultTiming AS defaultTiming,
  score,
  [{
    sourceLabels: ['VectorSearch'],
    sourceCode: 'recommendation_embedding_idx',
    suggestionMode: node.suggestionLevel,
    reason: '입력 맥락과 추천 상황의 의미 유사도'
  }] AS matchedBy
ORDER BY score DESC
LIMIT 8;


// ============================================================
// H. 애플리케이션 결합 규칙
// Cypher가 아니라 서버 로직에서 수행한다.
// ============================================================
// 1) F와 G 결과를 recommendation code로 합친다.
// 2) 같은 code의 matchedBy는 모두 보존한다.
// 3) score가 없는 관계 후보와 vector score를 단순 수치 비교하지 않는다.
// 4) 최종 8개 이하만 LLM에 전달한다.
// 5) LLM은 후보 code만 선택하며 빈 suggestions 배열을 반환할 수 있다.


// ============================================================
// I. Seed smoke check (독립 실행)
// v0.5 기준 기대값: Context 1, EventType 2, PlaceType 4,
// RecommendationTemplate 18, RECOMMENDS 23
// ============================================================

MATCH (r:RecommendationTemplate)
RETURN
  count(r) AS recommendationCount,
  sum(CASE
    WHEN r.embeddingText IS NULL
      OR r.conditionalText IS NULL
      OR r.suggestionLevel IS NULL
    THEN 1 ELSE 0
  END) AS invalidRecommendationCount;

MATCH ()-[rel:RECOMMENDS]->(:RecommendationTemplate)
RETURN
  count(rel) AS recommendsCount,
  sum(CASE
    WHEN rel.defaultRank IS NULL
      OR rel.suggestionMode IS NULL
    THEN 1 ELSE 0
  END) AS invalidRelationshipCount;
