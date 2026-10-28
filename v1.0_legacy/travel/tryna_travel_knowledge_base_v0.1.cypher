// Tryna 여행 카테고리 지식베이스 v0.1 (additive MVP seed)
//
// 전제:
// - teamProject/tryna_team_project_knowledge_base_v0.5.cypher를 먼저 실행한다.
// - 기존 공용 RecommendationTemplate 4개는 MATCH로만 재사용하며 속성을 덮어쓰지 않는다.
// - 여러 독립 statement로 구성되어 있으므로 Neo4j Browser에서 statement 단위로 실행한다.
//
// 범위:
// - 일반 여행 / 국내여행 / 해외여행
// - 교통편 출발 / 숙소 체크인
// - 예약, 날씨, 이동, 짐, 해외 출국 준비
//
// 제외:
// - 실시간 항공편·날씨·지도 조회
// - 비자·입국 요건 단정
// - 관광지·맛집·상세 여행 일정 자동 생성


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
// 2. Context
// domestic_travel과 international_travel은 같은 exclusiveGroup이다.
// 앱에서는 둘을 동시에 확정하지 않고, subtype이 잡히면 상위 travel도 포함한다.
// ============================================================

UNWIND [
  {
    code: 'travel',
    name: '여행',
    description: '평소 생활권을 벗어나 다른 지역으로 이동하거나 머무르는 일정 맥락',
    examples: ['여행', '휴가', '1박 2일', '여행 출발', '가족여행', '친구랑 여행'],
    exclusionExamples: [
      '일본어 공부', '여행 계획 회의', '호텔 결혼식', '공항 마중',
      '고객사 방문', '다른 지점 출근'
    ],
    embeddingText: '여행, 휴가, 1박 2일 여행, 여행 출발, 가족여행, 친구와 떠나는 여행. 다른 지역으로 이동하거나 숙박하며 보내는 일정.',
    contextLevel: 'category',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'domestic_travel',
    name: '국내여행',
    description: '대한민국 안의 다른 지역으로 이동하거나 머무르는 여행 맥락',
    examples: ['제주도', '부산 여행', '강릉 1박 2일', '경주 여행', 'KTX 부산'],
    exclusionExamples: ['부산 회의', '강릉 출장', '제주도 친구 이름'],
    embeddingText: '국내여행, 제주도 여행, 부산 여행, 강릉 1박 2일, 경주 여행, KTX 타고 부산 가기. 국내 다른 지역으로 이동하거나 숙박하며 보내는 여행 일정.',
    contextLevel: 'subtype', parentCode: 'travel', exclusiveGroup: 'travel_scope',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'international_travel',
    name: '해외여행',
    description: '다른 나라로 출국해 이동하거나 머무르는 여행 맥락',
    examples: ['해외여행', '일본 여행', '도쿄', '오사카 3박 4일', '유럽 여행', '출국'],
    exclusionExamples: ['일본어 공부', '일본 음식점', '인천공항 친구 마중', '공항 픽업'],
    embeddingText: '해외여행, 일본 여행, 도쿄 여행, 오사카 3박 4일, 유럽 여행, 해외 출국, 인천공항 국제선 출국. 다른 나라로 출국해 이동하거나 숙박하는 여행 일정.',
    contextLevel: 'subtype', parentCode: 'travel', exclusiveGroup: 'travel_scope',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  }
] AS row
MERGE (c:Context {code: row.code})
ON CREATE SET c.createdAt = datetime()
SET c += row,
    c.updatedAt = datetime();

MATCH (parent:Context {code: 'travel'})
UNWIND ['domestic_travel', 'international_travel'] AS childCode
MATCH (child:Context {code: childCode})
MERGE (child)-[rel:IS_A]->(parent)
SET rel.seedVersion = '0.1',
    rel.seedSource = 'travel_v0.1',
    rel.isActive = true;


// ============================================================
// 3. EventType
// 장소명만으로 탑승·체크인을 확정하지 않도록 embeddingText는 행동 표현 중심이다.
// ============================================================

UNWIND [
  {
    code: 'travel_departure',
    name: '여행 출발',
    description: '여행을 시작하거나 목적지로 떠나는 일정',
    examples: ['여행', '여행 출발', '휴가 출발', '제주도 가는 날', '일본 가는 날'],
    exclusionExamples: ['여행 계획 회의', '여행 사진 정리', '일본어 공부'],
    embeddingText: '여행 출발, 휴가 떠나는 날, 제주도 여행 가는 날, 부산 여행 시작, 일본 여행 출국. 여행 준비를 마치고 목적지로 떠나는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'transport_departure',
    name: '교통편 출발·탑승',
    description: '비행기, 기차, 버스 또는 배처럼 정해진 교통편에 탑승하는 일정',
    examples: ['비행기', '인천공항', 'KTX', '서울역', '고속버스', '공항 2터미널'],
    exclusionExamples: ['인천공항 친구 마중', '서울역 약속', '공항 픽업'],
    embeddingText: '비행기 타기, 항공편 출발, 인천공항에서 출국, KTX 탑승, 서울역에서 기차 출발, 고속버스 타기, 여객선 출발. 표와 출발 시각이 정해진 교통편에 탑승하는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'accommodation_checkin',
    name: '숙소 체크인',
    description: '호텔, 펜션, 게스트하우스 등 예약한 숙소에 들어가는 일정',
    examples: ['호텔', '체크인', '숙소', '펜션 입실', '에어비앤비'],
    exclusionExamples: ['호텔 결혼식', '호텔 뷔페', '호텔 카페'],
    embeddingText: '호텔 체크인, 숙소 입실, 펜션 체크인, 리조트 입실, 게스트하우스 체크인, 에어비앤비 숙박 시작. 예약한 숙박 장소에 들어가는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  }
] AS row
MERGE (e:EventType {code: row.code})
ON CREATE SET e.createdAt = datetime()
SET e += row,
    e.updatedAt = datetime();


// ============================================================
// 4. PlaceType
// PlaceType만 잡히고 EventType/Context가 없으면 추천을 열지 않는다.
// ============================================================

UNWIND [
  {
    code: 'airport',
    name: '공항',
    attendanceMode: 'offline',
    description: '항공편 출발·도착, 탑승 수속과 수하물 처리가 이루어지는 장소',
    examples: ['공항', '인천공항', '김포공항', '김해공항', '제주공항', '공항 터미널'],
    embeddingText: '공항, 인천공항, 김포공항, 김해공항, 제주공항, 국내선 터미널, 국제선 터미널, 항공편을 이용하는 장소.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'station_terminal',
    name: '역·터미널',
    attendanceMode: 'offline',
    description: '기차, 버스 또는 배를 타는 역과 터미널',
    examples: ['기차역', '서울역', '부산역', 'KTX역', '버스터미널', '여객터미널'],
    embeddingText: '기차역, 서울역, 부산역, KTX역, 버스터미널, 고속버스터미널, 여객터미널. 기차, 버스 또는 배를 타는 장소.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'accommodation',
    name: '숙소',
    attendanceMode: 'offline',
    description: '호텔, 리조트, 펜션, 게스트하우스 등 숙박하는 장소',
    examples: ['호텔', '리조트', '펜션', '게스트하우스', '숙소', '에어비앤비'],
    embeddingText: '호텔, 리조트, 펜션, 게스트하우스, 숙소, 에어비앤비처럼 여행 중 머무르는 숙박 장소.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'travel_destination',
    name: '여행지',
    attendanceMode: 'offline',
    description: '관광, 휴식 또는 체험을 위해 방문하는 여행 목적지',
    examples: ['제주도', '부산', '강릉', '경주', '일본', '도쿄', '오사카', '여행지'],
    embeddingText: '제주도, 부산, 강릉, 경주, 일본, 도쿄, 오사카 같은 국내외 여행 목적지와 관광 지역.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  }
] AS row
MERGE (p:PlaceType {code: row.code})
ON CREATE SET p.createdAt = datetime()
SET p += row,
    p.updatedAt = datetime();


// ============================================================
// 5. 여행 전용 RecommendationTemplate 21개
// 해외 전용 6개는 node.requiredContexts에도 gate를 기록한다.
// RecommendationTemplate 벡터 조회에서도 이 속성을 검사해야 한다.
// ============================================================

UNWIND [
  {
    code: 'check_travel_dates', name: '여행 날짜와 기간 확인하기',
    description: '출발일, 숙박 기간과 돌아오는 날짜를 다시 확인한다.',
    examples: ['여행 날짜', '출발일', '1박 2일', '돌아오는 날'],
    triggerExamples: ['여행', '휴가', '1박 2일', '여행 출발'],
    conditionalText: '출발일과 돌아오는 날짜를 다시 확인할까요?',
    embeddingText: '여행, 휴가, 1박 2일, 여행 출발처럼 여러 날짜에 걸쳐 이동하는 일정. 추천 행동: 여행 날짜와 기간 확인하기.',
    category: 'check', actionType: 'check', targetType: 'schedule',
    suggestionLevel: 'safe', defaultTiming: '일정 확정 직후 또는 전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_weather', name: '여행지 날씨 확인하기',
    description: '짐을 싸기 전에 여행 기간의 날씨와 기온을 확인한다.',
    examples: ['여행 날씨', '기온', '비 예보', '제주 날씨'],
    triggerExamples: ['여행', '제주 여행', '해외여행', '여행지'],
    conditionalText: '짐을 싸기 전에 여행지 날씨를 확인할까요?',
    embeddingText: '여행, 제주 여행, 해외여행, 여행지처럼 날씨에 따라 옷과 준비물이 달라지는 일정. 추천 행동: 여행지 날씨 확인하기.',
    category: 'check', actionType: 'check', targetType: 'weather',
    suggestionLevel: 'safe', defaultTiming: '짐 싸기 전 또는 전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'charge_phone', name: '휴대전화 미리 충전하기',
    description: '지도와 예약내역을 확인할 휴대전화를 출발 전에 충전한다.',
    examples: ['휴대폰 충전', '배터리 충전', '전화 충전'],
    triggerExamples: ['여행 출발', '장거리 이동', '공항'],
    conditionalText: '출발 전에 휴대전화를 충전해둘까요?',
    embeddingText: '여행 출발, 장거리 이동, 공항 가기처럼 휴대전화로 지도와 예약내역을 오래 확인하는 일정. 추천 행동: 휴대전화 미리 충전하기.',
    category: 'item', actionType: 'charge', targetType: 'device',
    suggestionLevel: 'contextual', defaultTiming: '전날 밤',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'pack_phone_charger', name: '휴대전화 충전기 챙기기',
    description: '여행 중 휴대전화를 충전할 수 있도록 충전기와 케이블을 챙긴다.',
    examples: ['휴대폰 충전기', '충전 케이블', 'C타입 충전기'],
    triggerExamples: ['여행', '숙박', '장거리 이동'],
    conditionalText: '휴대전화 충전기와 케이블을 챙길까요?',
    embeddingText: '여행, 숙박, 장거리 이동처럼 집 밖에서 휴대전화를 충전해야 하는 일정. 추천 행동: 휴대전화 충전기와 케이블 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'device_accessory',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'pack_id', name: '신분증 챙기기',
    description: '국내선, 숙소 또는 렌터카에서 신분 확인에 쓸 신분증을 챙긴다.',
    examples: ['신분증', '주민등록증', '운전면허증'],
    triggerExamples: ['국내선', 'KTX', '숙소', '렌터카'],
    conditionalText: '신분 확인이 필요한 교통편이라면 신분증을 챙길까요?',
    embeddingText: '국내선 탑승, KTX 이용, 숙소 체크인, 렌터카 이용처럼 신분 확인이 있을 수 있는 일정. 추천 행동: 신분증 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'identification',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'pack_regular_medicine', name: '평소 복용하는 약 챙기기',
    description: '여행 중에도 필요한 평소 복용약을 챙긴다.',
    examples: ['복용약', '처방약', '개인 약'],
    triggerExamples: ['숙박 여행', '장기 여행', '복용약'],
    conditionalText: '평소 복용하는 약이 있다면 챙길까요?',
    embeddingText: '숙박 여행, 장기 여행, 평소 복용하는 약이 있는 여행 일정. 추천 행동: 평소 복용하는 약이 있다면 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'medicine',
    suggestionLevel: 'conditional', defaultTiming: '짐 싸기 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'pack_toiletries', name: '세면도구 챙기기',
    description: '숙박할 때 필요한 개인 세면용품을 챙긴다.',
    examples: ['칫솔', '치약', '세면도구', '개인용품'],
    triggerExamples: ['호텔', '숙소', '체크인', '1박 이상'],
    conditionalText: '숙박할 예정이라면 필요한 세면도구를 챙길까요?',
    embeddingText: '호텔, 숙소 체크인, 펜션 입실, 1박 이상 숙박하는 여행 일정. 추천 행동: 숙박한다면 필요한 세면도구 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'personal_item',
    suggestionLevel: 'conditional', defaultTiming: '짐 싸기 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'save_reservations_offline', name: '예약내역 오프라인 저장하기',
    description: '인터넷 연결 없이도 볼 수 있게 표와 예약내역을 저장한다.',
    examples: ['예약 화면 캡처', '탑승권 저장', '예약내역 다운로드'],
    triggerExamples: ['항공권', '승차권', '호텔 예약', '해외여행'],
    conditionalText: '표나 숙소 예약내역을 오프라인에서도 볼 수 있게 저장할까요?',
    embeddingText: '항공권, 승차권, 호텔 예약, 해외여행처럼 이동 중 예약정보를 확인하는 일정. 추천 행동: 표와 예약내역을 오프라인으로 저장하기.',
    category: 'document', actionType: 'save', targetType: 'reservation',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_departure_time', name: '교통편 출발 시각 확인하기',
    description: '교통편의 출발 시각과 탑승 마감시간을 확인한다.',
    examples: ['비행기 시간', '기차 시간', '출발 시각', '탑승 마감'],
    triggerExamples: ['비행기', 'KTX', '고속버스', '배'],
    conditionalText: '교통편의 출발 시각과 탑승 마감시간을 확인할까요?',
    embeddingText: '비행기, KTX, 고속버스, 배처럼 정해진 시각에 출발하는 교통 일정. 추천 행동: 교통편 출발 시각과 탑승 마감시간 확인하기.',
    category: 'check', actionType: 'check', targetType: 'schedule',
    suggestionLevel: 'safe', defaultTiming: '전날 또는 출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_transport_ticket', name: '승차권·항공권 확인하기',
    description: '승차권이나 항공권의 날짜, 좌석과 탑승 정보를 확인한다.',
    examples: ['항공권', '기차표', 'KTX 표', '버스표', '탑승권'],
    triggerExamples: ['비행기', '항공편', 'KTX', '기차', '고속버스'],
    conditionalText: '승차권이나 항공권의 날짜와 좌석을 확인할까요?',
    embeddingText: '비행기, 항공편, KTX, 기차, 고속버스처럼 표가 필요한 교통 일정. 추천 행동: 승차권 또는 항공권의 날짜, 좌석과 탑승 정보 확인하기.',
    category: 'check', actionType: 'check', targetType: 'ticket',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_departure_point', name: '역·터미널·탑승 장소 확인하기',
    description: '정확한 역, 터미널, 탑승구 또는 승차 장소를 확인한다.',
    examples: ['공항 터미널', '탑승구', '기차역', '버스터미널'],
    triggerExamples: ['공항 2터미널', '서울역 KTX', '버스터미널', '탑승구'],
    conditionalText: '정확한 역·터미널과 탑승 장소를 확인할까요?',
    embeddingText: '공항 터미널, 탑승구, 기차역, KTX 승강장, 버스터미널처럼 정확한 출발 장소가 필요한 일정. 추천 행동: 역, 터미널과 탑승 장소 확인하기.',
    category: 'check', actionType: 'check', targetType: 'location',
    suggestionLevel: 'safe', defaultTiming: '전날 또는 출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_baggage_rules', name: '수하물 규정 확인하기',
    description: '항공편의 위탁·기내 수하물 허용량과 반입 규정을 확인한다.',
    examples: ['수하물 무게', '기내 반입', '캐리어 무게', '위탁수하물'],
    triggerExamples: ['비행기', '공항', '위탁수하물', '기내수하물'],
    conditionalText: '항공편을 이용한다면 수하물 허용량을 확인할까요?',
    embeddingText: '비행기, 공항, 위탁수하물, 기내수하물처럼 짐을 가지고 항공편에 탑승하는 일정. 추천 행동: 항공편 수하물 허용량과 반입 규정 확인하기.',
    category: 'check', actionType: 'check', targetType: 'baggage',
    suggestionLevel: 'conditional', defaultTiming: '짐 싸기 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_accommodation_booking', name: '숙소 예약내역 확인하기',
    description: '숙소 예약 날짜, 예약자명과 예약번호를 확인한다.',
    examples: ['호텔 예약', '숙소 예약', '예약자명', '예약번호'],
    triggerExamples: ['호텔', '숙소', '펜션', '에어비앤비'],
    conditionalText: '숙소 예약 날짜와 예약자명을 확인할까요?',
    embeddingText: '호텔, 숙소, 펜션, 에어비앤비처럼 예약한 장소에서 숙박하는 일정. 추천 행동: 숙소 예약 날짜, 예약자명과 예약번호 확인하기.',
    category: 'check', actionType: 'check', targetType: 'reservation',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_checkin_time', name: '숙소 체크인 시간 확인하기',
    description: '숙소 체크인 가능 시간과 늦은 입실 방법을 확인한다.',
    examples: ['체크인 시간', '입실 시간', '늦은 체크인'],
    triggerExamples: ['체크인', '호텔', '펜션 입실'],
    conditionalText: '숙소 체크인 가능 시간을 확인할까요?',
    embeddingText: '호텔 체크인, 숙소 입실, 펜션 입실처럼 정해진 시간 이후 들어가는 숙박 일정. 추천 행동: 숙소 체크인 가능 시간 확인하기.',
    category: 'check', actionType: 'check', targetType: 'schedule',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'save_accommodation_address', name: '숙소 주소와 연락처 저장하기',
    description: '숙소의 정확한 주소와 연락처를 휴대전화에 저장한다.',
    examples: ['호텔 주소', '숙소 위치', '숙소 전화번호'],
    triggerExamples: ['호텔', '숙소', '낯선 여행지'],
    conditionalText: '숙소 주소와 연락처를 저장해둘까요?',
    embeddingText: '호텔, 숙소, 낯선 여행지처럼 처음 찾아가는 숙박 장소. 추천 행동: 숙소의 정확한 주소와 연락처 저장하기.',
    category: 'document', actionType: 'save', targetType: 'location',
    suggestionLevel: 'contextual', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_passport_validity', name: '여권 유효기간 확인하기',
    description: '출국 전에 여권 만료일과 남은 유효기간을 확인한다.',
    examples: ['여권 만료일', '여권 유효기간', '여권 갱신'],
    triggerExamples: ['해외여행', '출국', '국제선'],
    conditionalText: '출국 전에 여권 유효기간을 확인할까요?',
    embeddingText: '해외여행, 해외 출국, 국제선 항공편처럼 유효한 여권이 필요한 일정. 추천 행동: 여권 만료일과 남은 유효기간 확인하기.',
    category: 'check', actionType: 'check', targetType: 'identification',
    suggestionLevel: 'safe', defaultTiming: '여행 결정 직후',
    requiredContexts: ['international_travel'], excludedContexts: ['domestic_travel'],
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'pack_passport', name: '여권 챙기기',
    description: '해외 출국과 입국에 필요한 여권을 챙긴다.',
    examples: ['여권', '패스포트', '출국 준비'],
    triggerExamples: ['해외여행', '출국', '국제선', '인천공항 해외편'],
    conditionalText: '해외 출국에 필요한 여권을 챙길까요?',
    embeddingText: '해외여행, 해외 출국, 국제선, 인천공항 해외편처럼 다른 나라로 가는 일정. 추천 행동: 여권 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'identification',
    suggestionLevel: 'safe', defaultTiming: '출발 전',
    requiredContexts: ['international_travel'], excludedContexts: ['domestic_travel'],
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'prepare_roaming', name: '로밍·유심·eSIM 준비하기',
    description: '해외에서 사용할 통신 방법과 개통 상태를 확인한다.',
    examples: ['로밍', '유심', 'eSIM', '해외 데이터'],
    triggerExamples: ['해외여행', '일본 여행', '유럽 여행'],
    conditionalText: '해외에서 사용할 로밍·유심·eSIM을 확인할까요?',
    embeddingText: '해외여행, 일본 여행, 유럽 여행처럼 해외에서 휴대전화 데이터를 사용하는 일정. 추천 행동: 로밍, 유심 또는 eSIM 준비하기.',
    category: 'check', actionType: 'prepare', targetType: 'connectivity',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    requiredContexts: ['international_travel'], excludedContexts: ['domestic_travel'],
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_power_adapter', name: '여행지 전원 플러그 확인하기',
    description: '여행 국가의 콘센트 규격과 어댑터 필요 여부를 확인한다.',
    examples: ['돼지코', '여행용 어댑터', '멀티어댑터', '콘센트'],
    triggerExamples: ['해외여행', '일본', '유럽', '어댑터'],
    conditionalText: '여행지 콘센트 규격이 다르다면 어댑터를 준비할까요?',
    embeddingText: '해외여행, 일본 여행, 유럽 여행처럼 전원 플러그 규격이 다를 수 있는 일정. 추천 행동: 여행지 콘센트 규격과 어댑터 필요 여부 확인하기.',
    category: 'check', actionType: 'check', targetType: 'power',
    suggestionLevel: 'conditional', defaultTiming: '짐 싸기 전',
    requiredContexts: ['international_travel'], excludedContexts: ['domestic_travel'],
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'prepare_overseas_payment', name: '해외 결제수단 준비하기',
    description: '해외에서 사용할 카드, 필요한 현금과 결제 가능 여부를 확인한다.',
    examples: ['환전', '해외 카드', '현금', '결제수단'],
    triggerExamples: ['해외여행', '환전', '해외카드', '현금'],
    conditionalText: '사용 가능한 카드와 필요한 현금을 확인할까요?',
    embeddingText: '해외여행, 환전, 해외카드, 현금처럼 다른 나라의 결제 환경을 사용하는 일정. 추천 행동: 해외에서 사용할 카드와 필요한 현금 확인하기.',
    category: 'check', actionType: 'prepare', targetType: 'payment',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    requiredContexts: ['international_travel'], excludedContexts: ['domestic_travel'],
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  },
  {
    code: 'check_entry_documents', name: '입국 필요 서류 확인하기',
    description: '공식 출입국 안내에서 목적지 입국에 필요한 서류를 확인한다.',
    examples: ['입국 서류', '출입국 안내', '비자 확인'],
    triggerExamples: ['해외여행', '출국', '입국'],
    conditionalText: '공식 출입국 안내에서 필요한 서류를 확인할까요?',
    embeddingText: '해외여행, 출국, 입국처럼 목적지의 공식 출입국 안내를 확인해야 하는 일정. 추천 행동: 공식 안내에서 입국에 필요한 서류 확인하기. 특정 비자나 요건을 단정하지 않는다.',
    category: 'check', actionType: 'check', targetType: 'entry_document',
    suggestionLevel: 'safe', defaultTiming: '여행 결정 직후',
    requiredContexts: ['international_travel'], excludedContexts: ['domestic_travel'],
    locale: 'ko', seedVersion: '0.1', seedSource: 'travel_v0.1', isActive: true
  }
] AS row
MERGE (r:RecommendationTemplate {code: row.code})
ON CREATE SET r.createdAt = datetime()
SET r += row,
    r.updatedAt = datetime();


// ============================================================
// 6. 기존 공용 추천 4개 확인 (속성 수정 없음)
// 기대 missingSharedCodes = []
// ============================================================

OPTIONAL MATCH (r:RecommendationTemplate)
WHERE r.code IN ['check_travel_time', 'check_transport', 'pack_power_bank', 'pack_water']
WITH collect(r.code) AS foundCodes
RETURN [
  code IN ['check_travel_time', 'check_transport', 'pack_power_bank', 'pack_water']
  WHERE NOT (code IN foundCodes)
] AS missingSharedCodes;


// ============================================================
// 7. Context 기반 추천 12개
// domestic_travel은 분류 및 해외 추천 차단용이며 직접 추천 관계는 없다.
// ============================================================

UNWIND [
  {sourceCode: 'travel', recommendationCode: 'check_travel_dates', defaultRank: 1, suggestionMode: 'safe', reason: '여행 날짜와 기간 확인'},
  {sourceCode: 'travel', recommendationCode: 'check_weather', defaultRank: 4, suggestionMode: 'safe', reason: '짐을 싸기 전 여행지 날씨 확인'},
  {sourceCode: 'travel', recommendationCode: 'charge_phone', defaultRank: 8, suggestionMode: 'contextual', reason: '이동 중 지도와 예약내역 확인'},
  {sourceCode: 'travel', recommendationCode: 'pack_phone_charger', defaultRank: 9, suggestionMode: 'contextual', reason: '여행 중 휴대전화 충전'},
  {sourceCode: 'travel', recommendationCode: 'pack_power_bank', defaultRank: 10, suggestionMode: 'conditional', reason: '장시간 이동 중 배터리 부족 대비'},
  {sourceCode: 'travel', recommendationCode: 'pack_regular_medicine', defaultRank: 11, suggestionMode: 'conditional', reason: '평소 복용약이 있는 경우 대비'},

  {sourceCode: 'international_travel', recommendationCode: 'check_passport_validity', defaultRank: 2, suggestionMode: 'safe', reason: '해외 출국 전 여권 유효기간 확인'},
  {sourceCode: 'international_travel', recommendationCode: 'pack_passport', defaultRank: 3, suggestionMode: 'safe', reason: '해외 출국에 여권 필요'},
  {sourceCode: 'international_travel', recommendationCode: 'check_entry_documents', defaultRank: 5, suggestionMode: 'safe', reason: '공식 출입국 안내 확인'},
  {sourceCode: 'international_travel', recommendationCode: 'prepare_roaming', defaultRank: 6, suggestionMode: 'contextual', reason: '해외 통신 준비'},
  {sourceCode: 'international_travel', recommendationCode: 'prepare_overseas_payment', defaultRank: 7, suggestionMode: 'contextual', reason: '해외 결제수단 준비'},
  {sourceCode: 'international_travel', recommendationCode: 'check_power_adapter', defaultRank: 10, suggestionMode: 'conditional', reason: '여행지 전원 플러그 확인'}
] AS row
MATCH (c:Context {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (c)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = [],
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'travel_v0.1',
    rel.isActive = true;


// ============================================================
// 8. EventType 기반 추천 27개
// 해외 전용 추천은 requiredContexts가 만족될 때만 후보가 된다.
// ============================================================

UNWIND [
  {sourceCode: 'travel_departure', recommendationCode: 'check_travel_dates', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '여행 날짜와 기간 확인'},
  {sourceCode: 'travel_departure', recommendationCode: 'check_weather', defaultRank: 4, requiredContexts: [], suggestionMode: 'safe', reason: '짐을 싸기 전 여행지 날씨 확인'},
  {sourceCode: 'travel_departure', recommendationCode: 'charge_phone', defaultRank: 8, requiredContexts: [], suggestionMode: 'contextual', reason: '출발 전 휴대전화 충전'},
  {sourceCode: 'travel_departure', recommendationCode: 'pack_phone_charger', defaultRank: 9, requiredContexts: [], suggestionMode: 'contextual', reason: '여행 중 휴대전화 충전'},
  {sourceCode: 'travel_departure', recommendationCode: 'pack_power_bank', defaultRank: 10, requiredContexts: [], suggestionMode: 'conditional', reason: '장시간 이동 중 배터리 부족 대비'},
  {sourceCode: 'travel_departure', recommendationCode: 'pack_regular_medicine', defaultRank: 11, requiredContexts: [], suggestionMode: 'conditional', reason: '평소 복용약이 있는 경우 대비'},
  {sourceCode: 'travel_departure', recommendationCode: 'pack_id', defaultRank: 8, requiredContexts: ['domestic_travel'], suggestionMode: 'contextual', reason: '국내 교통편이나 숙소에서 신분 확인 가능'},
  {sourceCode: 'travel_departure', recommendationCode: 'check_passport_validity', defaultRank: 2, requiredContexts: ['international_travel'], suggestionMode: 'safe', reason: '해외 출국 전 여권 유효기간 확인'},
  {sourceCode: 'travel_departure', recommendationCode: 'pack_passport', defaultRank: 3, requiredContexts: ['international_travel'], suggestionMode: 'safe', reason: '해외 출국에 여권 필요'},
  {sourceCode: 'travel_departure', recommendationCode: 'check_entry_documents', defaultRank: 5, requiredContexts: ['international_travel'], suggestionMode: 'safe', reason: '공식 출입국 안내 확인'},
  {sourceCode: 'travel_departure', recommendationCode: 'prepare_roaming', defaultRank: 6, requiredContexts: ['international_travel'], suggestionMode: 'contextual', reason: '해외 통신 준비'},
  {sourceCode: 'travel_departure', recommendationCode: 'prepare_overseas_payment', defaultRank: 7, requiredContexts: ['international_travel'], suggestionMode: 'contextual', reason: '해외 결제수단 준비'},
  {sourceCode: 'travel_departure', recommendationCode: 'check_power_adapter', defaultRank: 10, requiredContexts: ['international_travel'], suggestionMode: 'conditional', reason: '여행지 전원 플러그 확인'},

  {sourceCode: 'transport_departure', recommendationCode: 'check_departure_time', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '교통편 출발 시각과 탑승 마감 확인'},
  {sourceCode: 'transport_departure', recommendationCode: 'check_transport_ticket', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '승차권·항공권 정보 확인'},
  {sourceCode: 'transport_departure', recommendationCode: 'check_departure_point', defaultRank: 3, requiredContexts: [], suggestionMode: 'safe', reason: '정확한 역·터미널과 탑승 장소 확인'},
  {sourceCode: 'transport_departure', recommendationCode: 'check_travel_time', defaultRank: 4, requiredContexts: [], suggestionMode: 'contextual', reason: '출발 장소까지 이동시간 확인'},
  {sourceCode: 'transport_departure', recommendationCode: 'check_transport', defaultRank: 5, requiredContexts: [], suggestionMode: 'conditional', reason: '출발 장소까지 이동 경로 확인'},
  {sourceCode: 'transport_departure', recommendationCode: 'save_reservations_offline', defaultRank: 6, requiredContexts: [], suggestionMode: 'contextual', reason: '표와 예약내역을 오프라인으로 확인'},
  {sourceCode: 'transport_departure', recommendationCode: 'pack_id', defaultRank: 7, requiredContexts: ['domestic_travel'], suggestionMode: 'contextual', reason: '국내 교통편에서 신분 확인 가능'},
  {sourceCode: 'transport_departure', recommendationCode: 'pack_passport', defaultRank: 1, requiredContexts: ['international_travel'], suggestionMode: 'safe', reason: '국제선 탑승에 여권 필요'},
  {sourceCode: 'transport_departure', recommendationCode: 'check_passport_validity', defaultRank: 8, requiredContexts: ['international_travel'], suggestionMode: 'safe', reason: '국제선 탑승 전 여권 유효기간 확인'},

  {sourceCode: 'accommodation_checkin', recommendationCode: 'check_accommodation_booking', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '숙소 예약 날짜와 예약자명 확인'},
  {sourceCode: 'accommodation_checkin', recommendationCode: 'check_checkin_time', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '숙소 체크인 가능 시간 확인'},
  {sourceCode: 'accommodation_checkin', recommendationCode: 'save_accommodation_address', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '숙소 주소와 연락처 저장'},
  {sourceCode: 'accommodation_checkin', recommendationCode: 'save_reservations_offline', defaultRank: 4, requiredContexts: [], suggestionMode: 'contextual', reason: '숙소 예약내역을 오프라인으로 확인'},
  {sourceCode: 'accommodation_checkin', recommendationCode: 'pack_toiletries', defaultRank: 5, requiredContexts: [], suggestionMode: 'conditional', reason: '숙박 시 개인 세면용품 필요 가능'}
] AS row
MATCH (e:EventType {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (e)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = row.requiredContexts,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'travel_v0.1',
    rel.isActive = true;


// ============================================================
// 9. PlaceType 기반 추천 19개
// 공항에는 해외 전용 추천을 직접 연결하지 않는다. 공항은 국내선일 수도 있다.
// ============================================================

UNWIND [
  {sourceCode: 'airport', recommendationCode: 'check_departure_time', defaultRank: 1, requiredContexts: ['travel'], suggestionMode: 'safe', reason: '항공편 출발 시각과 탑승 마감 확인'},
  {sourceCode: 'airport', recommendationCode: 'check_transport_ticket', defaultRank: 2, requiredContexts: ['travel'], suggestionMode: 'safe', reason: '항공권과 탑승 정보 확인'},
  {sourceCode: 'airport', recommendationCode: 'check_departure_point', defaultRank: 3, requiredContexts: ['travel'], suggestionMode: 'safe', reason: '정확한 공항 터미널과 탑승 장소 확인'},
  {sourceCode: 'airport', recommendationCode: 'check_baggage_rules', defaultRank: 4, requiredContexts: ['travel'], suggestionMode: 'conditional', reason: '항공편 수하물 허용량 확인'},
  {sourceCode: 'airport', recommendationCode: 'check_travel_time', defaultRank: 5, requiredContexts: ['travel'], suggestionMode: 'contextual', reason: '공항까지 이동시간 확인'},
  {sourceCode: 'airport', recommendationCode: 'pack_id', defaultRank: 6, requiredContexts: ['domestic_travel'], suggestionMode: 'contextual', reason: '국내선 탑승 시 신분 확인 가능'},

  {sourceCode: 'station_terminal', recommendationCode: 'check_departure_time', defaultRank: 1, requiredContexts: ['travel'], suggestionMode: 'safe', reason: '교통편 출발 시각 확인'},
  {sourceCode: 'station_terminal', recommendationCode: 'check_transport_ticket', defaultRank: 2, requiredContexts: ['travel'], suggestionMode: 'safe', reason: '승차권과 좌석 정보 확인'},
  {sourceCode: 'station_terminal', recommendationCode: 'check_departure_point', defaultRank: 3, requiredContexts: ['travel'], suggestionMode: 'safe', reason: '정확한 역·터미널과 승차 장소 확인'},
  {sourceCode: 'station_terminal', recommendationCode: 'check_travel_time', defaultRank: 4, requiredContexts: ['travel'], suggestionMode: 'contextual', reason: '역·터미널까지 이동시간 확인'},
  {sourceCode: 'station_terminal', recommendationCode: 'check_transport', defaultRank: 5, requiredContexts: ['travel'], suggestionMode: 'conditional', reason: '역·터미널까지 이동 경로 확인'},

  {sourceCode: 'accommodation', recommendationCode: 'check_accommodation_booking', defaultRank: 1, requiredContexts: ['travel'], suggestionMode: 'safe', reason: '숙소 예약내역 확인'},
  {sourceCode: 'accommodation', recommendationCode: 'check_checkin_time', defaultRank: 2, requiredContexts: ['travel'], suggestionMode: 'safe', reason: '숙소 체크인 가능 시간 확인'},
  {sourceCode: 'accommodation', recommendationCode: 'save_accommodation_address', defaultRank: 3, requiredContexts: ['travel'], suggestionMode: 'contextual', reason: '숙소 주소와 연락처 저장'},
  {sourceCode: 'accommodation', recommendationCode: 'pack_toiletries', defaultRank: 4, requiredContexts: ['travel'], suggestionMode: 'conditional', reason: '숙박 시 개인 세면용품 필요 가능'},

  {sourceCode: 'travel_destination', recommendationCode: 'check_weather', defaultRank: 1, requiredContexts: ['travel'], suggestionMode: 'safe', reason: '여행지 날씨 확인'},
  {sourceCode: 'travel_destination', recommendationCode: 'check_travel_time', defaultRank: 2, requiredContexts: ['travel'], suggestionMode: 'contextual', reason: '여행지까지 이동시간 확인'},
  {sourceCode: 'travel_destination', recommendationCode: 'check_transport', defaultRank: 3, requiredContexts: ['travel'], suggestionMode: 'conditional', reason: '여행지 이동 경로와 교통편 확인'},
  {sourceCode: 'travel_destination', recommendationCode: 'pack_water', defaultRank: 4, requiredContexts: ['travel'], suggestionMode: 'conditional', reason: '장시간 이동이나 야외 일정 대비'}
] AS row
MATCH (p:PlaceType {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (p)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = row.requiredContexts,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'travel_v0.1',
    rel.isActive = true;


// ============================================================
// 10. 여행 seed smoke check
// 기대: Context 3, EventType 3, PlaceType 4, RecommendationTemplate 21
//       RECOMMENDS 58, IS_A 2, invalid* 0
// ============================================================

MATCH (n {seedSource: 'travel_v0.1'})
RETURN labels(n)[0] AS label, count(*) AS nodeCount
ORDER BY label;

MATCH ()-[rel:RECOMMENDS {seedSource: 'travel_v0.1'}]->()
RETURN
  count(rel) AS recommendsCount,
  sum(CASE
    WHEN rel.defaultRank IS NULL
      OR rel.suggestionMode IS NULL
      OR rel.requiredContexts IS NULL
    THEN 1 ELSE 0
  END) AS invalidRelationshipCount;

MATCH ()-[rel:IS_A {seedSource: 'travel_v0.1'}]->()
RETURN count(rel) AS contextHierarchyCount;

MATCH (r:RecommendationTemplate {seedSource: 'travel_v0.1'})
RETURN
  count(r) AS travelRecommendationCount,
  sum(CASE
    WHEN r.embeddingText IS NULL
      OR r.conditionalText IS NULL
      OR r.suggestionLevel IS NULL
    THEN 1 ELSE 0
  END) AS invalidRecommendationCount;
