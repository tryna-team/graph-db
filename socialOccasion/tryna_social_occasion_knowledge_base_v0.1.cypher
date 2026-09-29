// Tryna 경조사 지식베이스 v0.1
//
// 전제:
// - teamProject v0.5, travel v0.1, hangout v0.1, academic v0.1,
//   workCareer v0.1 뒤에 같은 database에서 추가 실행한다.
// - 기존 공용 RecommendationTemplate은 MATCH로만 재사용하며 속성을 덮어쓰지 않는다.
// - Neo4j Query에서 statement 단위로 위에서부터 실행한다.
//
// 범위:
// - 다른 사람의 생일·생신
// - 결혼식
// - 돌잔치
// - 조문·장례식장 방문
//
// 제외:
// - 사람 이름, 장소 이름 또는 "경조사"만으로 구체 일정 유형 추론
// - 내 결혼식 준비, 우리 아이 돌잔치 준비처럼 주최 범위가 큰 일정
// - 사용자의 관계, 선물 품목, 축의금·조의금 액수 추론
// - 조문 문구나 감정적 대응 자동 생성
// - 실시간 식장·장례식장 정보 자체 제공


// ============================================================
// 1. 기존 라벨의 고유 제약조건 재확인
// ============================================================

CREATE CONSTRAINT event_type_code IF NOT EXISTS
FOR (e:EventType)
REQUIRE e.code IS UNIQUE;

CREATE CONSTRAINT context_code IF NOT EXISTS
FOR (c:Context)
REQUIRE c.code IS UNIQUE;

CREATE CONSTRAINT place_type_code IF NOT EXISTS
FOR (p:PlaceType)
REQUIRE p.code IS UNIQUE;

CREATE CONSTRAINT recommendation_template_code IF NOT EXISTS
FOR (r:RecommendationTemplate)
REQUIRE r.code IS UNIQUE;


// ============================================================
// 2. 기존 분류 노드의 경조사 호환 migration
// 일반 약속·식사·업무 맥락이 경조사보다 먼저 확정되는 것을 줄인다.
// ============================================================

UNWIND [
  {
    code: 'hangout',
    additions: [
      '민영이 생일', '엄마 생신', '친구 생일 저녁',
      '친구 결혼식', '호텔 결혼식', '조카 돌잔치',
      '장례식장 방문', '회사 선배 조문'
    ]
  },
  {
    code: 'travel',
    additions: ['친구 결혼식', '호텔 결혼식', '지방 결혼식', '장례식장 방문']
  },
  {
    code: 'work_career',
    additions: ['직장 동료 결혼식', '회사 선배 조문', '거래처 장례식장 방문']
  }
] AS row
MATCH (c:Context {code: row.code})
SET c.exclusionExamples = coalesce(c.exclusionExamples, []) + [
      value IN row.additions
      WHERE NOT (value IN coalesce(c.exclusionExamples, []))
    ],
    c.socialOccasionCompatibilityVersion = '0.1',
    c.updatedAt = datetime()
RETURN count(c) AS updatedContextExclusionCount;

UNWIND [
  {
    code: 'social_meetup',
    additions: [
      '민영이 생일', '엄마 생신', '친구 결혼식',
      '조카 돌잔치', '장례식장 방문', '조문'
    ]
  },
  {
    code: 'dining_meetup',
    additions: ['생일 저녁', '생신 식사', '돌잔치 식사', '결혼식 피로연']
  },
  {
    code: 'external_work_meeting',
    additions: ['직장 동료 결혼식', '회사 선배 조문', '거래처 장례식장 방문']
  }
] AS row
MATCH (e:EventType {code: row.code})
SET e.exclusionExamples = coalesce(e.exclusionExamples, []) + [
      value IN row.additions
      WHERE NOT (value IN coalesce(e.exclusionExamples, []))
    ],
    e.socialOccasionCompatibilityVersion = '0.1',
    e.updatedAt = datetime()
RETURN count(e) AS updatedEventTypeExclusionCount;


// ============================================================
// 3. Context 1개
// Context 자체에는 추천 관계를 만들지 않는다.
// ============================================================

UNWIND [
  {
    code: 'social_occasion',
    name: '경조사',
    description: '생일, 생신, 결혼식, 돌잔치, 조문처럼 축하나 위로를 위해 일정과 준비를 확인하는 개인적 행사 맥락',
    examples: [
      '민영이 생일', '엄마 생신', '친구 결혼식', '사촌 결혼식',
      '조카 돌잔치', '첫돌 행사', '회사 선배 조문', '장례식장 방문'
    ],
    exclusionExamples: [
      '민영이', '엄마', '친구 만나기', '가족 모임', '저녁 약속',
      '내 생일', '내 결혼식 준비', '웨딩 촬영', '상견례', '청첩장 제작',
      '우리 아이 돌잔치 준비', '돌 사진 촬영', '장례 준비', '장례 보험',
      '호텔 숙박', '출장', '회사 회의', '경조사비 정산'
    ],
    embeddingText: '친구 생일, 부모님 생신, 지인 결혼식, 사촌 결혼식, 조카 돌잔치, 첫돌 행사, 조문, 장례식장 방문. 다른 사람의 생일을 챙기거나 결혼식과 돌잔치에 가고 장례식장을 방문하는 경조사 일정.',
    contextLevel: 'category',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  }
] AS row
MERGE (c:Context {code: row.code})
ON CREATE SET c.createdAt = datetime()
SET c += row,
    c.updatedAt = datetime();


// ============================================================
// 4. EventType 4개
// ============================================================

UNWIND [
  {
    code: 'birthday',
    name: '생일·생신',
    description: '가족, 친구 또는 지인의 생일이나 생신을 챙기는 일정',
    examples: ['민영이 생일', '엄마 생신', '아빠 생일', '친구 생일 저녁', '할머니 생신'],
    exclusionExamples: [
      '민영이', '엄마', '내 생일', '내 생일 파티 준비',
      '생일 선물 아이디어', '생일 케이크 레시피', '생년월일 입력'
    ],
    embeddingText: '민영이 생일, 엄마 생신, 아빠 생일, 친구 생일 저녁, 할머니 생신처럼 가족이나 지인의 생일을 기억하고 축하를 준비하는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'wedding',
    name: '결혼식',
    description: '가족, 친구, 지인 또는 동료의 결혼식 일정을 확인하는 행사',
    examples: ['친구 결혼식', '민수 결혼식', '사촌 결혼식', '직장 동료 결혼식', '호텔 결혼식'],
    exclusionExamples: [
      '내 결혼식', '결혼 준비', '웨딩 촬영', '상견례',
      '청첩장 제작', '예식장 계약', '신혼여행', '웨딩 플래너 상담'
    ],
    embeddingText: '친구 결혼식, 민수 결혼식, 사촌 결혼식, 직장 동료 결혼식, 호텔 결혼식처럼 다른 사람의 결혼식 날짜와 장소를 확인하고 필요한 준비를 챙기는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'first_birthday',
    name: '돌잔치',
    description: '친척, 친구 또는 지인의 아이 첫돌을 축하하는 돌잔치 일정',
    examples: ['조카 돌잔치', '친구 아기 돌잔치', '첫돌 행사', '돌잔치 가기'],
    exclusionExamples: [
      '우리 아이 돌잔치 준비', '돌상 준비', '돌 사진 촬영',
      '돌잔치 장소 계약', '아기 생일 파티 준비'
    ],
    embeddingText: '조카 돌잔치, 친구 아기 돌잔치, 첫돌 행사, 돌잔치 가기처럼 다른 가족의 아이 첫돌을 축하하기 위해 날짜와 장소를 확인하는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'funeral',
    name: '조문·장례식장 방문',
    description: '부고를 확인하고 장례식장이나 빈소를 방문하는 일정',
    examples: ['회사 선배 조문', '장례식장 방문', '친구 아버님 빈소', '부고 조문', '발인 참석'],
    exclusionExamples: [
      '장례 준비', '장례식장 예약', '장례 보험', '장례지도사 상담',
      '조의금 액수 검색', '조문 문구 작성', '병원 방문'
    ],
    embeddingText: '회사 선배 조문, 장례식장 방문, 친구 아버님 빈소, 부고 조문, 발인 참석처럼 부고 내용을 확인하고 장례식장이나 빈소를 방문하는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  }
] AS row
MERGE (e:EventType {code: row.code})
ON CREATE SET e.createdAt = datetime()
SET e += row,
    e.updatedAt = datetime();


// ============================================================
// 5. 경조사 전용 RecommendationTemplate 12개
// offsetDays는 현재 온톨로지 필드가 아니므로 저장하지 않는다.
// D104의 승인된 서버 설정에서 sourceCode별 값을 별도로 관리한다.
// ============================================================

UNWIND [
  {
    code: 'review_occasion_notice', name: '초대·안내 내용 다시 확인하기',
    description: '초대장, 청첩장 또는 부고 안내에서 날짜, 시간과 장소를 다시 확인한다.',
    examples: ['청첩장 확인', '초대장 확인', '부고 확인', '행사 안내 확인'],
    triggerExamples: ['친구 결혼식', '조카 돌잔치', '회사 선배 조문', '장례식장 방문'],
    conditionalText: '받은 초대나 안내에서 날짜와 시간, 장소를 다시 확인할까요?',
    embeddingText: '친구 결혼식, 조카 돌잔치, 부고, 장례식장 방문처럼 초대장이나 안내 메시지가 있는 경조사 일정. 추천 행동: 받은 안내에서 날짜, 시간과 장소 다시 확인하기.',
    category: 'check', actionType: 'review', targetType: 'occasion_notice',
    suggestionLevel: 'safe', defaultTiming: '일정 등록 직후 또는 전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'prepare_celebration_gift', name: '축하 선물 준비 여부 확인하기',
    description: '생일이나 돌잔치에 선물을 준비할지 확인하고 필요한 경우 미리 준비한다.',
    examples: ['생일 선물', '생신 선물', '돌 선물', '선물 준비'],
    triggerExamples: ['친구 생일', '부모님 생신', '조카 돌잔치'],
    conditionalText: '선물을 준비할 예정이라면 미리 챙겨둘까요?',
    embeddingText: '친구 생일, 부모님 생신, 조카 돌잔치처럼 선물을 준비할 수 있는 축하 일정. 추천 행동: 선물 준비 여부를 확인하고 필요한 경우 미리 준비하기.',
    category: 'item', actionType: 'prepare', targetType: 'gift',
    suggestionLevel: 'contextual', defaultTiming: '며칠 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'check_gift_delivery', name: '선물 배송 예정일 확인하기',
    description: '온라인으로 주문한 선물이 일정 전에 도착하는지 배송 예정일을 확인한다.',
    examples: ['선물 배송', '택배 도착', '주문한 선물'],
    triggerExamples: ['생일 선물 주문', '생신 선물 배송', '돌 선물 택배'],
    conditionalText: '선물을 주문했다면 일정 전에 도착하는지 확인할까요?',
    embeddingText: '생일 선물 주문, 생신 선물 배송, 돌 선물 택배처럼 온라인으로 선물을 주문한 일정. 추천 행동: 선물이 일정 전에 도착하는지 배송 예정일 확인하기.',
    category: 'check', actionType: 'check', targetType: 'gift_delivery',
    suggestionLevel: 'conditional', defaultTiming: '며칠 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'check_birthday_cake', name: '케이크 준비 여부 확인하기',
    description: '생일에 케이크가 필요한지 확인하고 예약이나 수령 계획을 점검한다.',
    examples: ['생일 케이크', '케이크 예약', '케이크 픽업'],
    triggerExamples: ['생일 파티', '생신 식사', '케이크 준비'],
    conditionalText: '케이크를 준비할 예정이라면 예약이나 수령 일정을 확인할까요?',
    embeddingText: '생일 파티, 생신 식사, 케이크 준비처럼 케이크가 있을 수 있는 생일 일정. 추천 행동: 케이크 준비 여부와 예약 또는 수령 일정 확인하기.',
    category: 'check', actionType: 'check', targetType: 'cake',
    suggestionLevel: 'conditional', defaultTiming: '며칠 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'check_birthday_meal_reservation', name: '생일 식사 예약 여부 확인하기',
    description: '생일이나 생신 식사를 함께할 경우 식당 예약 여부와 시간을 확인한다.',
    examples: ['생일 식사', '생신 저녁', '가족 외식 예약'],
    triggerExamples: ['엄마 생신 저녁', '친구 생일 식사', '가족 생일 외식'],
    conditionalText: '함께 식사할 예정이라면 예약 여부와 시간을 확인할까요?',
    embeddingText: '엄마 생신 저녁, 친구 생일 식사, 가족 생일 외식처럼 여러 사람이 함께 식사하는 생일 일정. 추천 행동: 식당 예약 여부와 예약 시간 확인하기.',
    category: 'check', actionType: 'check', targetType: 'meal_reservation',
    suggestionLevel: 'conditional', defaultTiming: '며칠 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'prepare_birthday_greeting', name: '축하 메시지 준비하기',
    description: '생일이나 생신 당일 전할 짧은 축하 메시지나 연락을 준비한다.',
    examples: ['생일 축하 메시지', '생신 연락', '축하 전화'],
    triggerExamples: ['친구 생일', '부모님 생신', '멀리 있는 지인 생일'],
    conditionalText: '당일 전할 축하 메시지나 연락을 미리 챙겨둘까요?',
    embeddingText: '친구 생일, 부모님 생신, 멀리 있는 지인 생일처럼 당일 축하 연락을 할 수 있는 일정. 추천 행동: 짧은 축하 메시지나 연락 준비하기.',
    category: 'contact', actionType: 'prepare', targetType: 'birthday_greeting',
    suggestionLevel: 'safe', defaultTiming: '당일',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'prepare_congratulatory_money', name: '축하금과 봉투 준비 여부 확인하기',
    description: '결혼식이나 돌잔치에 축하금과 봉투를 준비할지 확인한다.',
    examples: ['축의금', '축하금', '봉투 준비'],
    triggerExamples: ['친구 결혼식', '직장 동료 결혼식', '조카 돌잔치'],
    conditionalText: '축하금을 준비할 예정이라면 봉투와 함께 미리 챙겨둘까요?',
    embeddingText: '친구 결혼식, 직장 동료 결혼식, 조카 돌잔치처럼 축하금을 준비할 수 있는 일정. 추천 행동: 축하금과 봉투 준비 여부 확인하기. 금액은 제안하지 않는다.',
    category: 'item', actionType: 'prepare', targetType: 'congratulatory_money',
    suggestionLevel: 'contextual', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'check_ceremony_attire', name: '행사 복장 안내 확인하기',
    description: '결혼식 등 행사에 별도로 안내된 복장이나 준비 사항이 있는지 확인한다.',
    examples: ['결혼식 복장', '드레스 코드', '행사 복장 안내'],
    triggerExamples: ['결혼식', '야외 결혼식', '복장 안내가 있는 행사'],
    conditionalText: '별도로 안내된 복장이나 준비 사항이 있는지 확인할까요?',
    embeddingText: '결혼식, 야외 결혼식, 드레스 코드가 있는 행사처럼 별도 복장 안내가 있을 수 있는 일정. 추천 행동: 공식 안내에 복장이나 준비 사항이 있는지 확인하기.',
    category: 'check', actionType: 'check', targetType: 'attire_guidance',
    suggestionLevel: 'conditional', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'check_funeral_room', name: '장례식장과 빈소 호실 확인하기',
    description: '부고 안내에서 장례식장 이름, 건물과 빈소 호실을 확인한다.',
    examples: ['빈소 호실', '장례식장 위치', '장례식장 건물'],
    triggerExamples: ['장례식장 방문', '회사 선배 조문', '친구 아버님 빈소'],
    conditionalText: '부고 안내에서 장례식장과 빈소 호실을 확인할까요?',
    embeddingText: '장례식장 방문, 회사 선배 조문, 친구 아버님 빈소처럼 장례식장 안의 정확한 빈소를 찾아야 하는 일정. 추천 행동: 장례식장 이름, 건물과 빈소 호실 확인하기.',
    category: 'check', actionType: 'check', targetType: 'funeral_room',
    suggestionLevel: 'safe', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'check_funeral_visiting_time', name: '조문 가능한 시간 확인하기',
    description: '부고 안내나 전달받은 내용에서 조문 가능한 시간과 발인 시각을 확인한다.',
    examples: ['조문 시간', '방문 시간', '발인 시간'],
    triggerExamples: ['장례식장 방문', '저녁 조문', '발인 전 방문'],
    conditionalText: '안내된 조문 가능 시간과 발인 시각을 확인할까요?',
    embeddingText: '장례식장 방문, 저녁 조문, 발인 전 방문처럼 방문 시각 확인이 필요한 일정. 추천 행동: 안내된 조문 가능 시간과 발인 시각 확인하기.',
    category: 'check', actionType: 'check', targetType: 'visiting_time',
    suggestionLevel: 'safe', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'prepare_condolence_money', name: '조의금과 봉투 준비 여부 확인하기',
    description: '조문 전에 조의금과 봉투를 준비할지 확인한다.',
    examples: ['조의금', '부의금', '봉투 준비'],
    triggerExamples: ['장례식장 방문', '회사 선배 조문', '부고 조문'],
    conditionalText: '조의금을 준비할 예정이라면 봉투와 함께 챙겨둘까요?',
    embeddingText: '장례식장 방문, 회사 선배 조문, 부고 조문처럼 조의금을 준비할 수 있는 일정. 추천 행동: 조의금과 봉투 준비 여부 확인하기. 금액은 제안하지 않는다.',
    category: 'item', actionType: 'prepare', targetType: 'condolence_money',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  },
  {
    code: 'check_funeral_attire', name: '조문 복장 준비하기',
    description: '장례식장 방문 전에 단정하고 차분한 복장을 준비한다.',
    examples: ['조문 복장', '장례식장 옷', '검은 옷'],
    triggerExamples: ['장례식장 방문', '회사 선배 조문', '부고 조문'],
    conditionalText: '장례식장 방문에 맞는 단정한 복장을 준비할까요?',
    embeddingText: '장례식장 방문, 회사 선배 조문, 부고 조문처럼 조문을 위해 외출하는 일정. 추천 행동: 장례식장 방문에 맞는 단정하고 차분한 복장 준비하기.',
    category: 'item', actionType: 'prepare', targetType: 'funeral_attire',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'social_occasion_v0.1', isActive: true
  }
] AS row
MERGE (r:RecommendationTemplate {code: row.code})
ON CREATE SET r.createdAt = datetime()
SET r += row,
    r.updatedAt = datetime();


// ============================================================
// 6. 기존 공용 노드 확인 (속성 수정 없음)
// 기대 missingSharedCodes = []
// ============================================================

OPTIONAL MATCH (r:RecommendationTemplate)
WHERE r.code IN ['check_location', 'check_travel_time', 'check_transport']
WITH collect(r.code) AS foundCodes
RETURN [
  code IN ['check_location', 'check_travel_time', 'check_transport']
  WHERE NOT (code IN foundCodes)
] AS missingSharedCodes;


// ============================================================
// 7. Context 기반 추천 없음
// "경조사"만으로는 구체 준비를 단정하지 않는다.
// ============================================================


// ============================================================
// 8. EventType 기반 추천 25개
// ============================================================

UNWIND [
  {sourceCode: 'birthday', recommendationCode: 'prepare_celebration_gift', defaultRank: 1, requiredContexts: [], suggestionMode: 'contextual', reason: '생일·생신 선물 준비 여부 확인'},
  {sourceCode: 'birthday', recommendationCode: 'check_gift_delivery', defaultRank: 2, requiredContexts: [], suggestionMode: 'conditional', reason: '온라인 주문 선물의 배송 예정일 확인'},
  {sourceCode: 'birthday', recommendationCode: 'check_birthday_cake', defaultRank: 3, requiredContexts: [], suggestionMode: 'conditional', reason: '케이크가 있는 경우 예약·수령 일정 확인'},
  {sourceCode: 'birthday', recommendationCode: 'check_birthday_meal_reservation', defaultRank: 4, requiredContexts: [], suggestionMode: 'conditional', reason: '함께 식사하는 경우 예약 여부 확인'},
  {sourceCode: 'birthday', recommendationCode: 'prepare_birthday_greeting', defaultRank: 5, requiredContexts: [], suggestionMode: 'safe', reason: '생일 당일 축하 메시지나 연락 준비'},

  {sourceCode: 'wedding', recommendationCode: 'review_occasion_notice', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '청첩장에서 날짜·시간·장소 확인'},
  {sourceCode: 'wedding', recommendationCode: 'check_location', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '정확한 예식 장소 확인'},
  {sourceCode: 'wedding', recommendationCode: 'check_travel_time', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '예식 장소까지 이동시간 확인'},
  {sourceCode: 'wedding', recommendationCode: 'check_transport', defaultRank: 4, requiredContexts: [], suggestionMode: 'conditional', reason: '예식 장소까지 이동 경로 확인'},
  {sourceCode: 'wedding', recommendationCode: 'prepare_congratulatory_money', defaultRank: 5, requiredContexts: [], suggestionMode: 'contextual', reason: '축하금과 봉투 준비 여부 확인'},
  {sourceCode: 'wedding', recommendationCode: 'check_ceremony_attire', defaultRank: 6, requiredContexts: [], suggestionMode: 'conditional', reason: '별도 행사 복장 안내 확인'},

  {sourceCode: 'first_birthday', recommendationCode: 'review_occasion_notice', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '초대 안내에서 날짜·시간·장소 확인'},
  {sourceCode: 'first_birthday', recommendationCode: 'check_location', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '정확한 돌잔치 장소 확인'},
  {sourceCode: 'first_birthday', recommendationCode: 'check_travel_time', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '돌잔치 장소까지 이동시간 확인'},
  {sourceCode: 'first_birthday', recommendationCode: 'check_transport', defaultRank: 4, requiredContexts: [], suggestionMode: 'conditional', reason: '돌잔치 장소까지 이동 경로 확인'},
  {sourceCode: 'first_birthday', recommendationCode: 'prepare_celebration_gift', defaultRank: 5, requiredContexts: [], suggestionMode: 'contextual', reason: '돌 선물 준비 여부 확인'},
  {sourceCode: 'first_birthday', recommendationCode: 'prepare_congratulatory_money', defaultRank: 6, requiredContexts: [], suggestionMode: 'contextual', reason: '축하금과 봉투 준비 여부 확인'},

  {sourceCode: 'funeral', recommendationCode: 'review_occasion_notice', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '부고에서 날짜·장소와 발인 정보 확인'},
  {sourceCode: 'funeral', recommendationCode: 'check_funeral_room', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '장례식장과 빈소 호실 확인'},
  {sourceCode: 'funeral', recommendationCode: 'check_funeral_visiting_time', defaultRank: 3, requiredContexts: [], suggestionMode: 'safe', reason: '조문 가능 시간과 발인 시각 확인'},
  {sourceCode: 'funeral', recommendationCode: 'check_location', defaultRank: 4, requiredContexts: [], suggestionMode: 'safe', reason: '정확한 장례식장 위치 확인'},
  {sourceCode: 'funeral', recommendationCode: 'check_travel_time', defaultRank: 5, requiredContexts: [], suggestionMode: 'contextual', reason: '장례식장까지 이동시간 확인'},
  {sourceCode: 'funeral', recommendationCode: 'check_transport', defaultRank: 6, requiredContexts: [], suggestionMode: 'conditional', reason: '장례식장까지 이동 경로 확인'},
  {sourceCode: 'funeral', recommendationCode: 'prepare_condolence_money', defaultRank: 7, requiredContexts: [], suggestionMode: 'contextual', reason: '조의금과 봉투 준비 여부 확인'},
  {sourceCode: 'funeral', recommendationCode: 'check_funeral_attire', defaultRank: 8, requiredContexts: [], suggestionMode: 'contextual', reason: '조문 복장 준비'}
] AS row
MATCH (e:EventType {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (e)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = row.requiredContexts,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'social_occasion_v0.1',
    rel.isActive = true;


// ============================================================
// 9. 경조사 seed smoke check
// 기대: Context 1, EventType 4, RecommendationTemplate 12
//       신규 노드 17, RECOMMENDS 25, invalid* 0
// ============================================================

MATCH (n {seedSource: 'social_occasion_v0.1'})
RETURN labels(n)[0] AS label, count(*) AS nodeCount
ORDER BY label;

MATCH ()-[rel:RECOMMENDS {seedSource: 'social_occasion_v0.1'}]->()
RETURN
  count(rel) AS recommendsCount,
  sum(CASE
    WHEN rel.defaultRank IS NULL
      OR rel.suggestionMode IS NULL
      OR rel.requiredContexts IS NULL
    THEN 1 ELSE 0
  END) AS invalidRelationshipCount;

MATCH (r:RecommendationTemplate {seedSource: 'social_occasion_v0.1'})
RETURN
  count(r) AS socialOccasionRecommendationCount,
  sum(CASE
    WHEN r.embeddingText IS NULL
      OR r.conditionalText IS NULL
      OR r.suggestionLevel IS NULL
      OR r.defaultTiming IS NULL
    THEN 1 ELSE 0
  END) AS invalidRecommendationCount;
