// ============================================================================
// Tryna M1 온톨로지(스키마) 및 기초 지식(Rule) 초기화 쿼리 (통합본)
// 기존 v0.1~v0.5 레거시 데이터를 모두 삭제하고 새로운 6대 바구니 구조로 재편합니다.
// ============================================================================

// ----------------------------------------------------------------------------
// 1. 기존 레거시 데이터 전체 삭제 (DANGER: DB 완전 초기화)
// ----------------------------------------------------------------------------
MATCH (n) DETACH DELETE n;

// 기존 레거시 제약조건 삭제 (필요시 수동으로 남은 제약조건 확인 후 삭제)
// CALL apoc.schema.assert({}, {}, true);


// ----------------------------------------------------------------------------
// 2. 6대 핵심 노드 고유 제약조건 (Schema) 생성
// ----------------------------------------------------------------------------
CREATE CONSTRAINT event_code IF NOT EXISTS FOR (n:Event) REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT person_code IF NOT EXISTS FOR (n:Person) REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT place_code IF NOT EXISTS FOR (n:Place) REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT activity_code IF NOT EXISTS FOR (n:Activity) REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT item_code IF NOT EXISTS FOR (n:Item) REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT rule_code IF NOT EXISTS FOR (n:PreparationRule) REQUIRE n.code IS UNIQUE;


// ----------------------------------------------------------------------------
// 3. 기초 지식 (PreparationRule) 5종 세팅
// - 사람이 미리 넣어두는 "최소한의 상식" (빈 바구니에 넣는 기본 배합법)
// - 여기서 Activity, Action, Item 노드들이 MERGE로 생성됩니다.
// ----------------------------------------------------------------------------

// 3-1. 물건 전달 규칙
MERGE (act1:Activity {code: 'HANDOFF_ITEM', name: '물건 전달'})
MERGE (item1:Item {code: 'TARGET_ITEM', name: '전달 물품'})
MERGE (rule1:PreparationRule {
    code: 'RULE_HANDOFF_01',
    action: '챙기기',
    reminderPhase: 'BEFORE_DEPARTURE',
    importance: 'MEDIUM',
    status: 'APPROVED'
})
MERGE (rule1)-[:APPLIES_TO]->(act1)
MERGE (rule1)-[:TARGETS]->(item1);

// 3-2. 해외 이동 규칙
MERGE (act2:Activity {code: 'OVERSEAS_TRAVEL', name: '해외 이동'})
MERGE (item2:Item {code: 'PASSPORT', name: '여권'})
MERGE (rule2:PreparationRule {
    code: 'RULE_TRAVEL_01',
    action: '확인하기',
    reminderPhase: 'DAY_BEFORE_OR_DEPARTURE',
    importance: 'HIGH',
    status: 'APPROVED'
})
MERGE (rule2)-[:APPLIES_TO]->(act2)
MERGE (rule2)-[:TARGETS]->(item2);

// 3-3. OMR 시험 응시 규칙
MERGE (act3:Activity {code: 'TAKE_OMR_EXAM', name: 'OMR 시험 응시'})
MERGE (item3:Item {code: 'COMPUTER_PEN', name: '컴퓨터용 사인펜'})
MERGE (rule3:PreparationRule {
    code: 'RULE_EXAM_01',
    action: '챙기기',
    reminderPhase: 'BEFORE_DEPARTURE',
    importance: 'HIGH',
    status: 'APPROVED'
})
MERGE (rule3)-[:APPLIES_TO]->(act3)
MERGE (rule3)-[:TARGETS]->(item3);

// 3-4. 발표 규칙
MERGE (act4:Activity {code: 'PRESENTATION', name: '발표'})
MERGE (item4:Item {code: 'PRESENTATION_DOC', name: '발표 자료'})
MERGE (rule4:PreparationRule {
    code: 'RULE_PRESENTATION_01',
    action: '점검하기',
    reminderPhase: 'DAY_BEFORE',
    importance: 'MEDIUM',
    status: 'APPROVED'
})
MERGE (rule4)-[:APPLIES_TO]->(act4)
MERGE (rule4)-[:TARGETS]->(item4);

// 3-5. 기기 사용 (충전) 규칙
MERGE (act5:Activity {code: 'USE_DEVICE', name: '기기 사용'})
MERGE (item5:Item {code: 'TARGET_DEVICE', name: '해당 기기'})
MERGE (rule5:PreparationRule {
    code: 'RULE_DEVICE_01',
    action: '충전하기',
    reminderPhase: 'BEFORE_USE',
    importance: 'MEDIUM',
    status: 'APPROVED'
})
MERGE (rule5)-[:APPLIES_TO]->(act5)
MERGE (rule5)-[:TARGETS]->(item5);


// ----------------------------------------------------------------------------
// 4. 결과 요약 출력
// ----------------------------------------------------------------------------
MATCH (n)
RETURN labels(n)[0] AS Label, count(n) AS Count
ORDER BY Label;