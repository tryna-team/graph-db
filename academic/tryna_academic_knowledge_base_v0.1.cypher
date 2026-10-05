// Tryna 학교·학업·스터디 지식베이스 v0.1
//
// 전제:
// - teamProject v0.5, travel v0.1, hangout v0.1 뒤에 추가 실행한다.
// - 기존 PlaceType과 RecommendationTemplate은 MATCH로만 재사용한다.
// - Neo4j Query에서 statement 단위로 위에서부터 실행한다.
//
// 범위:
// - 개인 공부, 그룹 스터디, 수업·강의, 시험, 개인·팀 과제 제출
//
// 제외:
// - 학교·도서관·카페 등 장소명만으로 학업 목적 추론
// - 성적·합격 가능성 예측
// - 학습 내용 자체의 자동 생성


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
// 2. 기존 분류 노드의 Academic 호환 migration
// 팀 과제와 개인 과제에 같은 EventType을 사용해 임베딩 중복 경쟁을 피한다.
// 기존 seed를 재실행하지 않아도 교차 카테고리 제외 예시를 함께 보강한다.
// ============================================================

MATCH (e:EventType {code: 'assignment'})
SET e.description = '정해진 기한까지 문서, 파일 또는 결과물을 완성해 제출하는 일정',
    e.examples = [
      '과제 제출', '개인 과제', '레포트 마감', '팀플 제출',
      '최종 제출', '보고서 제출', '결과물 제출', '공모전 제출'
    ],
    e.exclusionExamples = ['시험 공부', '중간고사', '수업 듣기'],
    e.embeddingText = '과제 제출, 개인 과제, 레포트 마감, 팀플 제출, 최종 제출, 보고서 제출, 결과물 제출, 공모전 제출. 정해진 날짜와 시간까지 문서, 파일 또는 결과물을 완성해 제출하는 일정.',
    e.academicCompatibilityVersion = '0.1',
    e.updatedAt = datetime()
RETURN e.code AS updatedEventType;

MATCH (:EventType {code: 'assignment'})-[rel:RECOMMENDS]->(r:RecommendationTemplate)
WHERE r.code IN [
  'check_deadline',
  'check_submission_location',
  'open_final_file',
  'save_final_backup'
]
SET rel.requiredContexts = [],
    rel.academicCompatibilityVersion = '0.1',
    rel.updatedAt = datetime()
RETURN count(rel) AS generalizedAssignmentRelationshipCount;

UNWIND [
  {
    code: 'team_project',
    exclusionExamples: [
      '개인 공부', '그룹 스터디', '시험 공부', '수업 듣기', '친구 약속',
      '취업 면접', '첫 출근', '거래처 미팅', '고객사 방문'
    ]
  },
  {
    code: 'travel',
    exclusionExamples: [
      '일본어 공부', '여행 계획 회의', '호텔 결혼식', '공항 마중',
      '고객사 방문', '다른 지점 출근'
    ]
  },
  {
    code: 'international_travel',
    exclusionExamples: ['일본어 공부', '일본 음식점', '인천공항 친구 마중', '공항 픽업']
  },
  {
    code: 'hangout',
    exclusionExamples: [
      '민수', '지수', '성수', '가천대',
      '업무 미팅', '팀플 회의', '병원 예약', '상담 약속',
      '호텔 결혼식', '회사 회식',
      '카페 공부', '스터디 모임', '온라인 강의',
      '취업 면접', '첫 출근', '거래처 미팅', '고객사 방문'
    ]
  }
] AS row
MATCH (c:Context {code: row.code})
SET c.exclusionExamples = row.exclusionExamples,
    c.academicCompatibilityVersion = '0.1',
    c.updatedAt = datetime()
RETURN count(c) AS updatedContextExclusionCount;

UNWIND [
  {
    code: 'meeting',
    exclusionExamples: [
      '온라인 강의', '학교 수업', '그룹 스터디', '시험 응시',
      '취업 면접', '첫 출근', '거래처 미팅', '고객사 방문', '외부 미팅'
    ]
  },
  {
    code: 'travel_departure',
    exclusionExamples: ['여행 계획 회의', '여행 사진 정리', '일본어 공부']
  },
  {
    code: 'social_meetup',
    exclusionExamples: [
      '업무 미팅', '팀플 회의', '상담 약속', '병원 예약',
      '호텔 결혼식', '회사 회식', '그룹 스터디', '스터디 모임', '학교 수업',
      '취업 면접', '첫 출근', '거래처 미팅', '고객사 방문'
    ]
  },
  {
    code: 'dining_meetup',
    exclusionExamples: [
      '혼밥', '배달 주문', '장보기', '식단 기록',
      '카페 공부', '스터디카페', '카페 작업', '혼자 공부'
    ]
  }
] AS row
MATCH (e:EventType {code: row.code})
SET e.exclusionExamples = row.exclusionExamples,
    e.academicCompatibilityVersion = '0.1',
    e.updatedAt = datetime()
RETURN count(e) AS updatedEventTypeExclusionCount;

MATCH (r:RecommendationTemplate {code: 'pack_id'})
SET r.name = '신분증 챙기기',
    r.description = '국내선, 숙소 또는 렌터카에서 신분 확인에 쓸 신분증을 챙긴다.',
    r.examples = ['신분증', '주민등록증', '운전면허증'],
    r.triggerExamples = ['국내선', 'KTX', '숙소', '렌터카'],
    r.conditionalText = '신분 확인이 필요한 교통편이라면 신분증을 챙길까요?',
    r.embeddingText = '국내선 탑승, KTX 이용, 숙소 체크인, 렌터카 이용처럼 신분 확인이 있을 수 있는 일정. 추천 행동: 신분증 챙기기.',
    r.updatedAt = datetime()
REMOVE r.academicCompatibilityVersion
RETURN count(r) AS resetSharedRecommendationCount;

// 이전 Academic 초안이 이미 실행된 DB에서 과추천 관계를 정리한다.
MATCH ()-[rel:RECOMMENDS {seedSource: 'academic_v0.1'}]->(r:RecommendationTemplate)
WHERE r.code IN ['pack_id', 'check_calculator_battery', 'pack_water']
WITH collect(rel) AS obsoleteRelationships, count(rel) AS removedCount
FOREACH (obsoleteRelationship IN obsoleteRelationships | DELETE obsoleteRelationship)
RETURN removedCount AS removedObsoleteRelationshipCount;

MATCH (r:RecommendationTemplate {code: 'check_calculator_battery', seedSource: 'academic_v0.1'})
WHERE NOT (r)--()
WITH collect(r) AS obsoleteNodes, count(r) AS removedCount
FOREACH (obsoleteNode IN obsoleteNodes | DELETE obsoleteNode)
RETURN removedCount AS removedObsoleteRecommendationCount;

// 이전 Academic 초안의 범용·중복 추천 관계를 정리한다.
MATCH (source)-[rel:RECOMMENDS {seedSource: 'academic_v0.1'}]->(r:RecommendationTemplate)
WHERE (source:Context AND source.code = 'academic' AND r.code IN [
    'prepare_study_materials', 'set_study_goal', 'review_previous_study'
  ])
  OR (source:EventType AND source.code = 'group_study' AND r.code = 'check_location')
  OR (source:EventType AND source.code IN ['self_study', 'group_study']
      AND r.code = 'pack_power_bank')
  OR (source:EventType AND source.code IN ['self_study', 'class_session']
      AND r.code = 'pack_stationery')
  OR (source:EventType AND source.code = 'class_session'
      AND r.code = 'charge_laptop'
  )
WITH collect(rel) AS obsoleteRelationships, count(rel) AS removedCount
FOREACH (obsoleteRelationship IN obsoleteRelationships | DELETE obsoleteRelationship)
RETURN removedCount AS removedTrimmedRelationshipCount;


// ============================================================
// 3. Context 1개
// 사람·학교·도서관·카페 이름만으로는 academic을 확정하지 않는다.
// ============================================================

UNWIND [
  {
    code: 'academic',
    name: '학교·학업·스터디',
    description: '수업, 공부, 시험, 과제 또는 스터디처럼 학습을 목적으로 하는 일정 맥락',
    examples: [
      '공부하기', '일본어 공부', '카페에서 공부', '복습',
      '수업 듣기', '온라인 강의', '시험 준비', '과제 제출', '스터디 참여'
    ],
    exclusionExamples: [
      '민수', '학교', '가천대', '도서관', '카페', '스터디카페',
      '일본 여행', '친구 약속', '팀플 회의', '회사 회의',
      '취업 면접', '첫 출근', '입사 오리엔테이션', '거래처 미팅'
    ],
    embeddingText: '공부하기, 일본어 공부, 카페에서 공부, 복습, 자습, 수업 듣기, 온라인 강의, 시험 준비, 과제 작성과 제출, 사람들과 스터디하기. 지식이나 기술을 배우고 연습하거나 학업 결과물을 준비하는 일정.',
    contextLevel: 'category',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  }
] AS row
MERGE (c:Context {code: row.code})
ON CREATE SET c.createdAt = datetime()
SET c += row,
    c.updatedAt = datetime();


// ============================================================
// 4. EventType 4개
// assignment는 기존 EventType을 재사용한다.
// ============================================================

UNWIND [
  {
    code: 'self_study',
    name: '개인 공부·복습',
    description: '혼자 학습 범위를 정해 공부하거나 이전 내용을 복습하는 일정',
    examples: ['일본어 공부', '카페 공부', '도서관에서 복습', '자습', '중간고사 공부'],
    exclusionExamples: ['스터디카페', '스터디룸', '학교', '도서관 책 반납', '시험 응시'],
    embeddingText: '일본어 공부하기, 카페에서 공부하기, 도서관에서 복습하기, 혼자 자습하기, 중간고사 범위 공부하기. 혼자 학습 범위를 정하고 교재나 자료를 보며 공부하는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'group_study',
    name: '그룹 스터디',
    description: '여러 사람이 학습 주제와 자료를 정해 함께 공부하는 일정',
    examples: ['친구들과 스터디', '시험 스터디', '전공 스터디', '스터디 모임', '같이 문제 풀기'],
    exclusionExamples: ['스터디카페', '스터디룸', '스터디 플래너', '팀플 회의', '사람 이름만 입력'],
    embeddingText: '친구들과 스터디하기, 시험 스터디, 전공 스터디 모임, 여러 사람이 같이 문제 풀기. 사람들과 학습 주제와 자료를 정해 함께 공부하는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'class_session',
    name: '수업·강의',
    description: '학교나 온라인에서 정해진 시간표에 따라 수업 또는 강의를 듣는 일정',
    examples: ['수업', '전공 강의', '교양 수업', '온라인 강의', '특강', '세미나 수업'],
    exclusionExamples: [
      '회사 회의', '온라인 회의', '공연', '강연 관람',
      '첫 출근', '입사 오리엔테이션', '신입사원 교육'
    ],
    embeddingText: '학교 수업, 전공 강의, 교양 수업, 온라인 강의 듣기, 특강 수강, 세미나 수업처럼 정해진 시간표에 따라 학습 내용을 듣는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'exam',
    name: '시험·퀴즈 응시',
    description: '정해진 시간과 장소에서 시험이나 퀴즈에 응시하는 일정',
    examples: ['중간고사', '기말고사', '시험 보는 날', '퀴즈', '자격시험', '모의고사'],
    exclusionExamples: ['중간고사 공부', '시험 공부', '기말고사 준비', '문제 풀이'],
    embeddingText: '중간고사 응시, 기말고사 보는 날, 시험장에 가서 시험 보기, 수업 퀴즈 응시, 자격시험, 모의고사처럼 정해진 시간과 장소에서 평가에 참여하는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  }
] AS row
MERGE (e:EventType {code: row.code})
ON CREATE SET e.createdAt = datetime()
SET e += row,
    e.updatedAt = datetime();


// ============================================================
// 5. 신규 PlaceType 없음
// 기존 school / library / cafe / online을 재사용한다.
// ============================================================


// ============================================================
// 6. Academic 전용 RecommendationTemplate 12개
// ============================================================

UNWIND [
  {
    code: 'set_study_goal', name: '이번에 공부할 범위 정하기',
    description: '공부를 시작하기 전에 이번 일정에서 끝낼 범위를 작게 정한다.',
    examples: ['공부 범위', '오늘 할 분량', '학습 목표'],
    triggerExamples: ['개인 공부', '시험 공부', '복습', '자습'],
    conditionalText: '이번에 공부할 범위를 하나 정해둘까요?',
    embeddingText: '개인 공부, 시험 공부, 복습, 자습처럼 무엇부터 할지 정해야 하는 일정. 추천 행동: 이번 일정에서 공부할 범위 하나 정하기.',
    category: 'pre_task', actionType: 'plan', targetType: 'study_goal',
    suggestionLevel: 'contextual', defaultTiming: '공부 시작 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'prepare_study_materials', name: '필요한 교재와 자료 챙기기',
    description: '공부나 수업에 사용할 교재, 노트와 디지털 자료를 준비한다.',
    examples: ['교재 챙기기', '강의자료', '필기노트', '문제집'],
    triggerExamples: ['공부', '스터디', '수업', '복습'],
    conditionalText: '사용할 교재와 필기자료를 미리 챙길까요?',
    embeddingText: '공부, 스터디, 수업, 복습처럼 교재, 노트, 문제집 또는 파일을 사용하는 일정. 추천 행동: 필요한 교재와 필기자료 챙기기.',
    category: 'document', actionType: 'prepare', targetType: 'study_material',
    suggestionLevel: 'safe', defaultTiming: '일정 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'review_previous_study', name: '이전에 공부한 부분 잠깐 확인하기',
    description: '공부를 이어갈 수 있도록 마지막 진도와 메모를 짧게 확인한다.',
    examples: ['마지막 진도', '이전 공부', '복습 메모'],
    triggerExamples: ['이어 공부하기', '정기 스터디', '복습', '지난 진도'],
    conditionalText: '마지막으로 공부한 부분을 잠깐 확인할까요?',
    embeddingText: '이어 공부하기, 정기 스터디, 복습, 지난 진도처럼 이전 학습에서 계속 진행하는 일정. 추천 행동: 마지막 진도와 이전 메모 잠깐 확인하기.',
    category: 'check', actionType: 'review', targetType: 'study_progress',
    suggestionLevel: 'contextual', defaultTiming: '공부 시작 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'pack_stationery', name: '필기구 챙기기',
    description: '필기와 시험에 사용할 펜, 샤프와 지우개를 챙긴다.',
    examples: ['펜', '샤프', '지우개', '형광펜'],
    triggerExamples: ['수업', '시험', '스터디', '필기'],
    conditionalText: '필기에 필요한 펜과 지우개를 챙길까요?',
    embeddingText: '수업, 시험, 스터디, 필기처럼 손으로 내용을 적거나 답안을 작성하는 일정. 추천 행동: 펜, 샤프와 지우개 등 필기구 챙기기.',
    category: 'item', actionType: 'pack', targetType: 'stationery',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'check_study_schedule', name: '스터디 시간과 장소 확인하기',
    description: '참여자들과 정한 스터디 시작 시간과 만날 장소를 확인한다.',
    examples: ['스터디 시간', '스터디 장소', '몇 시에 공부'],
    triggerExamples: ['그룹 스터디', '시험 스터디', '같이 문제 풀기'],
    conditionalText: '스터디 시작 시간과 만날 장소를 확인할까요?',
    embeddingText: '그룹 스터디, 시험 스터디, 같이 문제 풀기처럼 여러 사람이 함께 공부하는 일정. 추천 행동: 스터디 시작 시간과 만날 장소 확인하기.',
    category: 'check', actionType: 'check', targetType: 'schedule_location',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'check_class_schedule', name: '수업 시간과 강의실 확인하기',
    description: '처음 듣는 수업이거나 장소가 익숙하지 않을 때 시작 시간, 건물과 강의실을 확인한다.',
    examples: ['수업 시간', '강의실', '강의동', '온라인 수업'],
    triggerExamples: ['전공 수업', '교양 강의', '온라인 강의', '특강'],
    conditionalText: '처음 가는 수업이라면 건물과 강의실을 미리 확인할까요?',
    embeddingText: '신입생 첫 수업, 처음 듣는 전공 수업, 익숙하지 않은 강의동이나 강의실에서 듣는 수업. 추천 행동: 수업 시작 시간, 건물과 강의실 확인하기.',
    category: 'check', actionType: 'check', targetType: 'schedule_location',
    suggestionLevel: 'contextual', defaultTiming: '전날 또는 수업 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true, excludedPlaceTypes: ['online']
  },
  {
    code: 'check_course_notice', name: '수업 공지와 변경사항 확인하기',
    description: '휴강, 강의실 변경, 준비물 또는 새 자료 공지를 확인한다.',
    examples: ['수업 공지', '휴강', '강의실 변경', '준비물 공지'],
    triggerExamples: ['학교 수업', '온라인 강의', '특강', '보강'],
    conditionalText: '휴강이나 강의실 변경 공지가 없는지 확인할까요?',
    embeddingText: '학교 수업, 온라인 강의, 특강, 보강처럼 공지에 따라 장소와 준비물이 바뀔 수 있는 일정. 추천 행동: 휴강, 강의실 변경과 새 자료 공지 확인하기.',
    category: 'check', actionType: 'check', targetType: 'course_notice',
    suggestionLevel: 'safe', defaultTiming: '수업 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'check_exam_schedule', name: '시험 시간과 시험실 확인하기',
    description: '시험 날짜, 시작 시간과 응시 장소를 확인한다.',
    examples: ['시험 시간', '시험실', '고사장', '입실 시간'],
    triggerExamples: ['중간고사', '기말고사', '퀴즈', '자격시험'],
    conditionalText: '시험 시작 시간과 시험실을 확인할까요?',
    embeddingText: '중간고사, 기말고사, 퀴즈, 자격시험처럼 정해진 시간과 장소에서 응시하는 일정. 추천 행동: 시험 날짜, 시작 시간과 시험실 확인하기.',
    category: 'check', actionType: 'check', targetType: 'schedule_location',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'check_exam_scope', name: '시험 범위 확인하기',
    description: '공지된 시험 범위와 제외되는 내용을 확인한다.',
    examples: ['시험 범위', '몇 장까지', '출제 범위'],
    triggerExamples: ['중간고사', '기말고사', '퀴즈', '시험 준비'],
    conditionalText: '공지된 시험 범위를 다시 확인할까요?',
    embeddingText: '중간고사, 기말고사, 퀴즈, 시험 준비처럼 출제되는 학습 범위를 알아야 하는 일정. 추천 행동: 공지된 시험 범위와 제외 내용 확인하기.',
    category: 'check', actionType: 'check', targetType: 'exam_scope',
    suggestionLevel: 'safe', defaultTiming: '시험 준비 시작 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'check_exam_requirements', name: '시험 준비물과 허용 도구 확인하기',
    description: '오픈북, 계산기 등 허용 도구와 필요한 준비물을 공식 공지에서 확인한다.',
    examples: ['오픈북', '계산기 허용', '시험 준비물', '반입 가능'],
    triggerExamples: ['중간고사', '기말고사', '자격시험', '오픈북 시험'],
    conditionalText: '시험 공지에서 준비물과 허용 도구를 확인할까요?',
    embeddingText: '중간고사, 기말고사, 자격시험, 오픈북 시험처럼 사용할 수 있는 도구와 준비물이 정해진 일정. 추천 행동: 공식 시험 공지에서 준비물과 허용 도구 확인하기.',
    category: 'check', actionType: 'check', targetType: 'exam_requirement',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'check_assignment_requirements', name: '과제 형식과 요구사항 확인하기',
    description: '분량, 파일 형식, 파일명과 필수 포함 항목을 확인한다.',
    examples: ['과제 양식', '파일 형식', '분량', '파일명 규칙'],
    triggerExamples: ['개인 과제', '레포트', '팀플 제출', '보고서 제출'],
    conditionalText: '과제 분량과 파일 형식, 필수 항목을 확인할까요?',
    embeddingText: '개인 과제, 레포트, 팀플 제출, 보고서 제출처럼 정해진 양식에 맞춰 결과물을 내는 일정. 추천 행동: 과제 분량, 파일 형식, 파일명과 필수 항목 확인하기.',
    category: 'check', actionType: 'check', targetType: 'assignment_requirement',
    suggestionLevel: 'safe', defaultTiming: '작업 시작 전 또는 제출 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  },
  {
    code: 'check_study_space_access', name: '공부할 장소의 운영시간 확인하기',
    description: '도서관이나 카페의 운영시간, 휴무와 좌석 이용방법을 확인한다.',
    examples: ['도서관 운영시간', '좌석 예약', '스터디카페 시간', '휴관일'],
    triggerExamples: ['도서관 공부', '카페 공부', '시험기간 열람실'],
    conditionalText: '공부할 장소의 운영시간과 좌석 이용방법을 확인할까요?',
    embeddingText: '도서관 공부, 카페 공부, 시험기간 열람실처럼 운영시간과 좌석 이용방법이 있는 장소에서 공부하는 일정. 추천 행동: 공부할 장소의 운영시간, 휴무와 좌석 이용방법 확인하기.',
    category: 'check', actionType: 'check', targetType: 'study_space',
    suggestionLevel: 'contextual', defaultTiming: '출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'academic_v0.1', isActive: true
  }
] AS row
MERGE (r:RecommendationTemplate {code: row.code})
ON CREATE SET r.createdAt = datetime()
SET r += row,
    r.updatedAt = datetime();


// ============================================================
// 7. 기존 공용 노드 확인 (속성 수정 없음)
// 기대 missingSharedCodes = [], missingSharedEventTypes = [], missingSharedPlaceTypes = []
// ============================================================

OPTIONAL MATCH (r:RecommendationTemplate)
WHERE r.code IN [
  'check_location',
  'check_travel_time',
  'pack_laptop',
  'charge_laptop',
  'pack_laptop_charger',
  'pack_power_bank',
  'check_deadline',
  'check_submission_location',
  'check_needed_files',
  'open_final_file',
  'save_final_backup'
]
WITH collect(r.code) AS foundCodes
RETURN [
  code IN [
    'check_location',
    'check_travel_time',
    'pack_laptop',
    'charge_laptop',
    'pack_laptop_charger',
    'pack_power_bank',
    'check_deadline',
    'check_submission_location',
    'check_needed_files',
    'open_final_file',
    'save_final_backup'
  ]
  WHERE NOT (code IN foundCodes)
] AS missingSharedCodes;

OPTIONAL MATCH (e:EventType)
WHERE e.code IN ['assignment']
WITH collect(e.code) AS foundCodes
RETURN [
  code IN ['assignment']
  WHERE NOT (code IN foundCodes)
] AS missingSharedEventTypes;

OPTIONAL MATCH (p:PlaceType)
WHERE p.code IN ['school', 'library', 'cafe', 'online']
WITH collect(p.code) AS foundCodes
RETURN [
  code IN ['school', 'library', 'cafe', 'online']
  WHERE NOT (code IN foundCodes)
] AS missingSharedPlaceTypes;


// ============================================================
// 8. 신규 EventType 기반 추천 22개
// ============================================================

UNWIND [
  {sourceCode: 'self_study', recommendationCode: 'set_study_goal', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '이번 공부 범위 설정'},
  {sourceCode: 'self_study', recommendationCode: 'prepare_study_materials', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '필요한 교재와 자료 준비'},
  {sourceCode: 'self_study', recommendationCode: 'review_previous_study', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '마지막 학습 진도 확인'},
  {sourceCode: 'self_study', recommendationCode: 'pack_laptop', defaultRank: 4, requiredContexts: [], suggestionMode: 'contextual', reason: '디지털 자료 사용 가능'},
  {sourceCode: 'self_study', recommendationCode: 'pack_laptop_charger', defaultRank: 5, requiredContexts: [], suggestionMode: 'conditional', reason: '장시간 노트북 사용 가능'},

  {sourceCode: 'group_study', recommendationCode: 'check_study_schedule', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '스터디 시간과 장소 확인'},
  {sourceCode: 'group_study', recommendationCode: 'prepare_study_materials', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '스터디에 필요한 자료 준비'},
  {sourceCode: 'group_study', recommendationCode: 'review_previous_study', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '이전 스터디 진도 확인'},
  {sourceCode: 'group_study', recommendationCode: 'check_travel_time', defaultRank: 4, requiredContexts: [], suggestionMode: 'contextual', reason: '스터디 장소까지 이동시간 확인'},
  {sourceCode: 'group_study', recommendationCode: 'pack_laptop', defaultRank: 5, requiredContexts: [], suggestionMode: 'contextual', reason: '공유 자료와 작업에 노트북 사용 가능'},
  {sourceCode: 'group_study', recommendationCode: 'charge_laptop', defaultRank: 6, requiredContexts: [], suggestionMode: 'conditional', reason: '외부에서 노트북 사용 가능'},
  {sourceCode: 'group_study', recommendationCode: 'pack_laptop_charger', defaultRank: 7, requiredContexts: [], suggestionMode: 'conditional', reason: '장시간 노트북 사용 가능'},

  {sourceCode: 'class_session', recommendationCode: 'check_course_notice', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '휴강과 변경사항 확인'},
  {sourceCode: 'class_session', recommendationCode: 'prepare_study_materials', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '수업 교재와 자료 준비'},
  {sourceCode: 'class_session', recommendationCode: 'check_class_schedule', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '처음 듣거나 익숙하지 않은 수업의 건물과 강의실 확인'},
  {sourceCode: 'class_session', recommendationCode: 'pack_laptop', defaultRank: 4, requiredContexts: [], suggestionMode: 'contextual', reason: '수업에서 노트북 사용 가능'},
  {sourceCode: 'class_session', recommendationCode: 'pack_laptop_charger', defaultRank: 5, requiredContexts: [], suggestionMode: 'conditional', reason: '장시간 수업 중 충전 필요 가능'},

  {sourceCode: 'exam', recommendationCode: 'check_exam_schedule', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '시험 시간과 시험실 확인'},
  {sourceCode: 'exam', recommendationCode: 'check_exam_scope', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '공지된 시험 범위 확인'},
  {sourceCode: 'exam', recommendationCode: 'check_exam_requirements', defaultRank: 3, requiredContexts: [], suggestionMode: 'safe', reason: '시험 준비물과 허용 도구 확인'},
  {sourceCode: 'exam', recommendationCode: 'pack_stationery', defaultRank: 4, requiredContexts: [], suggestionMode: 'contextual', reason: '답안 작성에 필요한 필기구 준비'},
  {sourceCode: 'exam', recommendationCode: 'check_travel_time', defaultRank: 5, requiredContexts: [], suggestionMode: 'contextual', reason: '시험 장소까지 이동시간 확인'}
] AS row
MATCH (e:EventType {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (e)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = row.requiredContexts,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'academic_v0.1',
    rel.isActive = true;


// ============================================================
// 9. 기존 assignment EventType에 신규 추천 2개 연결
// 기존 4개 관계는 migration으로 범용화했으므로 중복 생성하지 않는다.
// ============================================================

UNWIND [
  {recommendationCode: 'check_assignment_requirements', defaultRank: 2, suggestionMode: 'safe', reason: '과제 양식과 필수 요구사항 확인'},
  {recommendationCode: 'check_needed_files', defaultRank: 3, suggestionMode: 'safe', reason: '과제 작성과 제출에 필요한 파일 확인'}
] AS row
MATCH (e:EventType {code: 'assignment'})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (e)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = [],
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'academic_v0.1',
    rel.isActive = true;


// ============================================================
// 10. 기존 PlaceType 기반 추천 2개
// 장소 단독 입력으로 열리지 않도록 academic Context를 요구한다.
// ============================================================

UNWIND ['library', 'cafe'] AS sourceCode
MATCH (p:PlaceType {code: sourceCode})
MATCH (r:RecommendationTemplate {code: 'check_study_space_access'})
MERGE (p)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = 4,
    rel.requiredContexts = ['academic'],
    rel.suggestionMode = 'contextual',
    rel.reason = '공부할 장소의 운영시간과 좌석 이용방법 확인',
    rel.seedVersion = '0.1',
    rel.seedSource = 'academic_v0.1',
    rel.isActive = true;


// ============================================================
// 11. Academic seed smoke check
// 기대: Context 1, EventType 4, RecommendationTemplate 12
//       신규 노드 17, RECOMMENDS 26, invalid* 0
// ============================================================

MATCH (n {seedSource: 'academic_v0.1'})
RETURN labels(n)[0] AS label, count(*) AS nodeCount
ORDER BY label;

MATCH ()-[rel:RECOMMENDS {seedSource: 'academic_v0.1'}]->()
RETURN
  count(rel) AS recommendsCount,
  sum(CASE
    WHEN rel.defaultRank IS NULL
      OR rel.suggestionMode IS NULL
      OR rel.requiredContexts IS NULL
    THEN 1 ELSE 0
  END) AS invalidRelationshipCount;

MATCH (r:RecommendationTemplate {seedSource: 'academic_v0.1'})
RETURN
  count(r) AS academicRecommendationCount,
  sum(CASE
    WHEN r.embeddingText IS NULL
      OR r.conditionalText IS NULL
      OR r.suggestionLevel IS NULL
    THEN 1 ELSE 0
  END) AS invalidRecommendationCount;
