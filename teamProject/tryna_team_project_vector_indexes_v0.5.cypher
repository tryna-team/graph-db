// Tryna 팀프로젝트 지식베이스 v0.5 - Vector Index
//
// 실행 전 $embeddingDimension을 실제 Upstage embedding 모델의 출력 차원으로 설정한다.
// 모든 지식 노드와 사용자 입력은 반드시 같은 embedding 모델/버전을 사용해야 한다.

CREATE VECTOR INDEX event_type_embedding_idx IF NOT EXISTS
FOR (n:EventType)
ON n.embedding
OPTIONS {indexConfig: {
  `vector.dimensions`: $embeddingDimension,
  `vector.similarity_function`: 'cosine'
}};

CREATE VECTOR INDEX context_embedding_idx IF NOT EXISTS
FOR (n:Context)
ON n.embedding
OPTIONS {indexConfig: {
  `vector.dimensions`: $embeddingDimension,
  `vector.similarity_function`: 'cosine'
}};

CREATE VECTOR INDEX place_type_embedding_idx IF NOT EXISTS
FOR (n:PlaceType)
ON n.embedding
OPTIONS {indexConfig: {
  `vector.dimensions`: $embeddingDimension,
  `vector.similarity_function`: 'cosine'
}};

CREATE VECTOR INDEX recommendation_embedding_idx IF NOT EXISTS
FOR (n:RecommendationTemplate)
ON n.embedding
OPTIONS {indexConfig: {
  `vector.dimensions`: $embeddingDimension,
  `vector.similarity_function`: 'cosine'
}};

// 생성 직후에는 POPULATING 상태일 수 있다.
SHOW VECTOR INDEXES
YIELD name, state, populationPercent, labelsOrTypes, properties
RETURN name, state, populationPercent, labelsOrTypes, properties
ORDER BY name;
