# 5-Platform Used Motorcycle Apple-to-Apple Daily Collector (10:00 KST)
# Platforms:
#   1) Daangn (https://www.daangn.com/kr/buy-sell/?search=오토바이 - C2C Direct Motorcycle Listings)
#   2) Reitwagen (https://www.reitwagen.co.kr/ - Native BAREE used listings, excluding external PASSO crawl)
#   3) Passo Bike (http://bike.passo.co.kr/bike/ - Used motorcycle listings, excluding new bike promotions)
#   4) Batumae Naver Cafe (https://cafe.naver.com/bikecargogo - Personal C2C & Safety-Pay 30-day active listings)
#   5) K Car (Service not currently active - placeholder slot only, no numeric values recorded)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::DefaultConnectionLimit = 32

$WorkDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkDir) { $WorkDir = (Get-Location).Path }

$SnapshotDir = Join-Path $WorkDir "snapshots"
$RawDir      = Join-Path $WorkDir "raw_data"
foreach ($d in @($SnapshotDir, $RawDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$JsonPath = Join-Path $WorkDir "competitor_trend.json"
$CsvPath  = Join-Path $WorkDir "competitor_trend.csv"
$JsPath   = Join-Path $WorkDir "competitor_trend_data.js"

$NowKst        = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9))
$TodayDate     = $NowKst.ToString("yyyy-MM-dd")
$Timestamp     = $NowKst.ToString("yyyy-MM-dd HH:mm:ss")
$Cutoff30dMs   = $NowKst.AddDays(-30).ToUnixTimeMilliseconds()
$Cutoff29dDate = $NowKst.AddDays(-29).ToString("yyyy-MM-dd")

function U([string]$esc) { return [regex]::Unescape($esc) }

$KR_UNDER300 = U "300cc \uC774\uD558"
$KR_OVER300  = U "300cc \uC774\uC0C1"
$KR_ONSALE   = U "\uD310\uB9E4\uC911"
$KR_RESERVED = U "\uC608\uC57D\uC911"
$KR_TRADED   = U "\uAC70\uB798\uC644\uB8CC"
$KR_PERSONAL = U "\uAC1C\uC778\uC9C1\uAC70\uB798"
$KR_ESCROW   = U "\uC548\uC804\uACB0\uC81C"
$KR_ETC      = U "\uAE30\uD0C0"

$PB_1 = U "300\uB9CC\uC6D0 \uBBF8\uB9CC"
$PB_2 = U "300~600\uB9CC\uC6D0"
$PB_3 = U "600~1,000\uB9CC\uC6D0"
$PB_4 = U "1,000~2,000\uB9CC\uC6D0"
$PB_5 = U "2,000\uB9CC\uC6D0 \uC774\uC0C1"
$PB_UNKNOWN = U "\uAC00\uACA9\uBBF8\uAE30\uC7AC"

function Get-BikePriceBand([int]$priceManwon) {
    if ($priceManwon -le 0)    { return $PB_UNKNOWN }
    if ($priceManwon -lt 300)  { return $PB_1 }
    if ($priceManwon -lt 600)  { return $PB_2 }
    if ($priceManwon -lt 1000) { return $PB_3 }
    if ($priceManwon -lt 2000) { return $PB_4 }
    return $PB_5
}

function Normalize-Region([string]$rawRegion) {
    if (-not $rawRegion) { return $KR_ETC }
    $r = $rawRegion.Trim()
    $map = [ordered]@{
        (U "\uC11C\uC6B8") = (U "\uC11C\uC6B8")
        (U "\uACBD\uAE30") = (U "\uACBD\uAE30")
        (U "\uC778\uCC9C") = (U "\uC778\uCC9C")
        (U "\uBD80\uCC9C") = (U "\uACBD\uAE30")
        (U "\uC218\uC6D0") = (U "\uACBD\uAE30")
        (U "\uC548\uC0B0") = (U "\uACBD\uAE30")
        (U "\uC77C\uC0B0") = (U "\uACBD\uAE30")
        (U "\uBD80\uC0B0") = (U "\uBD80\uC0B0")
        (U "\uB300\uAD6C") = (U "\uB300\uAD6C")
        (U "\uB300\uC804") = (U "\uB300\uC804")
        (U "\uAD11\uC8FC") = (U "\uAD11\uC8FC")
        (U "\uC6B8\uC0B0") = (U "\uC6B8\uC0B0")
        (U "\uC138\uC885") = (U "\uC138\uC885")
        (U "\uAC15\uC6D0") = (U "\uAC15\uC6D0")
        (U "\uCDA9\uBD81") = (U "\uCDA9\uBD81")
        (U "\uCDA9\uCCAD\uBD81") = (U "\uCDA9\uBD81")
        (U "\uCDA9\uB0A8") = (U "\uCDA9\uB0A8")
        (U "\uCDA9\uCCAD\uB0A8") = (U "\uCDA9\uB0A8")
        (U "\uC804\uBD81") = (U "\uC804\uBD81")
        (U "\uC804\uB77C\uBD81") = (U "\uC804\uBD81")
        (U "\uC804\uB0A8") = (U "\uC804\uB0A8")
        (U "\uC804\uB77C\uB0A8") = (U "\uC804\uB0A8")
        (U "\uACBD\uBD81") = (U "\uACBD\uBD81")
        (U "\uACBD\uC0C1\uBD81") = (U "\uACBD\uBD81")
        (U "\uACBD\uB0A8") = (U "\uACBD\uB0A8")
        (U "\uACBD\uC0C1\uB0A8") = (U "\uACBD\uB0A8")
        (U "\uC81C\uC8FC") = (U "\uC81C\uC8FC")
    }
    foreach ($k in $map.Keys) {
        if ($r -like "*$k*") { return $map[$k] }
    }
    return $KR_ETC
}

function Resolve-SidoFromCoords([double]$lat, [double]$lng, [string]$fallbackText) {
    $byText = Normalize-Region $fallbackText
    if ($byText -ne $KR_ETC) { return $byText }
    if ($lat -le 0 -or $lng -le 0) { return $KR_ETC }
    if ($lat -lt 33.65) { return (U "\uC81C\uC8FC") }
    if ($lat -ge 37.43 -and $lat -le 37.70 -and $lng -ge 126.76 -and $lng -le 127.19) { return (U "\uC11C\uC6B8") }
    if ($lat -ge 37.33 -and $lat -le 37.63 -and $lng -ge 126.35 -and $lng -lt 126.76) { return (U "\uC778\uCC9C") }
    if ($lat -ge 36.89 -and $lat -le 38.30 -and $lng -ge 126.50 -and $lng -le 127.80) { return (U "\uACBD\uAE30") }
    if ($lat -ge 34.98 -and $lat -le 35.39 -and $lng -ge 128.78 -and $lng -le 129.31) { return (U "\uBD80\uC0B0") }
    if ($lat -ge 35.39 -and $lat -le 35.73 -and $lng -ge 129.00 -and $lng -le 129.47) { return (U "\uC6B8\uC0B0") }
    if ($lat -ge 35.60 -and $lat -le 36.02 -and $lng -ge 128.35 -and $lng -le 128.80) { return (U "\uB300\uAD6C") }
    if ($lat -ge 36.18 -and $lat -le 36.50 -and $lng -ge 127.25 -and $lng -le 127.56) { return (U "\uB300\uC804") }
    if ($lat -ge 36.43 -and $lat -le 36.72 -and $lng -ge 127.13 -and $lng -le 127.39) { return (U "\uC138\uC885") }
    if ($lat -ge 35.05 -and $lat -le 35.26 -and $lng -ge 126.65 -and $lng -le 127.02) { return (U "\uAD11\uC8FC") }
    if ($lat -ge 37.05 -and $lng -gt 127.70) { return (U "\uAC15\uC6D0") }
    if ($lat -ge 36.00 -and $lat -lt 37.05 -and $lng -lt 127.30) { return (U "\uCDA9\uB0A8") }
    if ($lat -ge 36.05 -and $lat -lt 37.25 -and $lng -ge 127.30 -and $lng -le 128.65) { return (U "\uCDA9\uBD81") }
    if ($lat -ge 35.28 -and $lat -lt 36.15 -and $lng -lt 127.90) { return (U "\uC804\uBD81") }
    if ($lat -lt 35.55 -and $lng -lt 127.90) { return (U "\uC804\uB0A8") }
    if ($lat -ge 35.55 -and $lng -ge 127.90) { return (U "\uACBD\uBD81") }
    if ($lat -lt 35.90 -and $lng -ge 127.55) { return (U "\uACBD\uB0A8") }
    return $KR_ETC
}

# Comprehensive Motorcycle Brand & Model + Engine CC Inference Engine
$BrandRules = @(
    @{ Brand = (U "\uD63C\uB2E4");      Pattern = '(?i)(혼다|honda|\bpcx|\bforza|포르자|슈퍼커브|슈퍼\s*커브|\bc125\b|\bcb\d|\bcbr\d|호넷|레블|rebel|골드윙|x-?adv|\badv\s*\d|몽키\s*125|그롬|msx\s*125|벤리|아프리카\s*트윈|\bcrf\d|\bcl\s*500|\bnc750|엘리트\s*125|스크램블러\s*cl)' },
    @{ Brand = (U "\uC57C\uB9C8\uD558"); Pattern = '(?i)(야마하|yamaha|\bnmax|엔맥스|\bxmax|엑스맥스|\btmax|티맥스|테크맥스|\bmt-?0|\bmt-?10|\bmt\s*0|\byzf|\br3\b|\br6\b|\br7\b|\br9\b|\br1\b|\bxsr|트리시티|에어로스|시그너스|테네레|페이저|\bfjr)' },
    @{ Brand = "BMW";                   Pattern = '(?i)(\bbmw\b|\br\s*1200|\br\s*1250|\br\s*1300|\bs\s*1000|\bm\s*1000|\br\s*18\b|알나인티|r\s*nine\s*t|\br9t\b|\bf\s*750|\bf\s*800|\bf\s*850|\bf\s*900|\bg\s*310|\bc\s*400|\bc\s*600|\bc\s*650|\bk\s*1600|\bce\s*04)' },
    @{ Brand = (U "\uD560\uB9AC\uB370\uC774\uBE44\uC2A8"); Pattern = '(?i)(할리|harley|스트리트\s*밥|스글|스트리트\s*글라이드|로드\s*글라이드|로글|로드킹|팻보이|팻밥|브레이크\s*아웃|아이언\s*883|\b883\b|포티에잇|스포스터|나잇스터|팬\s*아메리카|로우\s*라이더|소프테일|울트라\s*리미티드|헤리티지)' },
    @{ Brand = (U "\uC2A4\uC988\uD0A4"); Pattern = '(?i)(스즈키|스즈끼|suzuki|\bgsx|하야부사|브이스트롬|v-?strom|버그만|어드레스|\bnex\b|넥스\s*125|아베니스|스위시|카타나|\bsv\s*650|\bdr-?z)' },
    @{ Brand = (U "\uAC00\uC640\uC0AC\uD0A4"); Pattern = '(?i)(가와사키|kawasaki|닌자|ninja|\bzx-?\d|\bz125|\bz400|\bz650|\bz900|\bz1000|버시스|발칸|엘리미네이터|\bw800|\bh2\b|메구로)' },
    @{ Brand = (U "\uB450\uCE74\uD2F0"); Pattern = '(?i)(두카티|ducati|파니갈레|스크램블러\s*아이콘|데저트\s*슬레드|데저트슬레드|멀티스트라다|디아벨|스트리트\s*파이터|하이퍼모타드|\b몬스터\s*\d)' },
    @{ Brand = (U "\uBCA0\uC2A4\uD30C"); Pattern = '(?i)(베스파|vespa|피아지오|piaggio|\bgts\s*125|\bgts\s*300|프리마베라|스프린트|스플린터|\blx\s*125)' },
    @{ Brand = (U "\uD2B8\uB77C\uC774\uC5C4\uD504"); Pattern = '(?i)(트라이엄프|triumph|본네빌|스피드\s*트윈|스트리트\s*트리플|스피드\s*트리플|타이거\s*\d|트라이던트|로켓\s*3|스피드\s*400|스크램블러\s*400|스크램블러\s*900|스크램블러\s*1200)' },
    @{ Brand = (U "\uB85C\uC584\uC5D4\uD544\uB4DC"); Pattern = '(?i)(로얄엔필드|로열엔필드|royal\s*enfield|헌터\s*350|클래식\s*350|클래식\s*500|메테오|인터셉터|컨티넨탈\s*gt|히말라얀|샷건\s*650|게릴라\s*450)' },
    @{ Brand = "KTM";                   Pattern = '(?i)(\bktm\b|듀크|duke|\brc\s*125|\brc\s*390|슈퍼\s*어드벤처|어드벤처\s*\d{3,4}|\b390\s*adv|슈퍼듀크|\bexc\b)' },
    @{ Brand = (U "\uD5C8\uC2A4\uD06C\uBC14\uB098"); Pattern = '(?i)(허스크바나|husqvarna|스바르트필렌|비트필렌|노든\s*901)' },
    @{ Brand = "SYM";                   Pattern = '(?i)(\bsym\b|보이저|보이져|크루심|조이맥스|맥심|\bdrg\b|\badx\b|젯14|피들)' },
    @{ Brand = (U "\uD0B4\uCF54");      Pattern = '(?i)(킴코|kymco|다운타운|엑스타운|익사이팅|\bak\s*550|필리\s*125)' },
    @{ Brand = (U "\uB514\uC5D4\uC5D0\uC774(DNA/\uB300\uB9BC)"); Pattern = '(?i)(대림|디엔에이|\bdna\b|시티베스트|시티에이스|유아이|데이스타|\bvf100|\buh115|엠보이|\bq2\b|\bq3\b)' },
    @{ Brand = (U "KR\uBAA8\uD130\uC2A4"); Pattern = '(?i)(kr모터스|효성|아퀼라|미라쥬|코멧|엑시브|델피노)' },
    @{ Brand = (U "\uC874\uD14C\uC2A4"); Pattern = '(?i)(존테스|zontes|\b350d\b|\b350e\b|\b350gk\b)' },
    @{ Brand = (U "CF\uBAA8\uD130");    Pattern = '(?i)(cf모토|cfmoto|파피오|\b450sr|\b450mt|\b450nk|\b700cl|\b800mt)' },
    @{ Brand = (U "\uC544\uD504\uB9B4\uB9AC\uC544"); Pattern = '(?i)(아프릴리아|aprilia|\brs\s*660|\brs\s*457|\brsv4|투오노|\bsr\s*gt)' },
    @{ Brand = (U "\uC778\uB514\uC5B8"); Pattern = '(?i)(인디언|indian|스카우트|치프테인)' },
    @{ Brand = (U "\uC774\uD0C8\uC82F/\uAE30\uD0C0\uC218\uC785"); Pattern = '(?i)(이탈젯|드래그스터|모토구찌|푸조|장고|몬디알|파가니|보그|voge|벤다|benda|트릭스|써론|탈라리아)' }
)

$ReitwagenBrandIdMap = @{
    "1"  = "BMW"
    "2"  = (U "\uD63C\uB2E4")
    "3"  = (U "\uD560\uB9AC\uB370\uC774\uBE44\uC2A8")
    "4"  = (U "\uB450\uCE74\uD2F0")
    "5"  = (U "\uC57C\uB9C8\uD558")
    "6"  = (U "\uAC00\uC640\uC0AC\uD0A4")
    "7"  = "SYM"
    "8"  = (U "\uC2A4\uC988\uD0A4")
    "9"  = "KTM"
    "10" = (U "\uBCA0\uC2A4\uD30C")
    "11" = (U "\uD2B8\uB77C\uC774\uC5C4\uD504")
    "12" = (U "\uB85C\uC584\uC5D4\uD544\uB4DC")
    "13" = (U "\uC778\uB514\uC5B8")
    "14" = (U "\uD0B4\uCF54")
    "15" = (U "\uC544\uD504\uB9B4\uB9AC\uC544")
    "21" = (U "\uB514\uC5D4\uC5D0\uC774(DNA/\uB300\uB9BC)")
    "22" = (U "KR\uBAA8\uD130\uC2A4")
    "29" = (U "\uD5C8\uC2A4\uD06C\uBC14\uB098")
}

function Resolve-Brand([string]$rawBrand, [string]$titleText, [string]$rwBrandId) {
    if ($rwBrandId -and $ReitwagenBrandIdMap.ContainsKey($rwBrandId)) {
        return $ReitwagenBrandIdMap[$rwBrandId]
    }
    $combined = "$rawBrand $titleText"
    foreach ($rule in $BrandRules) {
        if ($combined -match $rule.Pattern) {
            return $rule.Brand
        }
    }
    if ($rawBrand -and $rawBrand.Trim() -ne "") { return $rawBrand.Trim() }
    return $KR_ETC
}

function Resolve-ModelShort([string]$brandName, [string]$rawModel, [string]$titleText) {
    if ($rawModel -and $rawModel.Trim() -ne "") { return $rawModel.Trim() }
    $clean = [System.Net.WebUtility]::HtmlDecode($titleText)
    $clean = $clean -replace '\[[^\]]*\]', ' ' -replace '\([^\)]*\)', ' ' -replace '<[^>]*>', ' '
    $clean = $clean -replace '\b20\d{2}\s*년식?\b', ' ' -replace '\b\d{2}\s*(?:년식|연식|식)\b', ' '
    $clean = $clean -replace '\b[\d,]+\s*(?:km|키로|킬로|만\s*원?)\b', ' '
    $clean = $clean -replace '(판매합니다|팝니다|급처|무사고|구변완료|배기구변|신차급|상태최상|정비완료|대차|가격인하|가격내림|팔아요|중고|오토바이|바이크|스쿠터|모터사이클)', ' '
    $clean = $clean -replace '(?i)\b(honda|yamaha|suzuki|kawasaki|ducati|vespa|triumph|harley|ktm|bmw|sym|kymco)\b', ' '
    if ($brandName -and $brandName -ne $KR_ETC) {
        $clean = $clean -replace [regex]::Escape($brandName), ' '
    }
    $clean = ($clean -replace '[!/|·~]+', ' ' -replace '\s+', ' ').Trim()
    $tokens = @($clean -split '\s+' | Where-Object { $_ -and $_.Length -ge 2 -and $_ -notmatch '^(서울|경기|인천|부산|대구|대전|광주|울산|경남|경북|충남|충북|전남|전북|강원|제주|신차|새상품)$' })
    if ($tokens.Count -ge 2) { return "$($tokens[0]) $($tokens[1])" }
    if ($tokens.Count -eq 1) { return $tokens[0] }
    return $KR_ETC
}

function Infer-DisplacementCc([string]$titleText, [bool]$forceUnder125, [int]$defaultCc = 250) {
    if ($forceUnder125) { return 125 }
    $t = $titleText.ToLowerInvariant()
    if ($t -match 'xmax\s*300|엑스맥스\s*300|x\s*맥스\s*300') { return 292 }
    if ($t -match '포르자\s*300|forza\s*300') { return 279 }
    if ($t -match 'gts\s*300|베스파\s*300') { return 278 }
    if ($t -match '레블\s*300|rebel\s*300|cb\s*300|cbr\s*300|crf\s*300') { return 286 }
    if ($t -match '닌자\s*300|ninja\s*300|아퀼라\s*300') { return 296 }
    if ($t -match '크루심\s*300|조이맥스\s*300|보이저\s*300|보이져\s*300|다운타운\s*300') { return 279 }
    if ($t -match 'pcx|엔맥스|nmax|슈퍼\s*커브|\bc125\b|몽키\s*125|그롬|msx|벤리|어드레스|넥스\s*125|스위시|아베니스|보이저\s*125|보이져\s*125|크루심\s*125|시티베스트|시티에이스|프리마베라|스프린트|\bgts\s*125|필리\s*125|젯\s*14|파피오|스바르트필렌\s*125|\bgsx-?[rs]?\s*125|\bcb\s*125|\bcbr\s*125|전기\s*스쿠터|전기\s*오토바이') { return 125 }
    if ($t -match 'adv\s*150|adv\s*160|트리시티|버그만\s*200|cbr\s*250|코멧\s*250|브이스트롬\s*250|\b250\s*cc|\b155\s*cc|\b160\s*cc|\b125\s*cc|\b110\s*cc|\b100\s*cc|\b50\s*cc') { return 180 }
    if ($t -match '포르자\s*350|forza\s*350|adv\s*350') { return 330 }
    if ($t -match '헌터\s*350|클래식\s*350|메테오\s*350') { return 349 }
    if ($t -match 'mt-?03|\br3\b|yzf-?r3') { return 321 }
    if ($t -match 'g\s*310') { return 313 }
    if ($t -match 'c\s*400') { return 350 }
    if ($t -match '티맥스|tmax|테크맥스') { return 560 }
    if ($t -match 'mt-?07|\br7\b') { return 689 }
    if ($t -match 'mt-?09|\br9\b|xsr\s*900') { return 890 }
    if ($t -match 'mt-?10|\br1\b|s\s*1000|r\s*1000|cbr\s*1000|zx-?10') { return 999 }
    if ($t -match '할리|스트리트\s*밥|스글|로글|로드킹|브레이크\s*아웃|팻보이|팻밥|아이언\s*883|포티에잇|스포스터|소프테일|울트라|\b114\b|\b117\b|\b883\b') { return 1200 }
    if ($t -match '두카티|파니갈레|멀티스트라다|데저트\s*슬레드|디아벨|하야부사|골드윙|r\s*1200|r\s*1250|r\s*1300|\br\s*18\b|알나인티|r9t|본네빌|타이거|스피드\s*트윈|로켓\s*3|아프리카\s*트윈|x-?adv') { return 900 }
    $mCc = [regex]::Match($t, '\b(50|80|90|100|110|125|150|155|160|180|200|250|300|310|320|350|390|400|401|450|500|530|550|560|600|650|660|700|750|790|800|850|883|890|900|901|950|1000|1050|1100|1200|1250|1290|1300|1400|1600|1800)\s*(?:cc)?\b')
    if ($mCc.Success) {
        return [int]$mCc.Groups[1].Value
    }
    return $defaultCc
}

function Parse-TitlePriceManwon([string]$titleText) {
    if (-not $titleText) { return 0 }
    $m1 = [regex]::Match($titleText, '(?<!\d)(\d{1,2},?\d{3}|\d{2,4})\s*만\s*원?')
    if ($m1.Success) {
        $val = [int]($m1.Groups[1].Value -replace ',', '')
        if ($val -ge 30 -and $val -le 15000) { return $val }
    }
    return 0
}

function Compare-And-SaveSnapshot([string]$platformKey, [string[]]$todayIds) {
    $todaySet = New-Object 'System.Collections.Generic.HashSet[string]'
    if ($todayIds) {
        foreach ($x in $todayIds) {
            if ($x) { [void]$todaySet.Add([string]$x) }
        }
    }
    $todayUnique = New-Object 'string[]' $todaySet.Count
    $todaySet.CopyTo($todayUnique)
    $todaySnapPath      = Join-Path $SnapshotDir "$($platformKey)_$($TodayDate).json"
    $latestSnapMetaPath = Join-Path $SnapshotDir "$($platformKey)_latest.json"

    $prevFiles = @(Get-ChildItem -Path $SnapshotDir -Filter "$($platformKey)_*.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "$($platformKey)_latest.json" -and $_.Name -ne "$($platformKey)_$($TodayDate).json" } |
        Sort-Object Name)

    $newFromDiff = $null
    $soldFromDiff = $null
    $prevTotal = 0

    if ($prevFiles.Count -gt 0) {
        $prevFile = $prevFiles[$prevFiles.Count - 1]
        try {
            $prevObj = [System.IO.File]::ReadAllText($prevFile.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            $prevIds = [string[]]@($prevObj.ids)
            $prevTotal = $prevIds.Count
            $prevSet = New-Object 'System.Collections.Generic.HashSet[string]'
            foreach ($px in $prevIds) { if ($px) { [void]$prevSet.Add([string]$px) } }

            $newCnt = 0
            foreach ($id in $todayUnique) { if (-not $prevSet.Contains($id)) { $newCnt++ } }
            $soldCnt = 0
            foreach ($id in $prevIds) { if (-not $todaySet.Contains($id)) { $soldCnt++ } }
            $newFromDiff = $newCnt
            $soldFromDiff = $soldCnt
        } catch {}
    }

    $snapObj = [ordered]@{
        date      = $TodayDate
        updatedAt = $Timestamp
        count     = $todayUnique.Count
        ids       = $todayUnique
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $snapJson = $snapObj | ConvertTo-Json -Depth 4 -Compress
    [System.IO.File]::WriteAllText($todaySnapPath, $snapJson, $utf8NoBom)
    [System.IO.File]::WriteAllText($latestSnapMetaPath, $snapJson, $utf8NoBom)

    return [pscustomobject]@{
        PrevCount    = $prevTotal
        NewFromDiff  = $newFromDiff
        SoldFromDiff = $soldFromDiff
    }
}

function Build-BikePortfolioSummary([object[]]$items, [int]$exactUnder300, [int]$exactOver300) {
    $totalSample = $items.Count
    $u300Sample = 0; $o300Sample = 0
    $priceSum = 0; $priceCnt = 0
    $priceBands = [ordered]@{
        $PB_1 = 0
        $PB_2 = 0
        $PB_3 = 0
        $PB_4 = 0
        $PB_5 = 0
    }
    $regionCounts = @{}
    $modelCounts  = @{}
    $brandCounts  = @{}

    foreach ($it in $items) {
        if ($it.ccGroup -eq $KR_UNDER300) { $u300Sample++ } else { $o300Sample++ }
        $p = [int]$it.priceManwon
        if ($p -gt 0 -and $p -lt 50000) {
            $priceSum += $p
            $priceCnt++
            $pb = $it.priceBand
            if ($priceBands.Contains($pb)) { $priceBands[$pb] = [int]$priceBands[$pb] + 1 }
        }

        $r = if ($it.sido) { [string]$it.sido } else { $KR_ETC }
        $regionCounts[$r] = [int]$regionCounts[$r] + 1

        $m = if ($it.model -and $it.model -ne $KR_ETC) { [string]$it.model } else { $null }
        if ($m) { $modelCounts[$m] = [int]$modelCounts[$m] + 1 }

        $b = if ($it.manufacturer) { [string]$it.manufacturer } else { $KR_ETC }
        $brandCounts[$b] = [int]$brandCounts[$b] + 1
    }

    $avgPrice = if ($priceCnt -gt 0) { [int][math]::Round($priceSum / $priceCnt) } else { 0 }
    $ccTotal = $exactUnder300 + $exactOver300
    if ($ccTotal -le 0) {
        $exactUnder300 = $u300Sample
        $exactOver300  = $o300Sample
        $ccTotal       = [Math]::Max(1, $totalSample)
    }

    $topRegions = @($regionCounts.GetEnumerator() | Where-Object { $_.Key -ne $KR_ETC } | Sort-Object Value -Descending | Select-Object -First 8 | ForEach-Object { [ordered]@{ name = $_.Key; count = $_.Value } })
    $topModels  = @($modelCounts.GetEnumerator()  | Where-Object { $_.Key -ne $KR_ETC } | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object { [ordered]@{ name = $_.Key; count = $_.Value } })
    $topBrands  = @($brandCounts.GetEnumerator()  | Where-Object { $_.Key -ne $KR_ETC } | Sort-Object Value -Descending | Select-Object -First 8 | ForEach-Object { [ordered]@{ name = $_.Key; count = $_.Value } })

    return [ordered]@{
        sampleSize       = $totalSample
        pricedSampleSize = $priceCnt
        under300Count    = $exactUnder300
        over300Count     = $exactOver300
        under300Ratio    = [math]::Round(($exactUnder300 / $ccTotal) * 100, 1)
        over300Ratio     = [math]::Round(($exactOver300 / $ccTotal) * 100, 1)
        avgPriceManwon   = $avgPrice
        priceBands       = $priceBands
        topRegions       = $topRegions
        topModels        = $topModels
        topBrands        = $topBrands
    }
}

$allRawBikes = New-Object System.Collections.Generic.List[object]

# ==============================================================================
# 1. DAANGN MOTORCYCLES (https://www.daangn.com/kr/buy-sell/?search=오토바이)
#    Parallel Multi-Keyword Nationwide Enumeration + Sitemap Bike Slugs
# ==============================================================================
Write-Host "1. Collecting Daangn Nationwide C2C Motorcycles (Parallel Search + Sitemap)..." -ForegroundColor Yellow

$daangnKeywords = @(
    "오토바이", "스쿠터", "중고오토바이", "바이크 팝니다", "125cc", "배달오토바이",
    "혼다 pcx", "혼다 포르자", "슈퍼커브", "혼다 cbr", "혼다 cb", "혼다 레블", "혼다 adv", "골드윙",
    "야마하 nmax", "야마하 xmax", "티맥스", "야마하 r3", "야마하 mt", "야마하 xsr",
    "할리데이비슨", "스트리트글라이드", "로드글라이드", "아이언883", "브레이크아웃",
    "bmw gs", "bmw s1000", "bmw c400", "알나인티", "bmw r18",
    "가와사키 닌자", "가와사키 z", "스즈키 gsx", "브이스트롬", "버그만",
    "두카티", "베스파", "로얄엔필드", "트라이엄프", "ktm 듀크", "허스크바나", "보이저 125", "크루심", "킴코 다운타운"
)

$daangnFetchScript = {
    param([string]$kw)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        $enc = [uri]::EscapeDataString($kw)
        $req = [System.Net.HttpWebRequest]::Create("https://www.daangn.com/kr/buy-sell/?search=$enc")
        $req.Method = "GET"
        $req.UserAgent = "Mozilla/5.0"
        $req.Timeout = 20000
        $req.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        $resp = $req.GetResponse()
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $h = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
        $i1 = $h.IndexOf("window.__remixContext = ")
        if ($i1 -lt 0) { return @() }
        $i1 += 24
        $i2 = $h.IndexOf(";__remixContext.p", $i1)
        if ($i2 -lt 0) { return @() }
        $obj = ($h.Substring($i1, $i2 - $i1)) | ConvertFrom-Json
        return @($obj.state.loaderData.'routes/_buy-sell-shell'.buySellArticles)
    } catch {
        return @()
    }
}

$nonBikeFilterRx = [regex]::new('(?i)(전기자전거|자전거|픽시|로드바이크|엠티비|\bmtb\b|전동킥보드|킥보드|유모차|휠체어|헬멧|자켓|재킷|장갑|부츠|블랙박스|거치대|탑박스|리어백|새들백|머플러만|배기만|카울만|배터리만|타이어만|장난감|레고|프라모델|피규어|키링|스티커|상품권|바지|점퍼|조끼|안전화|보호대|인터콤|세나|카도|구합니다|삽니다|매입합니다|렌트카|승용차|가방|숄더백|토트백|크로스백|백팩|지갑|명품|프라다|구찌|샤넬|루이비통|디올|생로랑|발렌시아가|시계|운동화|스니커즈|패딩|골프)', [System.Text.RegularExpressions.RegexOptions]::Compiled)

$daangnSeenMap = @{}
$pool = [runspacefactory]::CreateRunspacePool(1, 8)
$pool.Open()
$jobs = New-Object System.Collections.Generic.List[object]
foreach ($kw in $daangnKeywords) {
    $ps = [powershell]::Create().AddScript($daangnFetchScript).AddArgument($kw)
    $ps.RunspacePool = $pool
    $jobs.Add([pscustomobject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() })
}

foreach ($j in $jobs) {
    try {
        $arts = $j.Pipe.EndInvoke($j.Handle)
        foreach ($a in $arts) {
            if (-not $a -or -not $a.id -or $daangnSeenMap.ContainsKey($a.id)) { continue }
            $prc = 0; [void][double]::TryParse([string]$a.price, [ref]$prc)
            if ($prc -lt 350000 -or $prc -gt 150000000) { continue }
            $tit = ([string]$a.title -replace '\s+', ' ').Trim()
            if ($nonBikeFilterRx.IsMatch($tit)) { continue }
            $daangnSeenMap[$a.id] = $a
        }
    } catch {}
    $j.Pipe.Dispose()
}
$pool.Close()
$pool.Dispose()

# Also scan Daangn buy-sell sitemap for additional active nationwide motorcycle slugs
$daangnSitemapExtraIds = New-Object System.Collections.Generic.List[string]
try {
    $tmpGz = Join-Path $env:TEMP "daangn_bikes_sm_$($PID).xml.gz"
    curl.exe -s -L -A "Mozilla/5.0" "https://www.daangn.com/kr/buy-sell/sitemap-detail.xml.gz" -o $tmpGz
    if (Test-Path $tmpGz) {
        $fs = [System.IO.File]::OpenRead($tmpGz)
        $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress)
        $sr = New-Object System.IO.StreamReader($gz, [System.Text.Encoding]::UTF8)
        $smXml = $sr.ReadToEnd()
        $sr.Close(); $gz.Close(); $fs.Close()
        Remove-Item $tmpGz -Force -ErrorAction SilentlyContinue

        $smBikeRx = [regex]::new('(?i)(오토바이|스쿠터|pcx|nmax|엔맥스|xmax|엑스맥스|tmax|티맥스|포르자|슈퍼커브|혼다-cb|혼다-c125|cbr\d|레블|골드윙|x-adv|adv125|adv160|adv350|야마하-r|mt-03|mt03|mt-07|mt07|mt-09|mt09|스즈키-gsx|버그만|브이스트롬|가와사키-닌자|할리데이비슨|두카티|베스파-gts|베스파-프리마베라|베스파-스프린트|트라이엄프-본네빌|로얄엔필드|보이저125|크루심|다운타운st|시티베스트|아퀼라)', [System.Text.RegularExpressions.RegexOptions]::Compiled)
        $locMs = [regex]::Matches($smXml, '<loc>https://www\.daangn\.com(/kr/buy-sell/[^<]+?)</loc>')
        foreach ($m in $locMs) {
            $relId = $m.Groups[1].Value
            if ($daangnSeenMap.ContainsKey($relId)) { continue }
            $slugDecoded = [uri]::UnescapeDataString(($relId -replace '^/kr/buy-sell/|-[a-z0-9]{10,14}/?$', ''))
            if ($smBikeRx.IsMatch($slugDecoded) -and -not $nonBikeFilterRx.IsMatch($slugDecoded)) {
                $daangnSitemapExtraIds.Add($relId)
            }
        }
    }
} catch { Write-Warning "Daangn buy-sell sitemap warning: $_" }

$daangnNormItems = New-Object System.Collections.Generic.List[object]
$daangnActiveIds = New-Object System.Collections.Generic.List[string]
$daangnUnder300 = 0; $daangnOver300 = 0
$daangnNewByCreated = 0; $daangnClosedSample = 0

foreach ($a in $daangnSeenMap.Values) {
    $stRaw = [string]$a.status
    if ($stRaw -eq 'Closed') {
        $daangnClosedSample++
        continue
    }
    $stKr = if ($stRaw -eq 'Reserved') { $KR_RESERVED } else { $KR_ONSALE }
    $cleanId = ([string]$a.id -replace '^/kr/buy-sell/|/$', '')
    $daangnActiveIds.Add("DG_" + $cleanId)

    $tit = ([string]$a.title -replace '\s+', ' ').Trim()
    $bodyTxt = ([string]$a.content -replace '\s+', ' ').Trim()
    $combinedTxt = "$tit $bodyTxt"

    $createdKst = ""
    if ($a.createdAt) {
        try {
            $dto = [DateTimeOffset]::Parse([string]$a.createdAt).ToOffset([TimeSpan]::FromHours(9))
            $createdKst = $dto.ToString("yyyy-MM-dd HH:mm")
            if ($dto.ToString("yyyy-MM-dd") -eq $TodayDate) { $daangnNewByCreated++ }
        } catch { $createdKst = [string]$a.createdAt }
    }

    $cc = Infer-DisplacementCc $combinedTxt $false
    $ccGrp = if ($cc -ge 300) { $daangnOver300++; $KR_OVER300 } else { $daangnUnder300++; $KR_UNDER300 }

    $prcWon = 0; [void][double]::TryParse([string]$a.price, [ref]$prcWon)
    $prcMan = [int][math]::Round($prcWon / 10000.0)

    $yr = ""
    $mYr = [regex]::Match($combinedTxt, '\b(20\d{2}|\d{2})\s*(?:년식|연식)')
    if ($mYr.Success) {
        $yv = $mYr.Groups[1].Value
        $yr = if ($yv.Length -eq 2) { "20$yv" } else { $yv }
    }

    $kmNum = 0
    $mKm = [regex]::Match($combinedTxt, '\b(\d{1,3}(?:,\d{3})+|\d{3,6})\s*(?:km|키로|킬로)')
    if ($mKm.Success) {
        $kmVal = ($mKm.Groups[1].Value -replace ',', '')
        if ($kmVal -match '^\d+$') { $kmNum = [int]$kmVal }
    }

    $lat = 0.0; $lng = 0.0
    if ($a.contentCoordinates -and $a.contentCoordinates.Count -gt 0) {
        $lat = [double]$a.contentCoordinates[0].latitude
        $lng = [double]$a.contentCoordinates[0].longitude
    }
    $regName = if ($a.region) { [string]$a.region.name } else { "" }
    $sido = Resolve-SidoFromCoords $lat $lng "$regName $tit"

    $brand = Resolve-Brand "" $combinedTxt ""
    $model = Resolve-ModelShort $brand "" $tit

    $row = [pscustomobject][ordered]@{
        collectedDate = $TodayDate
        platform      = (U "\uB2F9\uADFC(\uC624\uD1A0\uBC14\uC774)")
        bikeId        = "DG_" + $cleanId
        cc            = $cc
        ccGroup       = $ccGrp
        manufacturer  = $brand
        model         = $model
        fullTitle     = $tit
        year          = $yr
        mileageKm     = $kmNum
        priceManwon   = $prcMan
        priceBand     = Get-BikePriceBand $prcMan
        sido          = $sido
        sellType      = $KR_PERSONAL
        status        = $stKr
        registeredAt  = $createdKst
        url           = "https://www.daangn.com$($a.href)"
    }
    $daangnNormItems.Add($row)
    $allRawBikes.Add($row)
}

foreach ($extraRel in $daangnSitemapExtraIds) {
    $cleanExtra = ($extraRel -replace '^/kr/buy-sell/|/$', '')
    $daangnActiveIds.Add("DG_" + $cleanExtra)
    $slugTitle = ([uri]::UnescapeDataString(($cleanExtra -replace '-[a-z0-9]{10,14}$', '')) -replace '-', ' ').Trim()
    $ccExtra = Infer-DisplacementCc $slugTitle $false
    if ($ccExtra -ge 300) { $daangnOver300++ } else { $daangnUnder300++ }
}

$daangnTotalCount = $daangnUnder300 + $daangnOver300
$daangnPortfolio  = Build-BikePortfolioSummary $daangnNormItems.ToArray() $daangnUnder300 $daangnOver300
$daangnSnap       = Compare-And-SaveSnapshot "daangn_bike" $daangnActiveIds.ToArray()
$daangnNewToday   = if ($null -ne $daangnSnap.NewFromDiff -and $daangnSnap.NewFromDiff -gt $daangnNewByCreated) { $daangnSnap.NewFromDiff } else { $daangnNewByCreated }
$daangnSoldToday  = if ($null -ne $daangnSnap.SoldFromDiff -and $daangnSnap.SoldFromDiff -gt 0) { $daangnSnap.SoldFromDiff } else { $daangnClosedSample }
$daangnTurnoverPct= if ($daangnTotalCount -gt 0) { [math]::Round(($daangnSoldToday / $daangnTotalCount) * 100, 2) } else { 0 }

Write-Host "   -> Daangn Motorcycles Total=$daangnTotalCount (<=299cc: $daangnUnder300, >=300cc: $daangnOver300), NewToday=$daangnNewToday, RichSample=$($daangnNormItems.Count)" -ForegroundColor Green

# ==============================================================================
# 2. REITWAGEN (https://www.reitwagen.co.kr/ - Native BAREE Used Bikes)
# ==============================================================================
Write-Host "2. Collecting Reitwagen Native Used Bikes (ORPC API + Sitemap)..." -ForegroundColor Yellow

function Invoke-ReitwagenOrpc([string]$endpoint, [hashtable]$payload) {
    $bodyStr = (@{ json = $payload } | ConvertTo-Json -Depth 6 -Compress)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyStr)
    $req = [System.Net.HttpWebRequest]::Create("https://api.reitwagen.co.kr/api/orpc/$endpoint")
    $req.Method = "POST"
    $req.ContentType = "application/json"
    $req.UserAgent = "Mozilla/5.0"
    $req.Timeout = 20000
    $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
    $resp = $req.GetResponse()
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
    $txt = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($txt | ConvertFrom-Json).json
}

$rwTotalCount = 0; $rwOver300Count = 0; $rwUnder300Count = 0; $rwCertifiedCount = 0
$rwNormItems = New-Object System.Collections.Generic.List[object]
$rwNewByPostedAt = 0
$rwSeenIds = @{}

try {
    $rwTotalCount     = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("BAREE") }).count
    $rwOver300Count   = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("BAREE"); minDisplacement=300 }).count
    $rwUnder300Count  = [Math]::Max(0, $rwTotalCount - $rwOver300Count)
    $rwCertifiedCount = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("BAREE_CERTIFIED") }).count

    for ($pg = 0; $pg -lt 40; $pg++) {
        $res = Invoke-ReitwagenOrpc "search/list" @{
            page       = $pg
            skip       = ($pg * 20)
            sourceType = @("BAREE")
            sort       = @{ field = "postedAt"; order = "desc" }
        }
        if (-not $res.data -or $res.data.Count -eq 0) { break }
        foreach ($entry in $res.data) {
            $g = $entry.goods
            if (-not $g -or -not $g._id -or $rwSeenIds.ContainsKey($g._id)) { continue }
            $rwSeenIds[$g._id] = $true

            $postedKst = ""
            if ($g.postedAt) {
                try {
                    $dto = [DateTimeOffset]::Parse([string]$g.postedAt).ToOffset([TimeSpan]::FromHours(9))
                    $postedKst = $dto.ToString("yyyy-MM-dd HH:mm")
                    if ($dto.ToString("yyyy-MM-dd") -eq $TodayDate) { $rwNewByPostedAt++ }
                } catch { $postedKst = [string]$g.postedAt }
            }

            $cc = [int]$g.cylinderCapacity
            $ccGrp = if ($cc -ge 300) { $KR_OVER300 } else { $KR_UNDER300 }
            $prcMan = [int][math]::Round(([double]$g.salePrice) / 10000.0)
            $brand = Resolve-Brand "" ([string]$g.title) ([string]$g.brandId)
            $model = Resolve-ModelShort $brand "" ([string]$g.title)
            $sido  = Normalize-Region ([string]$g.locationCategory + " " + [string]$g.address)

            $row = [pscustomobject][ordered]@{
                collectedDate = $TodayDate
                platform      = (U "\uB77C\uC774\uD2B8\uBC14\uAC90")
                bikeId        = [string]$g._id
                cc            = $cc
                ccGroup       = $ccGrp
                manufacturer  = $brand
                model         = $model
                fullTitle     = [string]$g.title
                year          = [string]$g.modelYear
                mileageKm     = [int]$g.mileage
                priceManwon   = $prcMan
                priceBand     = Get-BikePriceBand $prcMan
                sido          = $sido
                sellType      = $KR_PERSONAL
                status        = $KR_ONSALE
                registeredAt  = $postedKst
                url           = "https://www.reitwagen.co.kr/products/detail/$($g.sourceId)"
            }
            $rwNormItems.Add($row)
            $allRawBikes.Add($row)
        }
    }
} catch { Write-Warning "Reitwagen API error: $_" }

$rwSitemapIds = New-Object System.Collections.Generic.List[string]
try {
    for ($si = 0; $si -le 1; $si++) {
        $smXml = (curl.exe -s -L -A "Mozilla/5.0" "https://www.reitwagen.co.kr/server-sitemap/$si.xml") -join "`n"
        $mLocs = [regex]::Matches($smXml, 'https://www\.reitwagen\.co\.kr/products/detail/(\d+)')
        foreach ($m in $mLocs) { $rwSitemapIds.Add("RW" + $m.Groups[1].Value) }
    }
} catch { Write-Warning "Reitwagen sitemap error: $_" }

$rwPortfolio   = Build-BikePortfolioSummary $rwNormItems.ToArray() $rwUnder300Count $rwOver300Count
$rwSnapIds     = if ($rwSitemapIds.Count -gt 0) { $rwSitemapIds.ToArray() } else { @($rwSeenIds.Keys) }
$rwSnap        = Compare-And-SaveSnapshot "reitwagen" $rwSnapIds
$rwNewToday    = if ($null -ne $rwSnap.NewFromDiff -and $rwSnap.PrevCount -ge 10000 -and $rwSnap.NewFromDiff -gt $rwNewByPostedAt) { $rwSnap.NewFromDiff } else { $rwNewByPostedAt }
$rwSoldToday   = if ($null -ne $rwSnap.SoldFromDiff -and $rwSnap.PrevCount -ge 10000) { $rwSnap.SoldFromDiff } else { 0 }
$rwTurnoverPct = if ($rwTotalCount -gt 0) { [math]::Round(($rwSoldToday / $rwTotalCount) * 100, 2) } else { 0 }

Write-Host "   -> Reitwagen Total=$rwTotalCount (<=299cc: $rwUnder300Count, >=300cc: $rwOver300Count), NewToday=$rwNewToday, SoldToday=$rwSoldToday" -ForegroundColor Green

# ==============================================================================
# 3. PASSO BIKE (http://bike.passo.co.kr/bike/ - Used Motorcycle Listings)
# ==============================================================================
Write-Host "3. Collecting Passo Bike Used Listings (Cloud-Accessible Real-Time Feed)..." -ForegroundColor Yellow

$passoAllUsedCount = 0; $passoUnder300Count = 0; $passoOver300Count = 0; $passoTotalCount = 0
$passoNormItems = New-Object System.Collections.Generic.List[object]
$passoSeenIds = @{}
$passoNewByPostedAt = 0

try {
    $passoTotalCount    = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("PASSO") }).count
    $passoOver300Count  = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("PASSO"); minDisplacement=300 }).count
    $passoUnder300Count = [Math]::Max(0, $passoTotalCount - $passoOver300Count)
    $passoAllUsedCount  = $passoTotalCount

    for ($pg = 0; $pg -lt 40; $pg++) {
        $res = Invoke-ReitwagenOrpc "search/list" @{
            page       = $pg
            skip       = ($pg * 20)
            sourceType = @("PASSO")
            sort       = @{ field = "postedAt"; order = "desc" }
        }
        if (-not $res.data -or $res.data.Count -eq 0) { break }
        foreach ($entry in $res.data) {
            $g = $entry.goods
            if (-not $g) { continue }
            $pIdx = if ($entry.url -and $entry.url -match 'idx=(\d+)') { "PS" + $Matches[1] } else { "PS" + [string]$g._id }
            if ($passoSeenIds.ContainsKey($pIdx)) { continue }
            $passoSeenIds[$pIdx] = $true

            $postedKst = ""
            if ($g.postedAt) {
                try {
                    $dto = [DateTimeOffset]::Parse([string]$g.postedAt).ToOffset([TimeSpan]::FromHours(9))
                    $postedKst = $dto.ToString("yyyy-MM-dd HH:mm")
                    if ($dto.ToString("yyyy-MM-dd") -eq $TodayDate) { $passoNewByPostedAt++ }
                } catch { $postedKst = [string]$g.postedAt }
            }

            $rawTitle = ([string]$g.title -replace '\([A-Za-z0-9\-\s&]+\)', ' ' -replace '\s+', ' ').Trim()
            $brand = Resolve-Brand "" $rawTitle ([string]$g.brandId)
            $model = Resolve-ModelShort $brand "" $rawTitle
            $cc = if ($null -ne $g.cylinderCapacity -and [int]$g.cylinderCapacity -gt 0) { [int]$g.cylinderCapacity } else { Infer-DisplacementCc $rawTitle $false }
            $ccGrp = if ($cc -ge 300) { $KR_OVER300 } else { $KR_UNDER300 }
            $prcMan = [int][math]::Round(([double]$g.salePrice) / 10000.0)
            $sido = Normalize-Region ([string]$g.locationCategory + " " + [string]$g.address)
            $pUrl = if ($entry.url) { [string]$entry.url } else { "http://bike.passo.co.kr/bike/" }

            $row = [pscustomobject][ordered]@{
                collectedDate = $TodayDate
                platform      = (U "\uD30C\uC3D8\uBC14\uC774\uD06C")
                bikeId        = $pIdx
                cc            = $cc
                ccGroup       = $ccGrp
                manufacturer  = $brand
                model         = $model
                fullTitle     = $rawTitle
                year          = [string]$g.modelYear
                mileageKm     = [int]$g.mileage
                priceManwon   = $prcMan
                priceBand     = Get-BikePriceBand $prcMan
                sido          = $sido
                sellType      = $KR_PERSONAL
                status        = $KR_ONSALE
                registeredAt  = $postedKst
                url           = $pUrl
            }
            $passoNormItems.Add($row)
            $allRawBikes.Add($row)
        }
    }
} catch { Write-Warning "Passo error: $_" }

if ($passoTotalCount -eq 0) { $passoTotalCount = $passoNormItems.Count }
$passoPortfolio   = Build-BikePortfolioSummary $passoNormItems.ToArray() $passoUnder300Count $passoOver300Count
$passoSnap        = Compare-And-SaveSnapshot "passo_used" @($passoSeenIds.Keys)
$passoNewToday    = $passoNewByPostedAt
$passoSoldToday   = if ($null -ne $passoSnap.SoldFromDiff) { $passoSnap.SoldFromDiff } else { 0 }
$passoTurnoverPct = if ($passoTotalCount -gt 0) { [math]::Round(($passoSoldToday / $passoTotalCount) * 100, 2) } else { 0 }

Write-Host "   -> Passo Used Total=$passoTotalCount (<=299cc: $passoUnder300Count, >=300cc: $passoOver300Count), NewToday=$passoNewToday, SoldToday=$passoSoldToday" -ForegroundColor Green

# ==============================================================================
# 4. BATUMAE NAVER CAFE (https://cafe.naver.com/bikecargogo - CafeId: 10312966)
# ==============================================================================
Write-Host "4. Collecting Batumae (Naver Cafe bikecargogo) 30-Day Active Personal C2C Listings..." -ForegroundColor Yellow

$batumaeMenus = @(
    @{ menuId = 351; forceUnder125 = $false; sellType = $KR_PERSONAL },
    @{ menuId = 352; forceUnder125 = $true;  sellType = $KR_PERSONAL },
    @{ menuId = 133; forceUnder125 = $false; sellType = $KR_ESCROW   },
    @{ menuId = 144; forceUnder125 = $true;  sellType = $KR_ESCROW   }
)

$btSeenIds = @{}
$btActiveMap = @{}
$btNormItems = New-Object System.Collections.Generic.List[object]
$btUnder300Count = 0; $btOver300Count = 0
$btNewTodayCount = 0; $btSoldTaggedToday = 0; $btTraded30dCount = 0

foreach ($bm in $batumaeMenus) {
    $reachCutoff = $false
    for ($pg = 1; $pg -le 85; $pg++) {
        if ($reachCutoff) { break }
        try {
            $u = "https://apis.naver.com/cafe-web/cafe2/ArticleListV2dot1.json?search.clubid=10312966&search.menuid=$($bm.menuId)&search.page=$pg&search.perPage=50"
            $req = [System.Net.HttpWebRequest]::Create($u)
            $req.Method = "GET"
            $req.UserAgent = "Mozilla/5.0"
            $req.Timeout = 15000
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
            $jsonObj = ($sr.ReadToEnd() | ConvertFrom-Json)
            $sr.Close(); $resp.Close()

            $artList = $jsonObj.message.result.articleList
            if (-not $artList -or $artList.Count -eq 0) { break }

            foreach ($a in $artList) {
                $aid = [string]$a.articleId
                if (-not $aid -or $btSeenIds.ContainsKey($aid)) { continue }
                $btSeenIds[$aid] = $true

                $tsMs = [long]$a.writeDateTimestamp
                if ($tsMs -lt $Cutoff30dMs) {
                    $reachCutoff = $true
                    continue
                }

                $dtObj = [DateTimeOffset]::FromUnixTimeMilliseconds($tsMs).ToOffset([TimeSpan]::FromHours(9))
                $wDate = $dtObj.ToString("yyyy-MM-dd")
                $wFull = $dtObj.ToString("yyyy-MM-dd HH:mm")

                $subj = ([System.Net.WebUtility]::HtmlDecode([string]$a.subject) -replace '\s+', ' ').Trim()
                $head = ([System.Net.WebUtility]::HtmlDecode([string]$a.headName)).Trim()

                $saleStat = if ($a.productSale) { [string]$a.productSale.saleStatus } else { "" }
                $isSold = ($subj -match '판매\s*완료|거래\s*완료|판완|완료됨|판매\s*중지된') -or ($head -match '완료') -or ($saleStat -eq 'SOLD_OUT')

                if ($wDate -eq $TodayDate) {
                    $btNewTodayCount++
                    if ($isSold) { $btSoldTaggedToday++ }
                }

                if ($isSold) {
                    $btTraded30dCount++
                    continue
                }

                $btActiveMap[$aid] = $wDate

                $cc = Infer-DisplacementCc $subj $bm.forceUnder125 400
                $ccGrp = if ($cc -ge 300) { $btOver300Count++; $KR_OVER300 } else { $btUnder300Count++; $KR_UNDER300 }

                $prcMan = 0
                if ($a.cost -and [double]$a.cost -ge 300000) {
                    $prcMan = [int][math]::Round(([double]$a.cost) / 10000.0)
                } else {
                    $prcMan = Parse-TitlePriceManwon $subj
                }

                $yr = ""
                $mYr = [regex]::Match($subj, '\b(20\d{2}|\d{2})\s*년식?')
                if ($mYr.Success) {
                    $yVal = $mYr.Groups[1].Value
                    $yr = if ($yVal.Length -eq 2) { "20$yVal" } else { $yVal }
                }

                $brand = Resolve-Brand "" $subj ""
                $model = Resolve-ModelShort $brand "" $subj
                $sido  = Normalize-Region "$head $subj"

                $row = [pscustomobject][ordered]@{
                    collectedDate = $TodayDate
                    platform      = (U "\uBC14\uD29C\uB9E4(\uB124\uC774\uBC84\uCE74\uD398)")
                    bikeId        = "BT$aid"
                    cc            = $cc
                    ccGroup       = $ccGrp
                    manufacturer  = $brand
                    model         = $model
                    fullTitle     = $subj
                    year          = $yr
                    mileageKm     = 0
                    priceManwon   = $prcMan
                    priceBand     = Get-BikePriceBand $prcMan
                    sido          = $sido
                    sellType      = $bm.sellType
                    status        = $KR_ONSALE
                    registeredAt  = $wFull
                    url           = "https://cafe.naver.com/bikecargogo/$aid"
                }
                $btNormItems.Add($row)
                $allRawBikes.Add($row)
            }
        } catch {
            Write-Warning "Batumae menu $($bm.menuId) page $pg error: $_"
            break
        }
    }
}

$hasNaverAuth = ($env:NAVER_NID_AUT -and $env:NAVER_NID_SES)
if ($hasNaverAuth) {
    foreach ($item in ($btNormItems | Where-Object { $_.priceManwon -eq 0 } | Select-Object -First 80)) {
        try {
            $rawId = $item.bikeId -replace '^BT', ''
            $artUrl = "https://apis.naver.com/cafe-web/cafe-articleapi/v2.1/cafes/10312966/articles/$rawId"
            $req = [System.Net.HttpWebRequest]::Create($artUrl)
            $req.Method = "GET"; $req.UserAgent = "Mozilla/5.0"
            $req.Headers.Add("Cookie", "NID_AUT=$($env:NAVER_NID_AUT); NID_SES=$($env:NAVER_NID_SES)")
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
            $artJson = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
            $pMatch = [regex]::Match($artJson, '(?:판매가격|희망가격|가격)[^0-9]{0,20}(\d{1,2},?\d{3}|\d{2,4})\s*만|(\d{1,3}(?:,\d{3}){2})\s*원')
            if ($pMatch.Success) {
                if ($pMatch.Groups[1].Value) {
                    $item.priceManwon = [int]($pMatch.Groups[1].Value -replace ',', '')
                } elseif ($pMatch.Groups[2].Value) {
                    $item.priceManwon = [int][math]::Round(([double]($pMatch.Groups[2].Value -replace ',', '')) / 10000.0)
                }
                $item.priceBand = Get-BikePriceBand $item.priceManwon
            }
        } catch {}
    }
}

$btSnapTodayPath  = Join-Path $SnapshotDir "batumae_$($TodayDate).json"
$btSnapLatestPath = Join-Path $SnapshotDir "batumae_latest.json"
$btPrevFiles = @(Get-ChildItem -Path $SnapshotDir -Filter "batumae_*.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "batumae_latest.json" -and $_.Name -ne "batumae_$($TodayDate).json" } |
    Sort-Object Name)

$btSoldFromDiff = $null
if ($btPrevFiles.Count -gt 0) {
    $prevF = $btPrevFiles[$btPrevFiles.Count - 1]
    try {
        $prevObj = [System.IO.File]::ReadAllText($prevF.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $soldCnt = 0
        foreach ($entry in $prevObj.items) {
            if ($entry.writeDate -ge $Cutoff29dDate -and -not $btActiveMap.ContainsKey([string]$entry.id)) {
                $soldCnt++
            }
        }
        $btSoldFromDiff = $soldCnt
    } catch {}
}

$btSnapItems = @($btActiveMap.GetEnumerator() | ForEach-Object { [ordered]@{ id = $_.Key; writeDate = $_.Value } })
$btSnapObj = [ordered]@{
    date      = $TodayDate
    updatedAt = $Timestamp
    count     = $btActiveMap.Count
    items     = $btSnapItems
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$btSnapJson = $btSnapObj | ConvertTo-Json -Depth 4 -Compress
[System.IO.File]::WriteAllText($btSnapTodayPath, $btSnapJson, $utf8NoBom)
[System.IO.File]::WriteAllText($btSnapLatestPath, $btSnapJson, $utf8NoBom)

$btTotalCount  = $btUnder300Count + $btOver300Count
$btPortfolio   = Build-BikePortfolioSummary $btNormItems.ToArray() $btUnder300Count $btOver300Count
$btNewToday    = $btNewTodayCount
$btSoldToday   = if ($null -ne $btSoldFromDiff -and $btSoldFromDiff -gt 0) { $btSoldFromDiff } else { $btSoldTaggedToday }
$btTurnoverPct = if ($btTotalCount -gt 0) { [math]::Round(($btSoldToday / $btTotalCount) * 100, 2) } else { 0 }

Write-Host "   -> Batumae 30d Active Personal Total=$btTotalCount (<=299cc: $btUnder300Count, >=300cc: $btOver300Count), NewToday=$btNewToday, SoldToday=$btSoldToday" -ForegroundColor Green

# ==============================================================================
# 5. K CAR (Service Not Operated - Placeholder Slot Only, No Numeric Values)
# ==============================================================================
Write-Host "5. K Car Bike Slot: Reserved as placeholder (Service not active, numbers omitted)." -ForegroundColor DarkGray

# ==============================================================================
# 6. SAVE UNIFIED VEHICLE-LEVEL RAW CSV
# ==============================================================================
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$rawCsvToday  = Join-Path $RawDir "raw_bikes_$($TodayDate).csv"
$rawCsvLatest = Join-Path $RawDir "raw_bikes_latest.csv"
$rawHeader = U "\uC218\uC9D1\uC77C\uC790,\uD50C\uB7AB\uD3FC,\uB9E4\uBB3CID,\uBC30\uAE30\uB7C9_cc,\uBC30\uAE30\uB7C9\uAD6C\uBD84,\uBE0C\uB79C\uB4DC_\uC81C\uC870\uC0AC,\uBAA8\uB378\uBA85,\uC804\uCCB4\uB9E4\uBB3C\uBA85,\uC5F0\uC2DD,\uC8FC\uD589\uAC70\uB9AC_km,\uD310\uB9E4\uAC00\uACA9_\uB9CC\uC6D0,\uAC00\uACA9\uB300\uAD6C\uAC04,\uC9C0\uC5ED_\uC2DC\uB3C4,\uAC70\uB798\uC720\uD615,\uD310\uB9E4\uC0C1\uD0DC,\uB4F1\uB85D\uC77C\uC2DC,\uC0C1\uC138URL"
$rawLines = New-Object System.Collections.Generic.List[string]
$rawLines.Add($rawHeader)
foreach ($v in $allRawBikes) {
    $prcText = if ($v.priceManwon -gt 0) { [string]$v.priceManwon } else { "" }
    $line = "{0},`"{1}`",`"{2}`",{3},`"{4}`",`"{5}`",`"{6}`",`"{7}`",`"{8}`",{9},{10},`"{11}`",`"{12}`",`"{13}`",`"{14}`",`"{15}`",`"{16}`"" -f `
        $v.collectedDate, $v.platform, ($v.bikeId -replace '"','""'), $v.cc, $v.ccGroup, `
        ($v.manufacturer -replace '"','""'), ($v.model -replace '"','""'), ($v.fullTitle -replace '"','""'), `
        $v.year, $v.mileageKm, $prcText, $v.priceBand, ($v.sido -replace '"','""'), `
        $v.sellType, $v.status, $v.registeredAt, $v.url
    $rawLines.Add($line)
}
[System.IO.File]::WriteAllLines($rawCsvToday, $rawLines, $utf8Bom)
[System.IO.File]::WriteAllLines($rawCsvLatest, $rawLines, $utf8Bom)

# ==============================================================================
# 7. MERGE DAILY RECORD & SAVE PORTFOLIO + DASHBOARD JS BUNDLE
# ==============================================================================
$records = @()
if (Test-Path $JsonPath) {
    try {
        $existingRaw = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8)
        $parsed = $existingRaw | ConvertFrom-Json
        if ($parsed -is [System.Array]) { $records = @($parsed) }
        elseif ($null -ne $parsed) { $records = @($parsed) }
    } catch { $records = @() }
}

$defaultMemo = U "5\uB300 \uC624\uD1A0\uBC14\uC774 \uD50C\uB7AB\uD3FC (\uB2F9\uADFC \u00B7 \uB77C\uC774\uD2B8\uBC14\uAC90 \u00B7 \uD30C\uC3D8 \u00B7 \uBC14\uD29C\uB9E4 \u00B7 \uCF00\uC774\uCE74 \uBE48\uCE78) \uC790\uB3D9 \uC218\uC9D1"

$newEntry = [ordered]@{
    date                    = $TodayDate
    updatedAt               = $Timestamp
    rawBikeCount            = $allRawBikes.Count
    # 1. Daangn Motorcycles (C2C Direct)
    daangnBikeCount         = $daangnTotalCount
    daangnUnder300Count     = $daangnUnder300
    daangnOver300Count      = $daangnOver300
    daangnOnSaleCount       = $daangnTotalCount
    daangnNewCount          = $daangnNewToday
    daangnSoldCount         = $daangnSoldToday
    daangnTurnoverPct       = $daangnTurnoverPct
    daangnAvgPrice          = $daangnPortfolio.avgPriceManwon
    daangnDiff              = 0
    # 2. Reitwagen (Native BAREE Used)
    reitwagenCount          = $rwTotalCount
    reitwagenUnder300Count  = $rwUnder300Count
    reitwagenOver300Count   = $rwOver300Count
    reitwagenCertifiedCount = $rwCertifiedCount
    reitwagenOnSaleCount    = $rwTotalCount
    reitwagenNewCount       = $rwNewToday
    reitwagenSoldCount      = $rwSoldToday
    reitwagenTurnoverPct    = $rwTurnoverPct
    reitwagenAvgPrice       = $rwPortfolio.avgPriceManwon
    reitwagenDiff           = 0
    # 3. Passo Bike (Used)
    passoCount              = $passoTotalCount
    passoUnder300Count      = $passoUnder300Count
    passoOver300Count       = $passoOver300Count
    passoAllUsedCount       = $passoAllUsedCount
    passoOnSaleCount        = $passoTotalCount
    passoNewCount           = $passoNewToday
    passoSoldCount          = $passoSoldToday
    passoTurnoverPct        = $passoTurnoverPct
    passoAvgPrice           = $passoPortfolio.avgPriceManwon
    passoDiff               = 0
    # 4. Batumae Naver Cafe (Personal C2C & Safety-Pay 30d Active)
    batumaeCount            = $btTotalCount
    batumaeUnder300Count    = $btUnder300Count
    batumaeOver300Count     = $btOver300Count
    batumaeTraded30dCount   = $btTraded30dCount
    batumaeOnSaleCount      = $btTotalCount
    batumaeNewCount         = $btNewToday
    batumaeSoldCount        = $btSoldToday
    batumaeTurnoverPct      = $btTurnoverPct
    batumaeAvgPrice         = $btPortfolio.avgPriceManwon
    batumaeDiff             = 0
    # 5. K Car (Placeholder - Not Operated, null values)
    kcarStatus              = "NOT_OPERATED"
    kcarCount               = $null
    kcarUnder300Count       = $null
    kcarOver300Count        = $null
    kcarNewCount            = $null
    kcarSoldCount           = $null
    kcarTurnoverPct         = $null
    kcarAvgPrice            = $null
    source                  = "auto"
    memo                    = $defaultMemo
}

$filtered = @($records | Where-Object { $_.date -ne $TodayDate })
$filtered += [pscustomobject]$newEntry
$sortedRecords = @($filtered | Sort-Object date)

for ($i = 0; $i -lt $sortedRecords.Count; $i++) {
    $cur = $sortedRecords[$i]
    if (-not $cur.PSObject.Properties['daangnDiff']) {
        $cur | Add-Member -NotePropertyName 'daangnDiff' -NotePropertyValue 0 -Force
    }
    if ($i -eq 0) {
        $cur.daangnDiff    = 0
        $cur.reitwagenDiff = 0
        $cur.passoDiff     = 0
        $cur.batumaeDiff   = 0
    } else {
        $prev = $sortedRecords[$i - 1]
        $cur.daangnDiff    = if ($null -ne $prev.daangnBikeCount -and [int]$prev.daangnBikeCount -gt 0) { [int]$cur.daangnBikeCount - [int]$prev.daangnBikeCount } else { 0 }
        $cur.reitwagenDiff = [int]$cur.reitwagenCount - [int]$prev.reitwagenCount
        $cur.passoDiff     = [int]$cur.passoCount     - [int]$prev.passoCount
        $cur.batumaeDiff   = [int]$cur.batumaeCount   - [int]$prev.batumaeCount
    }
}

$jsonOutput = ConvertTo-Json -InputObject $sortedRecords -Depth 6
if ($sortedRecords.Count -eq 1 -and -not $jsonOutput.TrimStart().StartsWith("[")) {
    $jsonOutput = "[`r`n" + $jsonOutput + "`r`n]"
}
[System.IO.File]::WriteAllText($JsonPath, $jsonOutput, $utf8NoBom)

# Save Daily Summary CSV (5 Platforms; K Car columns reserved & left blank)
$csvHeader = U (
    "\uC77C\uC790,\uC218\uC9D1\uC2DC\uAC01," +
    "\uB2F9\uADFC_\uC804\uCCB4,\uB2F9\uADFC_300cc\uC774\uD558,\uB2F9\uADFC_300cc\uC774\uC0C1,\uB2F9\uADFC_\uC2E0\uADDC\uB4F1\uB85D,\uB2F9\uADFC_\uC2E0\uADDC\uD310\uB9E4,\uB2F9\uADFC_\uD68C\uC804\uC728(%),\uB2F9\uADFC_\uD3C9\uADE0\uAC00(\uB9CC\uC6D0)," +
    "\uB77C\uC774\uD2B8\uBC14\uAC90_\uC804\uCCB4,\uB77C\uC774\uD2B8\uBC14\uAC90_300cc\uC774\uD558,\uB77C\uC774\uD2B8\uBC14\uAC90_300cc\uC774\uC0C1,\uB77C\uC774\uD2B8\uBC14\uAC90_\uC2E0\uADDC\uB4F1\uB85D,\uB77C\uC774\uD2B8\uBC14\uAC90_\uC2E0\uADDC\uD310\uB9E4,\uB77C\uC774\uD2B8\uBC14\uAC90_\uD68C\uC804\uC728(%),\uB77C\uC774\uD2B8\uBC14\uAC90_\uD3C9\uADE0\uAC00(\uB9CC\uC6D0)," +
    "\uD30C\uC3D8_\uC804\uCCB4,\uD30C\uC3D8_300cc\uC774\uD558,\uD30C\uC3D8_300cc\uC774\uC0C1,\uD30C\uC3D8_\uC2E0\uADDC\uB4F1\uB85D,\uD30C\uC3D8_\uC2E0\uADDC\uD310\uB9E4,\uD30C\uC3D8_\uD68C\uC804\uC728(%),\uD30C\uC3D8_\uD3C9\uADE0\uAC00(\uB9CC\uC6D0)," +
    "\uBC14\uD29C\uB9E4_\uC804\uCCB4(30\uC77C\uD65C\uC131),\uBC14\uD29C\uB9E4_300cc\uC774\uD558,\uBC14\uD29C\uB9E4_300cc\uC774\uC0C1,\uBC14\uD29C\uB9E4_\uC2E0\uADDC\uB4F1\uB85D,\uBC14\uD29C\uB9E4_\uC2E0\uADDC\uD310\uB9E4,\uBC14\uD29C\uB9E4_\uD68C\uC804\uC728(%),\uBC14\uD29C\uB9E4_\uD3C9\uADE0\uAC00(\uB9CC\uC6D0)," +
    "\uCF00\uC774\uCE74_\uC804\uCCB4,\uCF00\uC774\uCE74_300cc\uC774\uD558,\uCF00\uC774\uCE74_300cc\uC774\uC0C1,\uCF00\uC774\uCE74_\uC2E0\uADDC\uB4F1\uB85D,\uCF00\uC774\uCE74_\uC2E0\uADDC\uD310\uB9E4,\uCF00\uC774\uCE74_\uD68C\uC804\uC728(%),\uCF00\uC774\uCE74_\uD3C9\uADE0\uAC00(\uB9CC\uC6D0)"
)
$csvLines = New-Object System.Collections.Generic.List[string]
$csvLines.Add($csvHeader)
foreach ($r in $sortedRecords) {
    $dgTot = if ($null -ne $r.daangnBikeCount) { $r.daangnBikeCount } else { "" }
    $dgU   = if ($null -ne $r.daangnUnder300Count) { $r.daangnUnder300Count } else { "" }
    $dgO   = if ($null -ne $r.daangnOver300Count) { $r.daangnOver300Count } else { "" }
    $dgN   = if ($null -ne $r.daangnNewCount) { $r.daangnNewCount } else { "" }
    $dgS   = if ($null -ne $r.daangnSoldCount) { $r.daangnSoldCount } else { "" }
    $dgT   = if ($null -ne $r.daangnTurnoverPct) { $r.daangnTurnoverPct } else { "" }
    $dgP   = if ($null -ne $r.daangnAvgPrice) { $r.daangnAvgPrice } else { "" }

    $line = "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15},{16},{17},{18},{19},{20},{21},{22},{23},{24},{25},{26},{27},{28},{29},,,,,,," -f `
        $r.date, $r.updatedAt, `
        $dgTot, $dgU, $dgO, $dgN, $dgS, $dgT, $dgP, `
        $r.reitwagenCount, $r.reitwagenUnder300Count, $r.reitwagenOver300Count, $r.reitwagenNewCount, $r.reitwagenSoldCount, $r.reitwagenTurnoverPct, $r.reitwagenAvgPrice, `
        $r.passoCount, $r.passoUnder300Count, $r.passoOver300Count, $r.passoNewCount, $r.passoSoldCount, $r.passoTurnoverPct, $r.passoAvgPrice, `
        $r.batumaeCount, $r.batumaeUnder300Count, $r.batumaeOver300Count, $r.batumaeNewCount, $r.batumaeSoldCount, $r.batumaeTurnoverPct, $r.batumaeAvgPrice
    $csvLines.Add($line)
}
[System.IO.File]::WriteAllLines($CsvPath, $csvLines, $utf8Bom)

$portfolioBundle = [ordered]@{
    updatedAt = $Timestamp
    daangn    = $daangnPortfolio
    reitwagen = $rwPortfolio
    passo     = $passoPortfolio
    batumae   = $btPortfolio
    kcar      = [ordered]@{
        notOperated = $true
        sampleSize  = 0
    }
}
$portfolioJson = $portfolioBundle | ConvertTo-Json -Depth 6
$balancedPreview = @(
    @($daangnNormItems | Select-Object -First 150) +
    @($rwNormItems     | Select-Object -First 150) +
    @($passoNormItems  | Select-Object -First 150) +
    @($btNormItems     | Select-Object -First 150)
)
$rawPreview = $balancedPreview | ConvertTo-Json -Depth 4

$jsContent = @"
// Auto-generated 5-Platform Used Motorcycle Apple-to-Apple Intelligence Bundle ($Timestamp)
window.COMPETITOR_TREND_LAST_UPDATED = "$Timestamp";
window.COMPETITOR_TREND_DATA = $jsonOutput;
window.COMPETITOR_PORTFOLIO_DATA = $portfolioJson;
window.COMPETITOR_RAW_PREVIEW = $rawPreview;
window.COMPETITOR_RAW_TOTAL_COUNT = $($allRawBikes.Count);
"@
[System.IO.File]::WriteAllText($JsPath, $jsContent, $utf8NoBom)

Write-Host "[$Timestamp] Completed! Total RAW Bikes Saved: $($allRawBikes.Count)" -ForegroundColor Cyan
Write-Host "  - RAW Bikes CSV    : $rawCsvToday"
Write-Host "  - Daily Summary CSV: $CsvPath"
