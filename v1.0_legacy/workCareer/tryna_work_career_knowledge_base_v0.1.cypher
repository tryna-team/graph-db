// Tryna 직장·취업 지식베이스 v0.1
//
// 전제:
// - teamProject v0.5, travel v0.1, hangout v0.1, academic v0.1 뒤에 추가 실행한다.
// - Neo4j Query에서 statement 단위로 위에서부터 실행한다.
//
// 범위:
// - 실제 채용 면접 일정
// - 첫 출근과 입사 온보딩
// - 평소와 다른 시간·장소로 출근
// - 거래처·고객사·협력사와의 업무 미팅
//
// 제외:
// - 회사명, 사람명, 장소명만으로 업무 목적 추론
// - 평범한 매일 출근에 반복 추천
// - 특정 서류, 정장, 신분증 또는 노트북을 근거 없이 단정


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
// 2. 기존 공용 노드의 Work/Career 호환 migration
// ============================================================

MATCH (e:EventType {code: 'meeting'})
SET e.description = '여러 사람이 만나거나 온라인으로 접속해 업무 또는 프로젝트 내용을 공유하고 논의하는 일정',
    e.examples = [
      '회의', '미팅', '팀플 회의', '프로젝트 위클리', '중간 점검',
      '온라인 회의', '회사 회의', '주간회의', '팀장님과 1:1'
    ],
    e.exclusionExamples = coalesce(e.exclusionExamples, []) + [
      value IN ['취업 면접', '첫 출근', '거래처 미팅', '고객사 방문', '외부 미팅']
      WHERE NOT (value IN coalesce(e.exclusionExamples, []))
    ],
    e.embeddingText = '회의, 미팅, 팀플 회의, 프로젝트 위클리, 중간 점검, 온라인 회의, 회사 회의, 주간회의, 팀장님과 1:1. 여러 사람이 만나거나 온라인으로 접속해 업무 또는 프로젝트 내용을 공유하고 논의하는 일정.',
    e.workCareerCompatibilityVersion = '0.1',
    e.updatedAt = datetime()
RETURN count(e) AS updatedMeetingCount;

UNWIND [
  {code: 'team_project', additions: ['취업 면접', '첫 출근', '거래처 미팅', '고객사 방문']},
  {code: 'travel', additions: ['고객사 방문', '다른 지점 출근']},
  {code: 'hangout', additions: ['취업 면접', '첫 출근', '거래처 미팅', '고객사 방문']},
  {code: 'academic', additions: ['취업 면접', '첫 출근', '입사 오리엔테이션', '거래처 미팅']}
] AS row
MATCH (c:Context {code: row.code})
SET c.exclusionExamples = coalesce(c.exclusionExamples, []) + [
      value IN row.additions
      WHERE NOT (value IN coalesce(c.exclusionExamples, []))
    ],
    c.workCareerCompatibilityVersion = '0.1',
    c.updatedAt = datetime()
RETURN count(c) AS updatedContextExclusionCount;

UNWIND [
  {
    code: 'meeting',
    additions: ['취업 면접', '첫 출근', '거래처 미팅', '고객사 방문', '외부 미팅']
  },
  {
    code: 'social_meetup',
    additions: ['취업 면접', '첫 출근', '거래처 미팅', '고객사 방문']
  },
  {
    code: 'class_session',
    additions: ['첫 출근', '입사 오리엔테이션', '신입사원 교육']
  },
  {
    code: 'travel_departure',
    additions: ['고객사 방문', '다른 지점 출근']
  }
] AS row
MATCH (e:EventType {code: row.code})
SET e.exclusionExamples = coalesce(e.exclusionExamples, []) + [
      value IN row.additions
      WHERE NOT (value IN coalesce(e.exclusionExamples, []))
    ],
    e.workCareerCompatibilityVersion = '0.1',
    e.updatedAt = datetime()
RETURN count(e) AS updatedEventTypeExclusionCount;

MATCH (:EventType {code: 'meeting'})-[rel:RECOMMENDS]->(r:RecommendationTemplate)
WHERE r.code IN ['check_meeting_time', 'note_discussion_points', 'check_needed_files']
SET rel.requiredContexts = [],
    rel.workCareerCompatibilityVersion = '0.1',
    rel.updatedAt = datetime()
RETURN count(rel) AS generalizedMeetingRelationshipCount;

UNWIND [
  {
    code: 'check_location',
    name: '정확한 장소 다시 확인하기',
    description: '건물, 층, 강의실, 매장 또는 방문 장소의 정확한 위치를 확인한다.',
    examples: ['장소 확인', '건물 확인', '강의실 확인', '매장 위치', '회사 위치'],
    triggerExamples: ['가천대', 'AI관', '성수', '카페에서 만나기', '처음 가는 장소', '회사 면접', '고객사 방문'],
    conditionalText: '정확한 건물과 방문 장소를 다시 확인할까요?',
    embeddingText: '학교, 강의실, 카페, 회사, 면접 장소, 고객사, 처음 가는 건물처럼 물리적인 장소가 포함된 일정. 추천 행동: 건물, 층, 강의실, 매장 또는 방문 위치를 다시 확인하기.'
  },
  {
    code: 'check_online_link',
    name: '온라인 일정 접속 링크 확인하기',
    description: '온라인 회의, 강의 또는 면접이 시작되기 전에 접속 링크나 채널을 확인한다.',
    examples: ['줌 링크', '디스코드 채널', '구글밋 링크', '온라인 면접 링크'],
    triggerExamples: ['온라인 팀플', '줌 회의', '온라인 강의', '화상 면접', '온라인 미팅'],
    conditionalText: '온라인 일정의 접속 링크나 채널을 확인할까요?',
    embeddingText: '온라인 팀플, 줌 회의, 온라인 강의, 구글밋, 화상 면접처럼 링크나 채널로 접속하는 일정. 추천 행동: 온라인 일정의 접속 링크와 채널 확인하기.'
  },
  {
    code: 'check_microphone',
    name: '카메라·마이크·이어폰 확인하기',
    description: '온라인 회의, 강의 또는 면접에서 영상과 소리가 정상적으로 작동하는지 확인한다.',
    examples: ['카메라 확인', '마이크 확인', '이어폰 확인', '화상 테스트'],
    triggerExamples: ['온라인 팀플', '줌 회의', '온라인 강의', '화상 면접', '온라인 발표'],
    conditionalText: '카메라와 마이크, 이어폰이 잘 작동하는지 확인할까요?',
    embeddingText: '온라인 팀플, 줌 회의, 온라인 강의, 화상 면접, 온라인 발표처럼 영상과 음성을 사용하는 일정. 추천 행동: 카메라, 마이크와 이어폰 작동 확인하기.'
  }
] AS row
MATCH (r:RecommendationTemplate {code: row.code})
SET r.name = row.name,
    r.description = row.description,
    r.examples = row.examples,
    r.triggerExamples = row.triggerExamples,
    r.conditionalText = row.conditionalText,
    r.embeddingText = row.embeddingText,
    r.workCareerCompatibilityVersion = '0.1',
    r.updatedAt = datetime()
RETURN count(r) AS updatedSharedRecommendationCount;

UNWIND ['check_location', 'check_travel_time', 'check_transport'] AS code
MATCH (r:RecommendationTemplate {code: code})
SET r.excludedPlaceTypes = coalesce(r.excludedPlaceTypes, []) +
      CASE
        WHEN 'online' IN coalesce(r.excludedPlaceTypes, []) THEN []
        ELSE ['online']
      END,
    r.workCareerCompatibilityVersion = '0.1',
    r.updatedAt = datetime()
RETURN count(r) AS gatedOfflineRecommendationCount;


// ============================================================
// 3. Context 1개
// Context 자체에는 추천 관계를 만들지 않는다.
// ============================================================

UNWIND [
  {
    code: 'work_career',
    name: '직장·취업',
    description: '채용 면접, 첫 출근, 온보딩, 평소와 다른 출근 또는 업무 미팅처럼 직장과 취업에 관련된 일정 맥락',
    examples: [
      '회사 면접', '온라인 면접', '첫 출근', '입사 첫날',
      '온보딩', '신입 교육', '거래처 미팅', '고객사 방문',
      '회사 주간회의', '팀장님과 1:1', '다른 지점 출근'
    ],
    exclusionExamples: [
      '회사', '삼성전자', '네이버', '김대리', '판교', '강남',
      '평소 출근', '매일 출근', '면접 스터디', '취업 면접 특강', '대입 면접',
      '팀플 회의', '학교 수업', '친구 약속', '회사 회식'
    ],
    embeddingText: '회사 면접, 온라인 면접, 첫 출근, 입사 첫날, 입사 온보딩, 신입사원 교육, 회사 주간회의, 팀장님과 1:1, 거래처 미팅, 고객사 방문, 협력사 회의, 다른 지점으로 출근. 취업 절차나 직장에서 회의, 준비와 평소와 다른 이동이 필요한 일정.',
    contextLevel: 'category',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
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
    code: 'job_interview',
    name: '채용 면접',
    description: '지원한 회사나 기관에서 정해진 시간과 방식으로 진행하는 실제 채용 면접 일정',
    examples: ['면접', '1차 면접', '최종 면접', '온라인 면접', '인턴 면접', '아르바이트 면접'],
    exclusionExamples: [
      '면접 스터디', '모의면접 연습', '취업 면접 특강', '면접 결과 발표',
      '면접관 교육', '대입 면접', '대입 면접 준비', '사용자 인터뷰', '고객 인터뷰', '소개팅'
    ],
    embeddingText: '회사 채용 면접, 1차 면접, 최종 면접, 화상 면접, 온라인 면접, 인턴 면접, 아르바이트 면접처럼 지원한 직무의 실제 채용 면접이 정해진 시간과 방식으로 진행되는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'first_day_onboarding',
    name: '첫 출근·입사 온보딩',
    description: '입사 후 처음 출근하거나 회사의 온보딩과 신입사원 안내에 참여하는 일정',
    examples: ['첫 출근', '입사 첫날', '첫 근무', '온보딩', '입사 오리엔테이션', '신입사원 교육'],
    exclusionExamples: ['평소 출근', '매일 출근', '개강 첫날', '첫 수업', '신입생 오티', '여행 첫날'],
    embeddingText: '첫 출근, 입사 첫날, 첫 근무, 입사 온보딩, 입사 오리엔테이션, 신입사원 교육처럼 새 직장에 처음 출근하거나 입사 안내를 받는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'nonroutine_commute',
    name: '평소와 다른 출근',
    description: '평소와 다른 시간, 지점, 사무실 또는 교육장으로 출근하는 일정',
    examples: ['다른 지점 출근', '오늘만 본사 출근', '새 사무실 출근', '교육장으로 출근', '평소보다 이른 출근', '야간 출근'],
    exclusionExamples: ['출근', '평소 출근', '매일 출근', '퇴근', '재택근무', '첫 출근', '입사 첫날'],
    embeddingText: '다른 지점으로 출근, 오늘만 본사 출근, 새 사무실 출근, 교육장으로 바로 출근, 평소보다 이른 출근, 야간 출근처럼 평소와 다른 시간이나 목적지로 이동하는 출근 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'external_work_meeting',
    name: '외부 관계자 업무 미팅',
    description: '거래처, 고객사, 협력사 또는 외부 담당자와 업무 목적으로 만나는 일정',
    examples: ['거래처 미팅', '고객사 방문', '협력사 회의', '외부 미팅', '온라인 거래처 미팅'],
    exclusionExamples: ['회사 주간회의', '사내 회의', '팀플 회의', '친구랑 미팅', '소개팅', '상담 약속'],
    embeddingText: '거래처 미팅, 고객사 방문, 협력사 회의, 외부 담당자 미팅, 온라인 거래처 미팅처럼 회사 밖의 관계자와 업무 내용을 논의하는 일정.',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  }
] AS row
MERGE (e:EventType {code: row.code})
ON CREATE SET e.createdAt = datetime()
SET e += row,
    e.updatedAt = datetime();


// ============================================================
// 5. 신규 PlaceType 없음
// online은 기존 PlaceType을 재사용한다.
// 회사명·건물명 단독 입력에서 업무 목적을 추론하지 않는다.
// ============================================================


// ============================================================
// 6. Work/Career 전용 RecommendationTemplate 8개
// ============================================================

UNWIND [
  {
    code: 'review_interview_notice', name: '면접 안내 메시지 다시 확인하기',
    description: '채용 담당자가 보낸 안내에서 면접 날짜, 시간, 진행 방식과 요청사항을 확인한다.',
    examples: ['면접 안내', '면접 메일', '면접 문자', '화상 면접 안내'],
    triggerExamples: ['회사 면접', '1차 면접', '온라인 면접', '최종 면접'],
    conditionalText: '면접 안내 메시지에서 시간과 진행 방식을 다시 확인할까요?',
    embeddingText: '회사 면접, 1차 면접, 최종 면접, 온라인 면접처럼 채용 담당자가 날짜와 진행 방식을 안내한 일정. 추천 행동: 면접 안내 메시지에서 날짜, 시간, 진행 방식과 요청사항 다시 확인하기.',
    category: 'check', actionType: 'review', targetType: 'interview_notice',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'review_job_posting', name: '지원한 채용공고 다시 확인하기',
    description: '지원한 직무의 역할, 요구사항과 회사가 강조한 내용을 다시 확인한다.',
    examples: ['채용공고', '지원 직무', '직무 내용', '자격요건'],
    triggerExamples: ['회사 면접', '직무 면접', '인턴 면접', '알바 면접'],
    conditionalText: '지원한 채용공고와 직무 내용을 다시 확인할까요?',
    embeddingText: '회사 면접, 직무 면접, 인턴 면접, 아르바이트 면접처럼 지원한 역할에 관해 이야기하는 일정. 추천 행동: 지원한 채용공고의 직무 역할과 요구사항 다시 확인하기.',
    category: 'document', actionType: 'review', targetType: 'job_posting',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'review_submitted_application', name: '제출한 지원자료 다시 보기',
    description: '실제로 제출한 지원자료가 있다면 이력서, 자기소개서 또는 포트폴리오의 내용을 다시 확인한다.',
    examples: ['제출 이력서', '자기소개서', '포트폴리오', '지원서'],
    triggerExamples: ['서류 합격 면접', '포트폴리오 면접', '직무 면접'],
    conditionalText: '실제로 제출한 지원자료가 있다면 내용을 다시 확인할까요?',
    embeddingText: '서류 합격 후 면접, 포트폴리오 면접, 직무 면접처럼 제출한 지원자료를 바탕으로 질문을 받을 수 있는 일정. 추천 행동: 실제 제출한 지원자료가 있다면 이력서, 자기소개서 또는 포트폴리오 내용 다시 보기.',
    category: 'document', actionType: 'review', targetType: 'application_document',
    suggestionLevel: 'contextual', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'review_first_day_notice', name: '첫 출근 안내 다시 확인하기',
    description: '회사에서 보낸 첫 출근 안내의 출근 시각, 장소, 담당자와 요청사항을 확인한다.',
    examples: ['첫 출근 안내', '입사 안내 메일', '온보딩 안내', '출근 시간'],
    triggerExamples: ['첫 출근', '입사 첫날', '온보딩', '신입사원 교육'],
    conditionalText: '첫 출근 안내에서 시간과 장소, 담당자를 다시 확인할까요?',
    embeddingText: '첫 출근, 입사 첫날, 온보딩, 신입사원 교육처럼 회사의 입사 안내에 따라 참여하는 일정. 추천 행동: 첫 출근 안내에서 출근 시각, 장소, 담당자와 요청사항 다시 확인하기.',
    category: 'check', actionType: 'review', targetType: 'onboarding_notice',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'check_requested_documents', name: '요청받은 준비서류 확인하기',
    description: '회사 안내에서 직접 요청한 입사 서류가 있는지와 제출 방법을 확인한다.',
    examples: ['입사 서류', '준비서류', '제출 서류', '서류 제출 방법'],
    triggerExamples: ['첫 출근', '입사 첫날', '온보딩', '입사 서류 제출'],
    conditionalText: '회사에서 요청한 준비서류와 제출 방법을 확인할까요?',
    embeddingText: '첫 출근, 입사 첫날, 온보딩, 입사 서류 제출처럼 회사가 공식 안내에서 서류를 요청할 수 있는 일정. 추천 행동: 요청받은 준비서류와 제출 방법 확인하기. 특정 서류를 임의로 단정하지 않는다.',
    category: 'document', actionType: 'check', targetType: 'requested_document',
    suggestionLevel: 'safe', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'save_work_contact', name: '업무 담당자 연락처 저장하기',
    description: '도착 지연, 출입 문제 또는 일정 변경 시 연락할 담당자의 이름과 연락처를 저장한다.',
    examples: ['채용 담당자', '인사 담당자', '거래처 담당자', '연락처 저장'],
    triggerExamples: ['회사 면접', '첫 출근', '고객사 방문', '거래처 미팅'],
    conditionalText: '필요할 때 연락할 담당자 이름과 연락처를 저장할까요?',
    embeddingText: '회사 면접, 첫 출근, 고객사 방문, 거래처 미팅처럼 도착이나 출입 문제가 생기면 담당자에게 연락해야 할 수 있는 일정. 추천 행동: 업무 담당자 이름과 연락처 저장하기.',
    category: 'contact', actionType: 'save', targetType: 'work_contact',
    suggestionLevel: 'contextual', defaultTiming: '전날 또는 출발 전',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'check_dress_guidance', name: '별도 복장 안내가 있는지 확인하기',
    description: '정장을 단정하지 않고 회사가 따로 안내한 복장 기준이 있는지만 확인한다.',
    examples: ['복장 안내', '드레스코드', '자율 복장', '면접 복장'],
    triggerExamples: ['회사 면접', '첫 출근', '입사 안내'],
    conditionalText: '회사에서 별도로 안내한 복장 기준이 있는지 확인할까요?',
    embeddingText: '회사 면접, 첫 출근, 입사 첫날처럼 회사가 별도 복장 기준을 안내했을 수 있는 일정. 추천 행동: 정장을 단정하지 않고 공식 안내에 복장 기준이 있는지 확인하기.',
    category: 'check', actionType: 'check', targetType: 'dress_guidance',
    suggestionLevel: 'conditional', defaultTiming: '전날',
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
  },
  {
    code: 'check_workplace_access', name: '출입구와 방문 등록 방법 확인하기',
    description: '처음 가는 회사나 고객사의 출입구, 안내데스크와 방문 등록 방법을 확인한다.',
    examples: ['회사 출입구', '방문 등록', '안내데스크', '출입 방법'],
    triggerExamples: ['회사 면접', '첫 출근', '고객사 방문', '거래처 미팅'],
    conditionalText: '처음 가는 회사라면 출입구와 방문 등록 방법을 확인할까요?',
    embeddingText: '회사 면접, 첫 출근, 고객사 방문, 거래처 미팅처럼 처음 가는 회사 건물에 들어가야 하는 일정. 추천 행동: 출입구, 안내데스크와 방문 등록 방법 확인하기.',
    category: 'check', actionType: 'check', targetType: 'workplace_access',
    suggestionLevel: 'contextual', defaultTiming: '전날 또는 출발 전',
    excludedPlaceTypes: ['online'],
    locale: 'ko', seedVersion: '0.1', seedSource: 'work_career_v0.1', isActive: true
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
  'check_meeting_time', 'note_discussion_points', 'check_needed_files',
  'check_location', 'check_travel_time', 'check_transport', 'pack_laptop',
  'check_online_link', 'check_microphone'
]
WITH collect(r.code) AS foundCodes
RETURN [
  code IN [
    'check_meeting_time', 'note_discussion_points', 'check_needed_files',
    'check_location', 'check_travel_time', 'check_transport', 'pack_laptop',
    'check_online_link', 'check_microphone'
  ]
  WHERE NOT (code IN foundCodes)
] AS missingSharedCodes;

OPTIONAL MATCH (e:EventType)
WHERE e.code IN ['meeting']
WITH collect(e.code) AS foundCodes
RETURN [code IN ['meeting'] WHERE NOT (code IN foundCodes)] AS missingSharedEventTypes;

OPTIONAL MATCH (p:PlaceType)
WHERE p.code IN ['online']
WITH collect(p.code) AS foundCodes
RETURN [code IN ['online'] WHERE NOT (code IN foundCodes)] AS missingSharedPlaceTypes;


// ============================================================
// 8. Context 기반 추천 없음
// 회사·출근 같은 넓은 맥락만으로는 추천을 열지 않는다.
// ============================================================


// ============================================================
// 9. EventType 기반 추천 27개
// ============================================================

UNWIND [
  {sourceCode: 'job_interview', recommendationCode: 'review_interview_notice', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '면접 시간과 진행 방식 확인'},
  {sourceCode: 'job_interview', recommendationCode: 'review_job_posting', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '지원 직무와 요구사항 확인'},
  {sourceCode: 'job_interview', recommendationCode: 'review_submitted_application', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '실제로 제출한 지원자료가 있는 경우 내용 확인'},
  {sourceCode: 'job_interview', recommendationCode: 'check_location', defaultRank: 4, requiredContexts: [], suggestionMode: 'safe', reason: '오프라인 면접 장소 확인'},
  {sourceCode: 'job_interview', recommendationCode: 'check_travel_time', defaultRank: 5, requiredContexts: [], suggestionMode: 'contextual', reason: '오프라인 면접 장소까지 이동시간 확인'},
  {sourceCode: 'job_interview', recommendationCode: 'check_workplace_access', defaultRank: 6, requiredContexts: [], suggestionMode: 'contextual', reason: '회사 건물 출입구와 방문 등록 확인'},
  {sourceCode: 'job_interview', recommendationCode: 'save_work_contact', defaultRank: 7, requiredContexts: [], suggestionMode: 'contextual', reason: '문제 발생 시 연락할 채용 담당자 저장'},
  {sourceCode: 'job_interview', recommendationCode: 'check_dress_guidance', defaultRank: 8, requiredContexts: [], suggestionMode: 'conditional', reason: '별도 복장 안내가 있는 경우 확인'},

  {sourceCode: 'first_day_onboarding', recommendationCode: 'review_first_day_notice', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '첫 출근 시간과 장소, 담당자 확인'},
  {sourceCode: 'first_day_onboarding', recommendationCode: 'check_location', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '첫 출근 장소 확인'},
  {sourceCode: 'first_day_onboarding', recommendationCode: 'check_travel_time', defaultRank: 3, requiredContexts: [], suggestionMode: 'contextual', reason: '첫 출근 장소까지 이동시간 확인'},
  {sourceCode: 'first_day_onboarding', recommendationCode: 'save_work_contact', defaultRank: 4, requiredContexts: [], suggestionMode: 'contextual', reason: '첫 출근 담당자 연락처 저장'},
  {sourceCode: 'first_day_onboarding', recommendationCode: 'check_requested_documents', defaultRank: 5, requiredContexts: [], suggestionMode: 'safe', reason: '공식 안내에서 요청한 서류 확인'},
  {sourceCode: 'first_day_onboarding', recommendationCode: 'check_workplace_access', defaultRank: 6, requiredContexts: [], suggestionMode: 'contextual', reason: '회사 출입구와 출입 방법 확인'},
  {sourceCode: 'first_day_onboarding', recommendationCode: 'check_dress_guidance', defaultRank: 7, requiredContexts: [], suggestionMode: 'conditional', reason: '별도 복장 안내가 있는 경우 확인'},

  {sourceCode: 'nonroutine_commute', recommendationCode: 'check_location', defaultRank: 1, requiredContexts: [], suggestionMode: 'contextual', reason: '평소와 다른 출근 목적지 확인'},
  {sourceCode: 'nonroutine_commute', recommendationCode: 'check_travel_time', defaultRank: 2, requiredContexts: [], suggestionMode: 'contextual', reason: '평소와 다른 시간·장소까지 이동시간 확인'},
  {sourceCode: 'nonroutine_commute', recommendationCode: 'check_transport', defaultRank: 3, requiredContexts: [], suggestionMode: 'conditional', reason: '평소와 다른 출근 경로 확인'},

  {sourceCode: 'external_work_meeting', recommendationCode: 'check_meeting_time', defaultRank: 1, requiredContexts: [], suggestionMode: 'safe', reason: '외부 관계자와 정한 미팅 시간 확인'},
  {sourceCode: 'external_work_meeting', recommendationCode: 'check_location', defaultRank: 2, requiredContexts: [], suggestionMode: 'safe', reason: '고객사·거래처 미팅 장소 확인'},
  {sourceCode: 'external_work_meeting', recommendationCode: 'note_discussion_points', defaultRank: 3, requiredContexts: [], suggestionMode: 'safe', reason: '미팅에서 확인할 내용 메모'},
  {sourceCode: 'external_work_meeting', recommendationCode: 'check_needed_files', defaultRank: 4, requiredContexts: [], suggestionMode: 'safe', reason: '미팅에 사용할 파일과 링크 확인'},
  {sourceCode: 'external_work_meeting', recommendationCode: 'check_travel_time', defaultRank: 5, requiredContexts: [], suggestionMode: 'contextual', reason: '외부 미팅 장소까지 이동시간 확인'},
  {sourceCode: 'external_work_meeting', recommendationCode: 'check_transport', defaultRank: 6, requiredContexts: [], suggestionMode: 'conditional', reason: '외부 미팅 장소까지 이동 경로 확인'},
  {sourceCode: 'external_work_meeting', recommendationCode: 'save_work_contact', defaultRank: 7, requiredContexts: [], suggestionMode: 'contextual', reason: '외부 담당자 이름과 연락처 저장'},
  {sourceCode: 'external_work_meeting', recommendationCode: 'check_workplace_access', defaultRank: 8, requiredContexts: [], suggestionMode: 'contextual', reason: '고객사 출입구와 방문 등록 확인'},
  {sourceCode: 'external_work_meeting', recommendationCode: 'pack_laptop', defaultRank: 9, requiredContexts: [], suggestionMode: 'conditional', reason: '미팅에서 노트북을 사용한다고 명시된 경우'}
] AS row
MATCH (e:EventType {code: row.sourceCode})
MATCH (r:RecommendationTemplate {code: row.recommendationCode})
MERGE (e)-[rel:RECOMMENDS]->(r)
SET rel.defaultRank = row.defaultRank,
    rel.requiredContexts = row.requiredContexts,
    rel.suggestionMode = row.suggestionMode,
    rel.reason = row.reason,
    rel.seedVersion = '0.1',
    rel.seedSource = 'work_career_v0.1',
    rel.isActive = true;


// ============================================================
// 10. Work/Career seed smoke check
// 기대: Context 1, EventType 4, RecommendationTemplate 8
//       신규 노드 13, RECOMMENDS 27, invalid* 0
// ============================================================

MATCH (n {seedSource: 'work_career_v0.1'})
RETURN labels(n)[0] AS label, count(*) AS nodeCount
ORDER BY label;

MATCH ()-[rel:RECOMMENDS {seedSource: 'work_career_v0.1'}]->()
RETURN
  count(rel) AS recommendsCount,
  sum(CASE
    WHEN rel.defaultRank IS NULL
      OR rel.suggestionMode IS NULL
      OR rel.requiredContexts IS NULL
    THEN 1 ELSE 0
  END) AS invalidRelationshipCount;

MATCH (r:RecommendationTemplate {seedSource: 'work_career_v0.1'})
RETURN
  count(r) AS workCareerRecommendationCount,
  sum(CASE
    WHEN r.embeddingText IS NULL
      OR r.conditionalText IS NULL
      OR r.suggestionLevel IS NULL
    THEN 1 ELSE 0
  END) AS invalidRecommendationCount;
