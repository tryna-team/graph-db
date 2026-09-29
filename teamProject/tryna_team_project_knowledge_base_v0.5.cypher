// Tryna 팀프로젝트 지식베이스 v0.5 (MVP seed)
//
// 목표:
// - 짧은 캘린더 입력(예: "팀플", "온라인 팀플", "가천대 팀플")에서도
//   일반적이고 사소한 할 일/준비물 후보를 찾을 수 있게 한다.
// - Kiwi/Rule Parser는 날짜, 시간, 반복처럼 명확한 정보만 추출한다.
// - 행동 예측은 파서가 아니라 Neo4j의 지식과 벡터 유사도 검색이 담당한다.
// - 사람 이름처럼 맥락이 없는 입력에는 추천이 없을 수 있다.
//
// 이 파일은 제약조건과 seed 데이터만 포함하므로 파라미터 없이 재실행할 수 있다.
// 실제 embedding 벡터 적재, vector index 생성, 런타임 조회는 별도 파일을 사용한다.


// ============================================================
// 1. 고유 제약조건
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
// 2. Context / EventType
// ============================================================

UNWIND [
  {
    code: 'team_project',
    name: '팀 프로젝트',
    description: '여러 사람이 하나의 과제, 프로젝트 또는 결과물을 함께 준비하는 활동 맥락',
    examples: [
      '팀플', '조별 과제', '팀 과제', '캡스톤',
      '공모전 팀', '해커톤 팀', '사이드 프로젝트'
    ],
    exclusionExamples: [
      '개인 공부', '그룹 스터디', '시험 공부', '수업 듣기', '친구 약속',
      '취업 면접', '첫 출근', '거래처 미팅', '고객사 방문'
    ],
    embeddingText: '팀 프로젝트, 팀플, 조별 과제, 팀 과제, 캡스톤, 공모전 팀, 해커톤 팀, 사이드 프로젝트. 여러 사람이 하나의 과제나 결과물을 함께 준비하고 작업하는 일정 맥락.',
    locale: 'ko',
    seedVersion: '0.5',
    isActive: true
  }
] AS row
MERGE (c:Context {code: row.code})
ON CREATE SET c.createdAt = datetime()
SET c += row,
    c.updatedAt = datetime();

UNWIND [
  {
    code: 'meeting',
    name: '회의',
    description: '여러 사람이 만나거나 온라인으로 접속해 내용을 공유하고 이야기하는 일정',
    examples: [
      '회의', '미팅', '팀플', '팀플 회의', '팀 미팅',
      '프로젝트 위클리', '중간 점검', '온라인 회의',
      '회사 회의', '주간회의', '팀장님과 1:1'
    ],
    exclusionExamples: [
      '온라인 강의', '학교 수업', '그룹 스터디', '시험 응시',
      '취업 면접', '첫 출근', '거래처 미팅', '고객사 방문', '외부 미팅'
    ],
    embeddingText: '회의, 미팅, 팀플 회의, 프로젝트 위클리, 중간 점검, 온라인 회의, 회사 회의, 주간회의, 팀장님과 1:1. 여러 사람이 만나거나 온라인으로 접속해 업무 또는 프로젝트 내용을 공유하고 논의하는 일정.',
    locale: 'ko',
    seedVersion: '0.5',
    isActive: true
  },
  {
    code: 'assignment',
    name: '과제·제출',
    description: '정해진 기한까지 문서, 파일 또는 결과물을 완성해 제출하는 일정',
    examples: [
      '과제 제출', '개인 과제', '레포트 마감', '팀플 제출',
      '최종 제출', '보고서 제출', '결과물 제출', '공모전 제출'
    ],
    exclusionExamples: ['시험 공부', '중간고사', '수업 듣기'],
    embeddingText: '과제 제출, 개인 과제, 레포트 마감, 팀플 제출, 최종 제출, 보고서 제출, 결과물 제출, 공모전 제출. 정해진 날짜와 시간까지 문서, 파일 또는 결과물을 완성해 제출하는 일정.',
    locale: 'ko',
    seedVersion: '0.5',
    isActive: true
  }
] AS row
MERGE (e:EventType {code: row.code})
ON CREATE SET e.createdAt = datetime()
SET e += row,
    e.updatedAt = datetime();


// ============================================================
// 3. PlaceType
// 장소를 반드시 분류하지 않는다. 확신도가 낮으면 $placeType은 null로 둔다.
// ============================================================

UNWIND [
  {
    code: 'online',
    name: '온라인',
    attendanceMode: 'online',
    description: '물리적 이동 없이 화상회의나 음성 채널로 접속하는 장소 유형',
    examples: [
      '온라인', '줌', 'Zoom', '구글밋',
      'Google Meet', '디스코드', 'Discord', '팀즈'
    ],
    embeddingText: '온라인 일정, 온라인 회의, 줌, Zoom, 구글밋, Google Meet, 디스코드, Discord, 팀즈. 물리적 이동 없이 링크나 채널을 통해 접속하는 일정.',
    locale: 'ko',
    seedVersion: '0.5',
    isActive: true
  },
  {
    code: 'school',
    name: '학교',
    attendanceMode: 'offline',
    description: '대학교, 캠퍼스, 강의실, 학과 건물 또는 교내 시설',
    examples: [
      '학교', '대학교', '캠퍼스', '강의실',
      '세미나실', '학과실', '과방', '가천대', 'AI관'
    ],
    embeddingText: '학교 일정, 대학교, 캠퍼스, 강의실, 세미나실, 학과실, 과방, 가천대, AI관. 학교나 교내 건물로 직접 이동해 참여하는 일정.',
    locale: 'ko',
    seedVersion: '0.5',
    isActive: true
  },
  {
    code: 'cafe',
    name: '카페',
    attendanceMode: 'offline',
    description: '음료를 마시며 대화하거나 노트북으로 작업하는 카페 공간',
    examples: [
      '카페', '커피숍', '스터디 카페',
      '스타벅스', '투썸', '메가커피'
    ],
    embeddingText: '카페 일정, 커피숍, 스터디 카페, 스타벅스, 투썸, 메가커피. 카페에서 만나 대화하거나 노트북으로 작업하는 일정.',
    locale: 'ko',
    seedVersion: '0.5',
    isActive: true
  },
  {
    code: 'library',
    name: '도서관·스터디룸',
    attendanceMode: 'offline',
    description: '도서관, 그룹 학습실, 스터디룸 또는 조용한 학습 공간',
    examples: [
      '도서관', '스터디룸', '그룹 학습실',
      '열람실', '학교 도서관'
    ],
    embeddingText: '도서관 일정, 스터디룸, 그룹 학습실, 열람실, 학교 도서관. 조용한 학습 공간이나 그룹 학습실에서 공부하고 작업하는 일정.',
    locale: 'ko',
    seedVersion: '0.5',
    isActive: true
  }
] AS row
MERGE (p:PlaceType {code: row.code})
ON CREATE SET p.createdAt = datetime()
SET p += row,
    p.updatedAt = datetime();


// ============================================================
// 4. RecommendationTemplate
// embeddingText는 출력 문구만이 아니라 추천이 필요한 입력 상황을 중심으로 작성한다.
// suggestionLevel:
// - safe: 정보가 적어도 비교적 안전하게 제안 가능
// - contextual: 맥락상 가능성이 높을 때 조건부 표현으로 제안
// - conditional: 장시간/외출 등 강한 단서가 있을 때만 제안
// ============================================================

UNWIND [
  {
    code: 'check_meeting_time',
    name: '회의 시간 다시 확인하기',
    description: '팀플 회의의 날짜와 시작 시간을 다시 확인한다.',
    examples: ['회의 시간 확인', '몇 시에 만나지', '날짜 다시 보기'],
    triggerExamples: ['팀플', '회의', '미팅', '팀플 회의', '내일 팀플', '조별과제 회의'],
    conditionalText: '회의 날짜와 시작 시간을 다시 확인할까요?',
    embeddingText: '팀플, 회의, 미팅, 팀플 회의, 내일 팀플, 조별과제 회의처럼 사람들과 만나는 일정. 추천 행동: 회의 날짜와 시작 시간을 다시 확인하기.',
    category: 'check', actionType: 'check', targetType: 'schedule',
    suggestionLevel: 'safe', defaultTiming: '일정 확정 직후 또는 전날',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'note_discussion_points',
    name: '이야기할 내용 간단히 메모하기',
    description: '회의에서 물어보거나 확인할 내용을 짧게 적어둔다.',
    examples: ['회의에서 말할 것', '질문 메모', '논의할 내용'],
    triggerExamples: ['회의', '팀플 회의', '프로젝트 미팅', '중간 점검', '발표 논의'],
    conditionalText: '회의에서 이야기할 내용을 간단히 메모해둘까요?',
    embeddingText: '회의, 팀플 회의, 프로젝트 미팅, 중간 점검, 발표 논의처럼 여러 사람이 내용을 공유하고 결정하는 일정. 추천 행동: 질문이나 논의할 내용을 간단히 메모하기.',
    category: 'pre_task', actionType: 'note', targetType: 'discussion',
    suggestionLevel: 'safe', defaultTiming: '회의 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'check_latest_work',
    name: '최근 작업한 내용 한번 확인하기',
    description: '회의 전에 현재 작업물과 마지막 수정 내용을 확인한다.',
    examples: ['작업물 확인', '최근 수정본 보기', '진행 내용 확인'],
    triggerExamples: ['팀플', '조별과제', '프로젝트 회의', '캡스톤', '작업 점검'],
    conditionalText: '최근 작업한 내용과 진행 상황을 한번 확인할까요?',
    embeddingText: '팀플, 조별과제, 프로젝트 회의, 캡스톤, 작업 점검처럼 진행 중인 결과물을 함께 다루는 일정. 추천 행동: 최근 작업물과 마지막 수정 내용을 확인하기.',
    category: 'check', actionType: 'check', targetType: 'work',
    suggestionLevel: 'safe', defaultTiming: '일정 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'check_needed_files',
    name: '필요한 파일이 열리는지 확인하기',
    description: '회의에서 사용할 문서, 링크 또는 작업 파일이 정상적으로 열리는지 확인한다.',
    examples: ['파일 확인', '자료 열어보기', '공유 문서 확인'],
    triggerExamples: ['팀플', '발표 준비', '프로젝트 회의', '자료 공유', '파일 제출'],
    conditionalText: '사용할 파일과 공유 문서가 열리는지 확인할까요?',
    embeddingText: '팀플, 발표 준비, 프로젝트 회의, 자료 공유, 파일 제출처럼 문서와 작업 파일을 사용하는 일정. 추천 행동: 필요한 파일, 링크, 공유 문서가 정상적으로 열리는지 확인하기.',
    category: 'document', actionType: 'check', targetType: 'document',
    suggestionLevel: 'safe', defaultTiming: '일정 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'check_location',
    name: '정확한 장소 다시 확인하기',
    description: '건물, 층, 강의실, 매장 또는 방문 장소의 정확한 위치를 확인한다.',
    examples: ['장소 확인', '건물 확인', '강의실 확인', '매장 위치', '회사 위치'],
    triggerExamples: ['가천대', 'AI관', '성수', '카페에서 만나기', '처음 가는 장소', '회사 면접', '고객사 방문'],
    conditionalText: '정확한 건물과 방문 장소를 다시 확인할까요?',
    embeddingText: '학교, 강의실, 카페, 회사, 면접 장소, 고객사, 처음 가는 건물처럼 물리적인 장소가 포함된 일정. 추천 행동: 건물, 층, 강의실, 매장 또는 방문 위치를 다시 확인하기.',
    category: 'check', actionType: 'check', targetType: 'location',
    suggestionLevel: 'safe', defaultTiming: '전날 또는 출발 전',
    excludedPlaceTypes: ['online'],
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'check_travel_time',
    name: '이동시간 확인하기',
    description: '목적지까지 걸리는 시간을 확인해 출발 시점을 정한다.',
    examples: ['이동시간', '몇 시에 출발', '길찾기', '처음 가는 장소'],
    triggerExamples: ['멀리서 만나기', '처음 가는 곳', '학교에서 약속', '성수에서 만나기', '외부 일정'],
    conditionalText: '이동이 필요한 일정이라면 걸리는 시간을 확인할까요?',
    embeddingText: '멀리서 만나는 일정, 처음 가는 곳, 학교나 성수 같은 외부 장소, 이동이 필요한 약속. 추천 행동: 목적지까지 걸리는 시간과 출발 시점을 확인하기.',
    category: 'check', actionType: 'check', targetType: 'travel',
    suggestionLevel: 'contextual', defaultTiming: '전날 또는 출발 전',
    excludedPlaceTypes: ['online'],
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'check_transport',
    name: '교통편과 경로 확인하기',
    description: '지하철, 버스, 도보 등 이동 경로를 확인한다.',
    examples: ['교통편 확인', '버스 확인', '지하철 경로', '환승 확인'],
    triggerExamples: ['먼 곳에서 약속', '처음 가는 장소', '외부 미팅', '학교 방문', '장거리 이동'],
    conditionalText: '이동이 필요하다면 교통편과 경로를 확인할까요?',
    embeddingText: '먼 곳에서 하는 약속, 처음 가는 장소, 외부 미팅, 학교 방문, 장거리 이동처럼 교통편이 필요한 일정. 추천 행동: 지하철, 버스, 도보와 환승 경로를 확인하기.',
    category: 'check', actionType: 'check', targetType: 'travel',
    suggestionLevel: 'conditional', defaultTiming: '전날',
    excludedPlaceTypes: ['online'],
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'pack_laptop',
    name: '노트북 챙기기',
    description: '팀플 회의나 작업에서 노트북을 사용할 경우 기기를 챙긴다.',
    examples: ['노트북 가져가기', '랩탑 필요', '컴퓨터로 작업'],
    triggerExamples: ['팀플', '조별과제', '프로젝트 회의', '학교에서 팀플', '카페에서 작업', '코딩 회의'],
    conditionalText: '노트북을 사용할 예정이라면 챙겨둘까요?',
    embeddingText: '팀플, 조별과제, 프로젝트 회의, 학교에서 하는 팀플, 카페에서 하는 작업, 코딩 회의처럼 노트북을 사용할 가능성이 있는 일정. 추천 행동: 노트북 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'device',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'charge_laptop',
    name: '노트북 미리 충전하기',
    description: '외부에서 오래 노트북을 사용할 수 있도록 미리 충전한다.',
    examples: ['노트북 충전', '배터리 채우기', '미리 충전'],
    triggerExamples: ['오래 팀플', '장시간 프로젝트 작업', '하루 종일 학교', '카페에서 오래 작업', '노트북으로 장시간 과제'],
    conditionalText: '노트북을 오래 사용할 예정이라면 미리 충전해둘까요?',
    embeddingText: '오래 진행하는 팀플, 장시간 프로젝트 작업, 하루 종일 학교에 있는 일정, 카페에서 오래 하는 작업, 노트북으로 장시간 과제처럼 배터리가 필요한 일정. 추천 행동: 노트북 미리 충전하기.',
    category: 'item', actionType: 'charge', targetType: 'device',
    suggestionLevel: 'conditional', defaultTiming: '전날 밤',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'pack_laptop_charger',
    name: '노트북 충전기 챙기기',
    description: '오래 작업하거나 외부에서 노트북을 사용할 때 충전기를 챙긴다.',
    examples: ['노트북 충전기', '오래 작업', '배터리 부족', '장시간 팀플'],
    triggerExamples: ['오래 팀플', '장시간 외부 작업', '하루 종일 학교', '카페에서 오래 작업', '노트북으로 프로젝트'],
    conditionalText: '외부에서 오래 작업한다면 노트북 충전기를 챙길까요?',
    embeddingText: '오래 진행하는 팀플, 장시간 외부 작업, 하루 종일 학교에 있는 일정, 카페에서 오래 하는 작업, 노트북으로 프로젝트를 하는 일정. 추천 행동: 노트북 충전기 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'device_accessory',
    suggestionLevel: 'conditional', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'pack_power_bank',
    name: '보조배터리 챙기기',
    description: '외출 시간이 길거나 충전하기 어려운 장소에 갈 때 보조배터리를 챙긴다.',
    examples: ['보조배터리', '하루 종일 외출', '오래 밖에 있음'],
    triggerExamples: ['하루 종일 외출', '장시간 밖에서 작업', '먼 곳에서 약속', '충전하기 어려운 장소', '오래 팀플'],
    conditionalText: '외출 시간이 길다면 보조배터리를 챙길까요?',
    embeddingText: '하루 종일 외출, 장시간 밖에서 하는 작업, 먼 곳에서 하는 약속, 충전하기 어려운 장소, 오래 진행하는 팀플. 추천 행동: 보조배터리 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'device_accessory',
    suggestionLevel: 'conditional', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'pack_water',
    name: '마실 물 챙기기',
    description: '오랜 외출이나 긴 회의 중 마실 수 있도록 물을 챙긴다.',
    examples: ['물 챙기기', '오래 외출', '긴 회의'],
    triggerExamples: ['긴 회의', '오래 팀플', '하루 종일 외출', '장시간 학교', '야외 일정'],
    conditionalText: '오래 밖에 있을 예정이라면 마실 물을 챙길까요?',
    embeddingText: '긴 회의, 오래 진행하는 팀플, 하루 종일 외출, 장시간 학교에 있는 일정, 야외 일정. 추천 행동: 마실 물 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'item',
    suggestionLevel: 'conditional', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'check_online_link',
    name: '온라인 일정 접속 링크 확인하기',
    description: '온라인 회의, 강의 또는 면접이 시작되기 전에 접속 링크나 채널을 확인한다.',
    examples: ['줌 링크', '디스코드 채널', '구글밋 링크', '온라인 면접 링크'],
    triggerExamples: ['온라인 팀플', '줌 회의', '온라인 강의', '화상 면접', '온라인 미팅'],
    conditionalText: '온라인 일정의 접속 링크나 채널을 확인할까요?',
    embeddingText: '온라인 팀플, 줌 회의, 온라인 강의, 구글밋, 화상 면접처럼 링크나 채널로 접속하는 일정. 추천 행동: 온라인 일정의 접속 링크와 채널 확인하기.',
    category: 'check', actionType: 'check', targetType: 'connection',
    suggestionLevel: 'safe', defaultTiming: '시작 10분 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'check_microphone',
    name: '카메라·마이크·이어폰 확인하기',
    description: '온라인 회의, 강의 또는 면접에서 영상과 소리가 정상적으로 작동하는지 확인한다.',
    examples: ['카메라 확인', '마이크 확인', '이어폰 확인', '화상 테스트'],
    triggerExamples: ['온라인 팀플', '줌 회의', '온라인 강의', '화상 면접', '온라인 발표'],
    conditionalText: '카메라와 마이크, 이어폰이 잘 작동하는지 확인할까요?',
    embeddingText: '온라인 팀플, 줌 회의, 온라인 강의, 화상 면접, 온라인 발표처럼 영상과 음성을 사용하는 일정. 추천 행동: 카메라, 마이크와 이어폰 작동 확인하기.',
    category: 'check', actionType: 'check', targetType: 'device',
    suggestionLevel: 'safe', defaultTiming: '시작 10분 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'check_deadline',
    name: '정확한 제출 마감시간 확인하기',
    description: '제출 날짜뿐 아니라 몇 시까지 제출해야 하는지 확인한다.',
    examples: ['마감시간', '자정까지', '몇 시 제출', '제출 기한'],
    triggerExamples: ['팀플 제출', '과제 마감', '최종 제출', '보고서 제출', '공모전 제출'],
    conditionalText: '정확히 몇 시까지 제출해야 하는지 확인할까요?',
    embeddingText: '팀플 제출, 과제 마감, 최종 제출, 보고서 제출, 공모전 제출처럼 기한이 있는 일정. 추천 행동: 제출 날짜와 정확한 마감시간 확인하기.',
    category: 'check', actionType: 'check', targetType: 'deadline',
    suggestionLevel: 'safe', defaultTiming: '제출 전날',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'check_submission_location',
    name: '어디에 제출하는지 확인하기',
    description: 'LMS, 이메일, 폼 또는 사이트 등 실제 제출 위치를 확인한다.',
    examples: ['LMS 제출', '이메일 제출', '구글폼 제출', '제출 위치'],
    triggerExamples: ['팀플 제출', '과제 제출', '보고서 제출', '공모전 제출', '최종 파일 제출'],
    conditionalText: '어디에 제출해야 하는지 확인할까요?',
    embeddingText: '팀플 제출, 과제 제출, 보고서 제출, 공모전 제출, 최종 파일 제출처럼 결과물을 보내야 하는 일정. 추천 행동: LMS, 이메일, 폼 또는 사이트 등 제출 위치 확인하기.',
    category: 'check', actionType: 'check', targetType: 'submission',
    suggestionLevel: 'safe', defaultTiming: '제출 전날',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'open_final_file',
    name: '최종 파일이 열리는지 확인하기',
    description: '제출할 파일이 손상되지 않았고 정상적으로 보이는지 확인한다.',
    examples: ['최종 파일 확인', '파일 열어보기', '제출본 확인'],
    triggerExamples: ['최종 제출', '팀플 제출', '보고서 제출', '발표자료 제출', '공모전 제출'],
    conditionalText: '최종 파일이 정상적으로 열리는지 확인할까요?',
    embeddingText: '최종 제출, 팀플 제출, 보고서 제출, 발표자료 제출, 공모전 제출처럼 파일을 제출하는 일정. 추천 행동: 제출할 최종 파일이 손상되지 않고 정상적으로 열리는지 확인하기.',
    category: 'check', actionType: 'check', targetType: 'document',
    suggestionLevel: 'safe', defaultTiming: '제출 직전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  },
  {
    code: 'save_final_backup',
    name: '최종 파일을 다른 곳에도 저장하기',
    description: '휴대전화, 클라우드 또는 다른 저장 공간에 최종 파일 사본을 보관한다.',
    examples: ['백업', '클라우드 저장', '휴대폰에 파일', '사본 저장'],
    triggerExamples: ['최종 제출', '팀플 제출', '보고서 마감', '공모전 제출', '발표자료 완성'],
    conditionalText: '최종 파일을 다른 곳에도 백업할까요?',
    embeddingText: '최종 제출, 팀플 제출, 보고서 마감, 공모전 제출, 발표자료 완성처럼 중요한 결과물을 마무리하는 일정. 추천 행동: 최종 파일 사본을 클라우드나 다른 저장 공간에 백업하기.',
    category: 'document', actionType: 'backup', targetType: 'document',
    suggestionLevel: 'safe', defaultTiming: '제출 전',
    locale: 'ko', seedVersion: '0.5', isActive: true
  }
] AS row
MERGE (r:RecommendationTemplate {code: row.code})
ON CREATE SET r.createdAt = datetime()
SET r += row,
    r.updatedAt = datetime();


// ============================================================
// 5. Context 기반 일반 추천
// "팀플"처럼 EventType이 불명확해도 낮은 위험의 후보를 제공한다.
// ============================================================

UNWIND [
  {
    sourceCode: 'team_project', recommendationCode: 'check_latest_work',
    defaultRank: 1, suggestionMode: 'safe',
    reason: '팀 프로젝트에서는 최근 작업 상태 확인이 일반적으로 유용함'
  },
  {
    sourceCode: 'team_project', recommendationCode: 'check_needed_files',
    defaultRank: 2, suggestionMode: 'safe',
    reason: '팀 프로젝트에서는 공유 문서와 작업 파일을 사용할 가능성이 높음'
  },
  {
    sourceCode: 'team_project', recommendationCode: 'pack_laptop',
    defaultRank: 3, suggestionMode: 'contextual',
    reason: '팀 프로젝트에서 노트북을 사용할 가능성이 있음'
  }
] AS row
MATCH (c:Context {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (c)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.isActive = true,
    rel.seedVersion = '0.5';


// ============================================================
// 6. EventType 기반 기본 추천
// ============================================================

UNWIND [
  {
    sourceCode: 'meeting', recommendationCode: 'check_meeting_time',
    defaultRank: 1, requiredContexts: [], suggestionMode: 'safe',
    reason: '회의의 날짜와 시작 시간 확인'
  },
  {
    sourceCode: 'meeting', recommendationCode: 'note_discussion_points',
    defaultRank: 2, requiredContexts: [], suggestionMode: 'safe',
    reason: '회의 전에 질문과 논의 내용을 준비'
  },
  {
    sourceCode: 'meeting', recommendationCode: 'check_latest_work',
    defaultRank: 3, requiredContexts: ['team_project'], suggestionMode: 'safe',
    reason: '회의 전에 최근 작업 상태 확인'
  },
  {
    sourceCode: 'meeting', recommendationCode: 'check_needed_files',
    defaultRank: 4, requiredContexts: [], suggestionMode: 'safe',
    reason: '회의에서 사용할 파일과 링크 확인'
  },
  {
    sourceCode: 'meeting', recommendationCode: 'pack_laptop',
    defaultRank: 5, requiredContexts: ['team_project'], suggestionMode: 'contextual',
    reason: '팀 프로젝트 회의에서 노트북을 사용할 가능성이 있음'
  },
  {
    sourceCode: 'assignment', recommendationCode: 'check_deadline',
    defaultRank: 1, requiredContexts: [], suggestionMode: 'safe',
    reason: '제출 일정의 정확한 마감시간 확인'
  },
  {
    sourceCode: 'assignment', recommendationCode: 'check_submission_location',
    defaultRank: 2, requiredContexts: [], suggestionMode: 'safe',
    reason: '실제 제출 위치 확인'
  },
  {
    sourceCode: 'assignment', recommendationCode: 'open_final_file',
    defaultRank: 3, requiredContexts: [], suggestionMode: 'safe',
    reason: '제출할 최종 파일 검증'
  },
  {
    sourceCode: 'assignment', recommendationCode: 'save_final_backup',
    defaultRank: 4, requiredContexts: [], suggestionMode: 'safe',
    reason: '중요한 최종 파일의 사본 보관'
  }
] AS row
MATCH (e:EventType {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (e)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = row.requiredContexts,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.isActive = true,
    rel.seedVersion = '0.5';


// ============================================================
// 7. PlaceType 기반 기본 추천
// ============================================================

UNWIND [
  {
    sourceCode: 'online', recommendationCode: 'check_online_link',
    defaultRank: 1, suggestionMode: 'safe',
    reason: '온라인 일정은 접속 링크나 채널 확인이 필요함'
  },
  {
    sourceCode: 'online', recommendationCode: 'check_microphone',
    defaultRank: 2, suggestionMode: 'safe',
    reason: '온라인 일정은 마이크와 이어폰을 사용할 가능성이 높음'
  }
] AS row
MATCH (p:PlaceType {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (p)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.isActive = true,
    rel.seedVersion = '0.5';

UNWIND ['school', 'cafe', 'library'] AS sourceCode
UNWIND [
  {
    recommendationCode: 'check_location', defaultRank: 1,
    suggestionMode: 'safe', reason: '물리적 장소가 있는 일정은 정확한 위치 확인이 유용함'
  },
  {
    recommendationCode: 'check_travel_time', defaultRank: 2,
    suggestionMode: 'contextual', reason: '물리적 장소로 이동하는 일정'
  },
  {
    recommendationCode: 'check_transport', defaultRank: 3,
    suggestionMode: 'conditional', reason: '이동 경로와 교통편이 필요할 수 있음'
  }
] AS row
MATCH (p:PlaceType {code: sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (p)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.isActive = true,
    rel.seedVersion = '0.5';


// ============================================================
// 8. Seed 결과 확인
// 이 조회는 파라미터가 없으며 seed 실행 후 개수만 확인한다.
// ============================================================

MATCH (n)
WHERE n:EventType
   OR n:Context
   OR n:PlaceType
   OR n:RecommendationTemplate
RETURN labels(n)[0] AS label, count(*) AS nodeCount
ORDER BY label;
