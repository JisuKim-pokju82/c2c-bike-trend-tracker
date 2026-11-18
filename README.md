# 5대 오토바이 플랫폼 중고 매물 일별 동향 & RAW 데이터 트래커

매일 한국시간(KST) **오전 09:00 정각 (`UTC 00:00`)** 에 **Antigravity Automations + GitHub Actions 클라우드 + Windows 백그라운드 작업 스케줄러**가 자동으로 실행되어 5대 오토바이 플랫폼의 등록대수·신규등록·판매소진 및 포트폴리오(배기량 300cc 기준, 브랜드/제조사, 판매가격, 지역, 인기모델)를 동일 조건(Apple-to-Apple)으로 수집·기록합니다.

## 추적 대상 플랫폼 (5개사 비교 양식)
1. **당근 (오토바이 직거래)** (`https://www.daangn.com/kr/buy-sell/?search=오토바이`)
   - 당근중고차(`/kr/cars/`) 내 '오토바이' 바로가기 연동 대상인 당근 개인 직거래 오토바이·스쿠터 실매물을 멀티 키워드 병렬 검색 + 사이트맵으로 전국 수집 (용품·헬멧·자전거·킥보드·삽니다 및 35만원 미만 부품류 제외)
2. **라이트바겐** (`https://www.reitwagen.co.kr/`)
   - 외부 파쏘 크롤링(`PASSO`)·신차(`BRANDNEW`)·직영인증(`BAREE_CERTIFIED`)을 분리한 **순수 라이트바겐 자체 등록 중고매물(`BAREE`)** 기준
3. **파쏘 바이크** (`http://bike.passo.co.kr/bike/`)
   - 신차 프로모션을 제외한 **파쏘 중고 오토바이 매물 전체**를 클라우드 실시간 인덱스로 수집
4. **바튜매 (네이버 카페)** (`https://cafe.naver.com/bikecargogo`)
   - 제휴업체 일일 반복 도배 게시판(272·302)을 제외한 **개인 판매 게시판(351: 125cc초과, 352: 125cc이하) 및 안전결제 장터(133·144)의 최근 30일 활성 매물 전수** 기준 (로그인 불필요)
5. **케이카 (K Car)**
   - 현재 오토바이 서비스 미운영 상태이므로 대시보드 및 CSV에 **별도 비교 칸만 잡아두고 숫자는 일절 기재하지 않음(`-` 처리)**

## 주요 산출물
- **통합 웹 대시보드**: [`index.html`](./index.html) / [`competitor_trend.html`](./competitor_trend.html)
- **일자별 요약 누적 CSV**: [`competitor_trend.csv`](./competitor_trend.csv)
- **개별 바이크 상세 RAW 데이터**: [`raw_data/raw_bikes_latest.csv`](./raw_data/raw_bikes_latest.csv)
- **일별 고유 매물 ID 스냅샷**: [`snapshots/`](./snapshots/)
