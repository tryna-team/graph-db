// Tryna Hangout(지인과의 약속) 지식베이스 v0.1
//
// 전제:
// - teamProject v0.5와 travel v0.1 seed를 먼저 실행한다.
// - 기존 공용 RecommendationTemplate은 MATCH로만 재사용하며 속성을 덮어쓰지 않는다.
// - Neo4j Browser에서 statement 단위로 위에서부터 실행한다.
//
// 범위:
// - 친구, 가족, 지인과의 일반 약속
// - 식사·카페 약속
// - 영화·공연·전시처럼 시간과 표가 있는 외출
//
// 제외:
// - 사람 이름이나 장소 이름만으로 약속 목적 추론
// - 생일·기념일 선물 추천
// - 실시간 영업시간·날씨·교통정보 자체 제공


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
// 2. Context 1개
// 민수·성수 같은 단독 이름은 embeddingText에 넣지 않는다.
// 이름과 만나기/약속/식사 같은 행동 단서가 함께 있을 때만 이 맥락을 확정한다.
// ============================================================

UNWIND [
  {
    code: 'hangout',
    name: '지인과의 약속',
    description: '친구, 가족, 연인 또는 지인을 만나 함께 시간을 보내는 사적인 일정 맥락',
    examples: [
      '친구 만나기', '지인 약속', '친구랑 저녁 약속', '동네에서 지인 만나기',
      '데이트', '소개팅', '가족 모임', '동창 만나기',
      '친구와 한강 피크닉', '공원 산책 약속'
    ],
    exclusionExamples: [
      '민수', '지수', '성수', '가천대',
      '업무 미팅', '팀플 회의', '병원 예약', '상담 약속',
      '호텔 결혼식', '회사 회식',
      '카페 공부', '스터디 모임', '온라인 강의',
      '취업 면접', '첫 출근', '거래처 미팅', '고객사 방문'
    ],
    embeddingText: '친구 만나기, 지인과 약속, 친구랑 저녁 약속, 동네에서 친구 만나기, 데이트, 소개팅, 가족 모임, 동창 만나기, 친구와 한강 피크닉, 공원 산책 약속. 업무 목적이 아니라 아는 사람을 만나 식사하거나 대화하고 함께 시간을 보내는 사적인 일정.',
    contextLevel: 'category',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  }
] AS row
MERGE (c:Context {code: row.code})
ON CREATE SET c.createdAt = datetime()
SET c += row,
    c.updatedAt = datetime();


// ============================================================
// 3. EventType 3개
// ============================================================

UNWIND [
  {
    code: 'social_meetup',
    name: '일반 만남·약속',
    description: '친구, 가족 또는 지인과 특정 시간과 장소에서 만나는 일정',
    examples: ['친구 만나기', '지인이랑 약속', '동네에서 만나기', '데이트', '소개팅', '가족 모임'],
    exclusionExamples: [
      '업무 미팅', '팀플 회의', '상담 약속', '병원 예약',
      '호텔 결혼식', '회사 회식', '그룹 스터디', '스터디 모임', '학교 수업',
      '취업 면접', '첫 출근', '거래처 미팅', '고객사 방문'
    ],
    embeddingText: '친구 만나기, 친구랑 약속, 동네에서 만나기, 데이트, 소개팅, 가족 모임처럼 아는 사람과 정해진 시간과 장소에서 만나는 사적인 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'dining_meetup',
    name: '식사·카페 약속',
    description: '지인과 식당이나 카페에서 함께 먹고 마시며 만나는 일정',
    examples: ['지인이랑 저녁', '친구랑 점심', '카페 약속', '소개팅 식사', '가족 외식'],
    exclusionExamples: [
      '혼밥', '배달 주문', '장보기', '식단 기록',
      '카페 공부', '스터디카페', '카페 작업', '혼자 공부'
    ],
    embeddingText: '친구랑 저녁 먹기, 지인과 점심 약속, 카페에서 만나기, 소개팅 식사, 가족 외식처럼 다른 사람과 식당이나 카페에서 함께 먹고 마시는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'ticketed_outing',
    name: '영화·공연·전시 약속',
    description: '영화, 공연, 전시 또는 경기처럼 시작 시각과 입장 정보가 있는 외출 일정',
    examples: ['친구랑 영화', '공연 보러 가기', '전시 약속', '뮤지컬', '야구 직관'],
    exclusionExamples: ['항공권', 'KTX 승차권', '공항 출국', '온라인 영상 보기'],
    embeddingText: '친구와 영화 보기, 공연 보러 가기, 전시 관람 약속, 뮤지컬 관람, 야구 직관처럼 정해진 시작 시각과 입장권 또는 예매내역이 있는 문화·관람 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  }
] AS row
MERGE (e:EventType {code: row.code})
ON CREATE SET e.createdAt = datetime()
SET e += row,
    e.updatedAt = datetime();


// ============================================================
// 4. PlaceType 3개
// 기존 cafe PlaceType은 새로 만들거나 수정하지 않고 그대로 재사용한다.
// ============================================================

UNWIND [
  {
    code: 'restaurant',
    name: '식당',
    attendanceMode: 'offline',
    description: '식사 예약, 영업시간과 인원 확인이 필요할 수 있는 음식점',
    examples: ['식당', '레스토랑', '고깃집', '파스타집', '이자카야', '맛집'],
    embeddingText: '식당, 레스토랑, 고깃집, 파스타집, 이자카야, 맛집처럼 여러 사람이 만나 식사하는 음식점 장소.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'entertainment_venue',
    name: '영화관·공연장·전시장',
    attendanceMode: 'offline',
    description: '정해진 시각과 입장권에 맞춰 영화, 공연, 전시 또는 경기를 관람하는 장소',
    examples: ['영화관', 'CGV', '메가박스', '공연장', '극장', '미술관', '전시장', '야구장'],
    embeddingText: '영화관, CGV, 메가박스, 공연장, 극장, 미술관, 전시장, 야구장처럼 시작 시각과 입장 위치를 확인하고 관람하는 장소.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'park_outdoor',
    name: '공원·야외 만남 장소',
    attendanceMode: 'offline',
    description: '공원, 강변, 광장 등 날씨의 영향을 받는 야외 만남 장소',
    examples: ['공원', '한강', '서울숲', '피크닉', '야외 광장', '산책로'],
    embeddingText: '공원, 한강, 서울숲, 피크닉 장소, 야외 광장, 산책로처럼 날씨의 영향을 받으며 사람을 만나거나 시간을 보내는 야외 장소.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  }
] AS row
MERGE (p:PlaceType {code: row.code})
ON CREATE SET p.createdAt = datetime()
SET p += row,
    p.updatedAt = datetime();


// ============================================================
// 5. Hangout 전용 RecommendationTemplate 11개
// ============================================================

UNWIND [
  {
    code: 'confirm_meetup_time', name: '약속 시간 다시 확인하기',
    description: '상대방과 정한 날짜와 시작 시간을 다시 확인한다.',
    examples: ['약속 시간', '몇 시에 만나지', '만나는 시간'],
    triggerExamples: ['친구 약속', '데이트', '소개팅', '가족 모임'],
    conditionalText: '상대방과 정한 약속 시간을 다시 확인할까요?',
    embeddingText: '친구 약속, 데이트, 소개팅, 가족 모임처럼 다른 사람과 정해진 시간에 만나는 일정. 추천 행동: 상대방과 정한 약속 시간 다시 확인하기.',
    category: 'check', actionType: 'check', targetType: 'schedule',
    suggestionLevel: 'safe', defaultTiming: '일정 확정 직후 또는 전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'review_meetup_details', name: '최근 대화에서 약속 내용 확인하기',
    description: '최근 대화에서 시간, 장소 또는 인원이 바뀌지 않았는지 확인한다.',
    examples: ['카톡 다시 보기', '약속 변경 확인', '최근 대화 확인'],
    triggerExamples: ['오래전에 잡은 약속', '친구 약속', '장소가 바뀐 약속'],
    conditionalText: '최근 대화에서 시간이나 장소가 바뀌지 않았는지 확인할까요?',
    embeddingText: '오래전에 잡은 약속, 친구와 정한 일정, 장소가 바뀔 수 있는 만남. 추천 행동: 최근 대화에서 약속 시간, 장소와 변경 내용 확인하기.',
    category: 'check', actionType: 'review', targetType: 'conversation',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'check_reservation_status', name: '예약 여부와 예약자명 확인하기',
    description: '식당이나 이용 장소의 예약 여부, 날짜, 시간과 예약자명을 확인한다.',
    examples: ['식당 예약', '예약 확인', '예약자명', '몇 명 예약'],
    triggerExamples: ['저녁 약속', '맛집', '레스토랑', '소개팅 식사'],
    conditionalText: '예약했다면 날짜와 시간, 예약자명을 확인할까요?',
    embeddingText: '저녁 약속, 맛집, 레스토랑, 소개팅 식사처럼 예약할 수 있는 장소에서 만나는 일정. 추천 행동: 예약 여부와 날짜, 시간, 예약자명 확인하기.',
    category: 'check', actionType: 'check', targetType: 'reservation',
    suggestionLevel: 'contextual', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'check_business_hours', name: '영업시간과 휴무 여부 확인하기',
    description: '방문할 식당이나 카페의 영업시간과 휴무 여부를 확인한다.',
    examples: ['영업시간', '몇 시까지', '휴무일', '라스트 오더'],
    triggerExamples: ['식당 약속', '카페 약속', '늦은 저녁', '주말 방문'],
    conditionalText: '방문할 장소의 영업시간과 휴무 여부를 확인할까요?',
    embeddingText: '식당 약속, 카페 약속, 늦은 저녁, 주말 방문처럼 운영시간이 중요한 일정. 추천 행동: 방문할 장소의 영업시간과 휴무 여부 확인하기.',
    category: 'check', actionType: 'check', targetType: 'business_hours',
    suggestionLevel: 'contextual', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'check_dietary_preferences', name: '못 먹는 음식이 있는지 확인하기',
    description: '함께 식사하는 사람에게 알레르기나 먹지 못하는 음식이 있는지 확인한다.',
    examples: ['알레르기', '못 먹는 음식', '식사 취향'],
    triggerExamples: ['소개팅 식사', '여러 명 외식', '처음 같이 먹는 사람'],
    conditionalText: '함께 먹는 사람에게 못 먹는 음식이 있는지 확인할까요?',
    embeddingText: '소개팅 식사, 여러 명 외식, 처음 같이 먹는 사람처럼 메뉴 선택을 함께 해야 하는 일정. 추천 행동: 상대방에게 알레르기나 못 먹는 음식이 있는지 확인하기.',
    category: 'check', actionType: 'check', targetType: 'dietary_preference',
    suggestionLevel: 'conditional', defaultTiming: '예약 또는 메뉴 선택 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'check_event_start_time', name: '상영·공연 시작 시각 확인하기',
    description: '영화, 공연, 전시 또는 경기의 시작 시각과 입장 가능 시간을 확인한다.',
    examples: ['영화 시간', '공연 시작', '입장 시간', '경기 시작'],
    triggerExamples: ['영화 약속', '뮤지컬', '공연', '야구 직관'],
    conditionalText: '상영·공연 시작 시각과 입장 가능 시간을 확인할까요?',
    embeddingText: '영화 약속, 뮤지컬, 공연, 야구 직관처럼 정해진 시각에 관람하는 일정. 추천 행동: 상영, 공연 또는 경기 시작 시각과 입장 가능 시간 확인하기.',
    category: 'check', actionType: 'check', targetType: 'schedule',
    suggestionLevel: 'safe', defaultTiming: '전날 또는 출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'check_event_ticket', name: '예매내역과 입장권 확인하기',
    description: '영화, 공연, 전시 또는 경기의 예매 날짜, 좌석과 입장권을 확인한다.',
    examples: ['영화표', '공연 티켓', '예매내역', '좌석 확인'],
    triggerExamples: ['영화', '공연', '전시', '뮤지컬', '야구 직관'],
    conditionalText: '예매 날짜와 좌석, 입장권을 확인할까요?',
    embeddingText: '영화, 공연, 전시, 뮤지컬, 야구 직관처럼 예매내역이나 입장권이 있는 일정. 추천 행동: 예매 날짜, 좌석과 입장권 확인하기.',
    category: 'check', actionType: 'check', targetType: 'ticket',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'save_event_ticket', name: '입장권을 휴대전화에 저장하기',
    description: '인터넷 연결 없이도 꺼낼 수 있게 모바일 입장권이나 예매번호를 저장한다.',
    examples: ['티켓 캡처', '예매번호 저장', '모바일 티켓'],
    triggerExamples: ['영화표', '공연 티켓', '전시 입장권', '경기 티켓'],
    conditionalText: '입장권이나 예매번호를 휴대전화에 저장해둘까요?',
    embeddingText: '영화표, 공연 티켓, 전시 입장권, 경기 티켓처럼 현장에서 휴대전화로 보여주는 표가 있는 일정. 추천 행동: 입장권이나 예매번호를 휴대전화에 저장하기.',
    category: 'document', actionType: 'save', targetType: 'ticket',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'check_venue_entrance', name: '건물과 입장 위치 확인하기',
    description: '상영관, 공연장, 전시장 또는 경기장의 정확한 건물과 입장 위치를 확인한다.',
    examples: ['입구 확인', '상영관', '공연장 위치', '게이트'],
    triggerExamples: ['복합 쇼핑몰 영화관', '공연장', '전시장', '야구장 게이트'],
    conditionalText: '정확한 건물과 입장 위치를 확인할까요?',
    embeddingText: '복합 쇼핑몰 영화관, 공연장, 전시장, 야구장처럼 입구나 관람 구역이 여러 곳인 일정. 추천 행동: 정확한 건물, 상영관과 입장 위치 확인하기.',
    category: 'check', actionType: 'check', targetType: 'location',
    suggestionLevel: 'safe', defaultTiming: '전날 또는 출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'check_return_transport', name: '돌아오는 교통편 확인하기',
    description: '늦게 끝나는 약속이라면 막차와 귀가 경로를 확인한다.',
    examples: ['막차', '집에 오는 길', '귀가 교통편'],
    triggerExamples: ['늦은 저녁 약속', '밤 공연', '야구 경기', '막차 전'],
    conditionalText: '늦게 끝날 예정이라면 돌아오는 교통편을 확인할까요?',
    embeddingText: '늦은 저녁 약속, 밤 공연, 야구 경기처럼 늦게 끝날 수 있는 일정. 추천 행동: 일정 종료 시각, 막차와 돌아오는 교통편 확인하기.',
    category: 'check', actionType: 'check', targetType: 'return_transport',
    suggestionLevel: 'conditional', defaultTiming: '전날',
    selectionHint: '파싱된 종료 시각이 늦거나 입력에 밤·막차 단서가 있을 때 우선',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
  },
  {
    code: 'check_outdoor_weather', name: '야외 약속 시간대 날씨 확인하기',
    description: '야외에서 만나는 시간대의 비, 기온과 바람을 확인한다.',
    examples: ['야외 날씨', '비 예보', '한강 날씨', '기온'],
    triggerExamples: ['공원 약속', '한강 피크닉', '야외 산책', '서울숲'],
    conditionalText: '야외에서 만날 예정이라면 그 시간대 날씨를 확인할까요?',
    embeddingText: '공원 약속, 한강 피크닉, 야외 산책, 서울숲처럼 날씨의 영향을 받는 만남. 추천 행동: 야외 약속 시간대의 비, 기온과 바람 확인하기.',
    category: 'check', actionType: 'check', targetType: 'weather',
    suggestionLevel: 'contextual', defaultTiming: '전날 또는 출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'hangout_v0.1', isActive: true
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
WHERE r.code IN [
  'check_location',
  'check_travel_time',
  'check_transport',
  'charge_phone',
  'pack_power_bank',
  'pack_water'
]
WITH collect(r.code) AS foundCodes
RETURN [
  code IN [
    'check_location',
    'check_travel_time',
    'check_transport',
    'charge_phone',
    'pack_power_bank',
    'pack_water'
  ]
  WHERE NOT (code IN foundCodes)
] AS missingSharedCodes;


// ============================================================
// 7. 여행 Place 관계의 교차 카테고리 gate 보정
// 기존 travel seed를 이미 실행했다면 18개 관계가 갱신된다.
// 수정된 travel seed를 재실행한 뒤라면 0개여도 정상이다.
// domestic_travel 조건이 있는 pack_id 관계는 변경하지 않는다.
// ============================================================

MATCH (p:PlaceType)-[rel:RECOMMENDS]->(:RecommendationTemplate)
WHERE p.code IN [
  'airport',
  'station_terminal',
  'accommodation',
  'travel_destination'
]
  AND rel.seedSource = 'travel_v0.1'
  AND size(coalesce(rel.requiredContexts, [])) = 0
SET rel.requiredContexts = ['travel'],
    rel.updatedAt = datetime()
RETURN count(rel) AS newlyGatedTravelPlaceRelationshipCount;


// ============================================================
// 8. Context 기반 추천 7개
// ============================================================

UNWIND [
  {sourceCode: 'hangout', recommendationCode: 'confirm_meetup_time', defaultRank: 1, suggestionMode: 'safe', reason: '상대방과 정한 약속 시간 확인'},
  {sourceCode: 'hangout', recommendationCode: 'check_location', defaultRank: 2, suggestionMode: 'safe', reason: '정확한 만남 장소 확인'},
  {sourceCode: 'hangout', recommendationCode: 'review_meetup_details', defaultRank: 3, suggestionMode: 'safe', reason: '최근 대화에서 약속 변경 내용 확인'},
  {sourceCode: 'hangout', recommendationCode: 'check_travel_time', defaultRank: 4, suggestionMode: 'contextual', reason: '만남 장소까지 이동시간 확인'},
  {sourceCode: 'hangout', recommendationCode: 'check_transport', defaultRank: 5, suggestionMode: 'conditional', reason: '만남 장소까지 이동 경로 확인'},
  {sourceCode: 'hangout', recommendationCode: 'charge_phone', defaultRank: 8, suggestionMode: 'contextual', reason: '연락과 길찾기에 사용할 휴대전화 충전'},
  {sourceCode: 'hangout', recommendationCode: 'pack_power_bank', defaultRank: 9, suggestionMode: 'conditional', reason: '장시간 외출 중 배터리 부족 대비'}
] AS row
MATCH (c:Context {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (c)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = [],
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'hangout_v0.1',
    rel.isActive = true;


// ============================================================
// 9. EventType 기반 추천 22개
// ============================================================

UNWIND [
  {sourceCode: 'social_meetup', recommendationCode: 'confirm_meetup_time', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '상대방과 정한 약속 시간 확인'},
  {sourceCode: 'social_meetup', recommendationCode: 'check_location', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '정확한 만남 장소 확인'},
  {sourceCode: 'social_meetup', recommendationCode: 'review_meetup_details', defaultRank: 3, requiredContexts: [], suggestionMode: 'safe', reason: '최근 대화에서 변경 내용 확인'},
  {sourceCode: 'social_meetup', recommendationCode: 'check_travel_time', defaultRank: 4, requiredContexts: [], suggestionMode: 'contextual', reason: '만남 장소까지 이동시간 확인'},
  {sourceCode: 'social_meetup', recommendationCode: 'check_transport', defaultRank: 5, requiredContexts: [], suggestionMode: 'conditional', reason: '만남 장소까지 이동 경로 확인'},
  {sourceCode: 'social_meetup', recommendationCode: 'charge_phone', defaultRank: 7, requiredContexts: [], suggestionMode: 'contextual', reason: '연락과 길찾기에 사용할 휴대전화 충전'},
  {sourceCode: 'social_meetup', recommendationCode: 'check_return_transport', defaultRank: 10, requiredContexts: [], suggestionMode: 'conditional', reason: '늦게 끝나는 약속의 귀가 경로 확인'},

  {sourceCode: 'dining_meetup', recommendationCode: 'confirm_meetup_time', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '식사 약속 시간 확인'},
  {sourceCode: 'dining_meetup', recommendationCode: 'check_location', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '정확한 식당·카페 위치 확인'},
  {sourceCode: 'dining_meetup', recommendationCode: 'check_reservation_status', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '예약 여부와 예약자명 확인'},
  {sourceCode: 'dining_meetup', recommendationCode: 'check_business_hours', defaultRank: 4, requiredContexts: [], suggestionMode: 'contextual', reason: '영업시간과 휴무 여부 확인'},
  {sourceCode: 'dining_meetup', recommendationCode: 'check_dietary_preferences', defaultRank: 5, requiredContexts: [], suggestionMode: 'conditional', reason: '함께 먹는 사람의 식사 제약 확인'},
  {sourceCode: 'dining_meetup', recommendationCode: 'check_travel_time', defaultRank: 6, requiredContexts: [], suggestionMode: 'contextual', reason: '식사 장소까지 이동시간 확인'},
  {sourceCode: 'dining_meetup', recommendationCode: 'check_return_transport', defaultRank: 10, requiredContexts: [], suggestionMode: 'conditional', reason: '늦은 식사 약속의 귀가 경로 확인'},

  {sourceCode: 'ticketed_outing', recommendationCode: 'check_event_start_time', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '상영·공연 시작 시각 확인'},
  {sourceCode: 'ticketed_outing', recommendationCode: 'check_event_ticket', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '예매내역과 입장권 확인'},
  {sourceCode: 'ticketed_outing', recommendationCode: 'save_event_ticket', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '현장에서 보여줄 입장권 저장'},
  {sourceCode: 'ticketed_outing', recommendationCode: 'check_venue_entrance', defaultRank: 4, requiredContexts: [], suggestionMode: 'safe', reason: '건물과 입장 위치 확인'},
  {sourceCode: 'ticketed_outing', recommendationCode: 'check_travel_time', defaultRank: 5, requiredContexts: [], suggestionMode: 'contextual', reason: '관람 장소까지 이동시간 확인'},
  {sourceCode: 'ticketed_outing', recommendationCode: 'check_transport', defaultRank: 6, requiredContexts: [], suggestionMode: 'conditional', reason: '관람 장소까지 이동 경로 확인'},
  {sourceCode: 'ticketed_outing', recommendationCode: 'charge_phone', defaultRank: 7, requiredContexts: [], suggestionMode: 'contextual', reason: '모바일 입장권과 연락에 사용할 휴대전화 충전'},
  {sourceCode: 'ticketed_outing', recommendationCode: 'check_return_transport', defaultRank: 8, requiredContexts: [], suggestionMode: 'conditional', reason: '늦게 끝나는 관람 일정의 귀가 경로 확인'}
] AS row
MATCH (e:EventType {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (e)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = row.requiredContexts,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'hangout_v0.1',
    rel.isActive = true;


// ============================================================
// 10. PlaceType 기반 추천 16개
// cafe의 기존 위치·이동 관계는 유지하고 영업시간 관계만 추가한다.
// 다른 카테고리에서 이 PlaceType만 잡혀도 열리지 않도록 hangout 맥락을 요구한다.
// ============================================================

UNWIND [
  {sourceCode: 'restaurant', recommendationCode: 'check_location', defaultRank: 1, requiredContexts: ['hangout'], suggestionMode: 'safe', reason: '정확한 식당 위치 확인'},
  {sourceCode: 'restaurant', recommendationCode: 'check_reservation_status', defaultRank: 2, requiredContexts: ['hangout'], suggestionMode: 'contextual', reason: '예약 여부와 예약자명 확인'},
  {sourceCode: 'restaurant', recommendationCode: 'check_business_hours', defaultRank: 3, requiredContexts: ['hangout'], suggestionMode: 'contextual', reason: '영업시간과 휴무 여부 확인'},
  {sourceCode: 'restaurant', recommendationCode: 'check_dietary_preferences', defaultRank: 4, requiredContexts: ['hangout'], suggestionMode: 'conditional', reason: '함께 먹는 사람의 식사 제약 확인'},
  {sourceCode: 'restaurant', recommendationCode: 'check_travel_time', defaultRank: 5, requiredContexts: ['hangout'], suggestionMode: 'contextual', reason: '식당까지 이동시간 확인'},

  {sourceCode: 'entertainment_venue', recommendationCode: 'check_event_start_time', defaultRank: 1, requiredContexts: ['hangout'], suggestionMode: 'safe', reason: '상영·공연 시작 시각 확인'},
  {sourceCode: 'entertainment_venue', recommendationCode: 'check_event_ticket', defaultRank: 2, requiredContexts: ['hangout'], suggestionMode: 'safe', reason: '예매내역과 입장권 확인'},
  {sourceCode: 'entertainment_venue', recommendationCode: 'save_event_ticket', defaultRank: 3, requiredContexts: ['hangout'], suggestionMode: 'contextual', reason: '모바일 입장권 저장'},
  {sourceCode: 'entertainment_venue', recommendationCode: 'check_venue_entrance', defaultRank: 4, requiredContexts: ['hangout'], suggestionMode: 'safe', reason: '건물과 입장 위치 확인'},
  {sourceCode: 'entertainment_venue', recommendationCode: 'check_travel_time', defaultRank: 5, requiredContexts: ['hangout'], suggestionMode: 'contextual', reason: '관람 장소까지 이동시간 확인'},

  {sourceCode: 'park_outdoor', recommendationCode: 'check_location', defaultRank: 1, requiredContexts: ['hangout'], suggestionMode: 'safe', reason: '정확한 야외 만남 위치 확인'},
  {sourceCode: 'park_outdoor', recommendationCode: 'check_outdoor_weather', defaultRank: 2, requiredContexts: ['hangout'], suggestionMode: 'contextual', reason: '야외 약속 시간대 날씨 확인'},
  {sourceCode: 'park_outdoor', recommendationCode: 'check_travel_time', defaultRank: 3, requiredContexts: ['hangout'], suggestionMode: 'contextual', reason: '야외 만남 장소까지 이동시간 확인'},
  {sourceCode: 'park_outdoor', recommendationCode: 'pack_water', defaultRank: 4, requiredContexts: ['hangout'], suggestionMode: 'conditional', reason: '장시간 야외 일정 중 마실 물 준비'},
  {sourceCode: 'park_outdoor', recommendationCode: 'pack_power_bank', defaultRank: 5, requiredContexts: ['hangout'], suggestionMode: 'conditional', reason: '장시간 야외 일정 중 배터리 부족 대비'},

  {sourceCode: 'cafe', recommendationCode: 'check_business_hours', defaultRank: 4, requiredContexts: ['hangout'], suggestionMode: 'contextual', reason: '카페 영업시간과 휴무 여부 확인'}
] AS row
MATCH (p:PlaceType {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (p)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = row.requiredContexts,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'hangout_v0.1',
    rel.isActive = true;


// ============================================================
// 11. Hangout seed smoke check
// 기대: Context 1, EventType 3, PlaceType 3, RecommendationTemplate 11
//       RECOMMENDS 45, invalid* 0
// ============================================================

MATCH (n {seedSource: 'hangout_v0.1'})
RETURN labels(n)[0] AS label, count(*) AS nodeCount
ORDER BY label;

MATCH ()-[rel:RECOMMENDS {seedSource: 'hangout_v0.1'}]->()
RETURN
  count(rel) AS recommendsCount,
  sum(CASE
    WHEN rel.defaultRank IS NULL
      OR rel.suggestionMode IS NULL
      OR rel.requiredContexts IS NULL
    THEN 1 ELSE 0
  END) AS invalidRelationshipCount;

MATCH (r:RecommendationTemplate {seedSource: 'hangout_v0.1'})
RETURN
  count(r) AS hangoutRecommendationCount,
  sum(CASE
    WHEN r.embeddingText IS NULL
      OR r.conditionalText IS NULL
      OR r.suggestionLevel IS NULL
    THEN 1 ELSE 0
  END) AS invalidRecommendationCount;
