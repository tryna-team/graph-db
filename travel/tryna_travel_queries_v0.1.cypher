// Tryna 여행 KB v0.1 - 런타임 보완 쿼리
//
// 이 파일은 여러 독립 쿼리의 레퍼런스다.
// 여행 카테고리를 추가한 뒤 기존 teamProject v0.5 쿼리의
// Context 조회, F(관계 후보), G(추천 벡터 후보)를 아래 방식으로 보완한다.


// ============================================================
// A. Context 벡터 후보 조회
// params: $embedding, $minContextScore
// 앱은 exclusiveGroup이 같은 subtype을 동시에 확정하지 않는다.
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
  node.contextLevel AS contextLevel,
  node.parentCode AS parentCode,
  node.exclusiveGroup AS exclusiveGroup,
  node.exclusionExamples AS exclusionExamples,
  score
ORDER BY score DESC
LIMIT 5;


// ============================================================
// B. 확정된 Context의 상위 맥락 확장
// params: $detectedContexts
// 예:
// ['domestic_travel']      -> ['domestic_travel', 'travel']
// ['international_travel'] -> ['international_travel', 'travel']
// exclusiveGroup 승자 선택을 먼저 끝낸 뒤 호출한다.
// ============================================================

UNWIND coalesce($detectedContexts, []) AS detectedCode
MATCH (detected:Context {code: detectedCode})
MATCH (detected)-[:IS_A*0..2]->(expanded:Context)
RETURN collect(DISTINCT expanded.code) AS contexts;


// ============================================================
// C. 관계 기반 기본 추천 후보
// params: $eventType, $contexts, $placeType
//
// 기존 F와 다른 점:
// - EventType이 있어도 Context 추천을 함께 사용한다.
// - 관계와 추천 노드 양쪽의 required/excluded context를 검사한다.
// - LLM 전 후보가 굶지 않도록 관계 후보를 최대 12개 반환한다.
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
    size(coalesce(r.requiredContexts, [])) = 0
    OR all(
      requiredContext IN r.requiredContexts
      WHERE requiredContext IN coalesce($contexts, [])
    )
  )
  AND none(
    excludedContext IN coalesce(r.excludedContexts, [])
    WHERE excludedContext IN coalesce($contexts, [])
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
LIMIT 12;


// ============================================================
// D. RecommendationTemplate 벡터 후보
// params: $embedding, $minRecommendationScore, $eventType, $contexts, $placeType
//
// 해외 전용 추천이 국내여행에 섞이지 않도록 node context gate를 적용한다.
// EventType/Context가 모두 없으면 장소명·인명 단독 입력으로 보고 결과를 열지 않는다.
// 다른 카테고리 추천이 의미 유사도만으로 섞이지 않도록 현재 graph source와
// 실제 RECOMMENDS 관계가 있는 노드만 vector 후보로 허용한다.
// ============================================================

CALL db.index.vector.queryNodes(
  'recommendation_embedding_idx',
  30,
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
    size(coalesce(node.requiredContexts, [])) = 0
    OR all(
      requiredContext IN node.requiredContexts
      WHERE requiredContext IN coalesce($contexts, [])
    )
  )
  AND none(
    excludedContext IN coalesce(node.excludedContexts, [])
    WHERE excludedContext IN coalesce($contexts, [])
  )
  AND (
    $placeType IS NULL
    OR NOT ($placeType IN coalesce(node.excludedPlaceTypes, []))
  )
  AND EXISTS {
    MATCH (source)-[rel:RECOMMENDS]->(node)
    WHERE source.isActive = true
      AND coalesce(rel.isActive, true) = true
      AND (
        (source:EventType
          AND $eventType IS NOT NULL
          AND source.code = $eventType)
        OR
        (source:Context
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
  }
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
// E. 해외 추천 gate 점검
// 기대:
// - internationalOnlyCount = 6
// - invalidRequiredContextCount = 0
// - invalidExcludedContextCount = 0
// ============================================================

MATCH (r:RecommendationTemplate)
WHERE r.code IN [
  'check_passport_validity',
  'pack_passport',
  'prepare_roaming',
  'check_power_adapter',
  'prepare_overseas_payment',
  'check_entry_documents'
]
RETURN
  count(r) AS internationalOnlyCount,
  sum(CASE
    WHEN NOT ('international_travel' IN coalesce(r.requiredContexts, []))
    THEN 1 ELSE 0
  END) AS invalidRequiredContextCount,
  sum(CASE
    WHEN NOT ('domestic_travel' IN coalesce(r.excludedContexts, []))
    THEN 1 ELSE 0
  END) AS invalidExcludedContextCount;
