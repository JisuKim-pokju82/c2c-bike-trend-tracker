# 5-Platform Used Motorcycle Apple-to-Apple Daily Collector & Master DB Builder (10:00 KST)
# Platforms:
#   1) Daangn Bike (https://www.daangn.com/kr/buy-sell/ - 238 Fine-Grained Keywords + Sitemap Minimum Floor)
#   2) Reitwagen (https://www.reitwagen.co.kr/ - Native BAREE used listings, excluding external PASSO crawl)
#   3) Passo Bike (http://bike.passo.co.kr/bike/ - Used motorcycle listings, excluding new bike promotions)
#   4) Batumae Naver Cafe (https://cafe.naver.com/bikecargogo - Personal C2C & Safety-Pay 30-day active listings)
#   5) K Car (Service not currently active - placeholder slot only, no numeric values recorded)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::DefaultConnectionLimit = 48

$WorkDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkDir) { $WorkDir = (Get-Location).Path }

$SnapshotDir = Join-Path $WorkDir "snapshots"
$RawDir      = Join-Path $WorkDir "raw_data"
$DbDir       = Join-Path $WorkDir "database"
foreach ($d in @($SnapshotDir, $RawDir, $DbDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$JsonPath = Join-Path $WorkDir "competitor_trend.json"
$CsvPath  = Join-Path $WorkDir "competitor_trend.csv"
$JsPath   = Join-Path $WorkDir "competitor_trend_data.js"

$NowKst        = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9))
$TodayDate     = $NowKst.ToString("yyyy-MM-dd")
$Timestamp     = $NowKst.ToString("yyyy-MM-dd HH:mm:ss")
$CacheVer      = $NowKst.ToString("yyyyMMddHHmm")
$Cutoff30dMs   = $NowKst.AddDays(-30).ToUnixTimeMilliseconds()
$Cutoff29dDate = $NowKst.AddDays(-29).ToString("yyyy-MM-dd")

$ExistingRecords = @()
if (Test-Path $JsonPath) {
    try {
        $parsedExisting = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($elem in @($parsedExisting)) {
            if ($null -ne $elem -and $null -ne $elem.PSObject.Properties['value']) {
                foreach ($sub in @($elem.value)) { if ($null -ne $sub -and $sub.date) { $ExistingRecords += $sub } }
            } elseif ($null -ne $elem -and $elem.date) {
                $ExistingRecords += $elem
            }
        }
    } catch { $ExistingRecords = @() }
}
$PriorRecords = @($ExistingRecords | Where-Object { $_.date -lt $TodayDate } | Sort-Object date)
$PrevRec = if ($PriorRecords.Count -gt 0) { $PriorRecords[$PriorRecords.Count - 1] } else { $null }

$NewSinceCutoff = $NowKst.AddHours(-24)
if ($PrevRec -and $PrevRec.updatedAt) {
    try {
        $prevDto = [DateTimeOffset]::Parse("$($PrevRec.updatedAt)+09:00")
        if ($prevDto -ge $NowKst.AddHours(-48) -and $prevDto -le $NowKst.AddHours(-6)) {
            $NewSinceCutoff = $prevDto
        }
    } catch {}
}

function U([string]$esc) { return [regex]::Unescape($esc) }

$KR_UNDER300 = U "300cc \uC774\uD558"
$KR_OVER300  = U "300cc \uC774\uC0C1"
$KR_ONSALE   = U "\uD310\uB9E4\uC911"
$KR_RESERVED = U "\uC608\uC57D\uC911"
$KR_TRADED   = U "\uAC70\uB798\uC644\uB8CC"
$KR_ENDED    = U "\uD310\uB9E4\uC885\uB8CC(\uCD94\uC815)"
$KR_PERSONAL = U "\uAC1C\uC778\uC9C1\uAC70\uB798"
$KR_ESCROW   = U "\uC548\uC804\uACB0\uC81C"
$KR_ETC      = U "\uAE30\uD0C0"

$PLAT_DAANGN = U "\uB2F9\uADFC(\uC624\uD1A0\uBC14\uC774)"
$PLAT_RW     = U "\uB77C\uC774\uD2B8\uBC14\uAC90"
$PLAT_PASSO  = U "\uD30C\uC3D8\uBC14\uC774\uD06C"
$PLAT_BT     = U "\uBC14\uD29C\uB9E4(\uB124\uC774\uBC84\uCE74\uD398)"

$PB_1 = U "300\uB9CC\uC6D0 \uBBF8\uB9CC"
$PB_2 = U "300~600\uB9CC\uC6D0"
$PB_3 = U "600~1,000\uB9CC\uC6D0"
$PB_4 = U "1,000~2,000\uB9CC\uC6D0"
$PB_5 = U "2,000\uB9CC\uC6D0 \uC774\uC0C1"
$PB_UNKNOWN = U "\uAC00\uACA9\uBBF8\uAE30\uC7AC"

$BT_SCOOTER = U "\uC2A4\uCFE0\uD130 \u00B7 \uCEE4\uBBF8\uD130"
$BT_NAKED   = U "\uB124\uC774\uD0A4\uB4DC \u00B7 \uB85C\uB4DC\uC2A4\uD130"
$BT_SPORT   = U "\uC288\uD37C\uC2A4\uD3EC\uCE20 \u00B7 \uB808\uD50C\uB9AC\uCE74"
$BT_TOURER  = U "\uD22C\uC5B4\uB7EC \u00B7 \uC5B4\uB4DC\uBCA4\uCC98"
$BT_CRUISER = U "\uD06C\uB8E8\uC800 \u00B7 \uC544\uBA54\uB9AC\uCE78"
$BT_CLASSIC = U "\uD074\uB798\uC2DD \u00B7 \uC2A4\uD06C\uB7A8\uBE14\uB7EC"
$BT_OTHER   = U "\uAE30\uD0C0 \uC774\uB95C\uCC28"

function Get-BikePriceBand([int]$priceManwon) {
    if ($priceManwon -le 0)    { return $PB_UNKNOWN }
    if ($priceManwon -lt 300)  { return $PB_1 }
    if ($priceManwon -lt 600)  { return $PB_2 }
    if ($priceManwon -lt 1000) { return $PB_3 }
    if ($priceManwon -lt 2000) { return $PB_4 }
    return $PB_5
}

function Get-BikeTypeCategory([string]$text) {
    $t = $text.ToLowerInvariant()
    if ($t -match 'pcx|nmax|엔맥스|xmax|엑스맥스|tmax|티맥스|테크맥스|포르자|forza|슈퍼\s*커브|\bc125|헌터커브|ct125|벤리|엘리트|비전|어드레스|넥스|스위시|아베니스|버그만|보이저|보이져|크루심|조이맥스|맥심|다운타운|엑스타운|익사이팅|ak\s*550|필리|젯14|피들|베스파|프리마베라|스프린트|gts|장고|드래그스터|트리시티|시그너스|에어로스|시티베스트|시티에이스|\bq2\b|\bq3\b|유아이|엠보이|\bc\s*400|\bc\s*600|\bc\s*650|\bce\s*04|adv\s*125|adv\s*150|adv\s*160|adv\s*350|x-?adv|스쿠터') { return $BT_SCOOTER }
    if ($t -match '할리|harley|스트리트\s*밥|스글|스트리트\s*글라이드|로드\s*글라이드|로글|로드킹|팻보이|팻밥|브레이크\s*아웃|아이언\s*883|\b883\b|포티에잇|스포스터|나잇스터|로우\s*라이더|소프테일|울트라|레블|rebel|아퀼라|미라쥬|발칸|엘리미네이터|\br\s*18\b|스카우트|치프|디아벨|크루저|아메리칸') { return $BT_CRUISER }
    if ($t -match 'cbr|yzf|\br3\b|\br6\b|\br7\b|\br9\b|\br1\b|닌자|ninja|\bzx|gsx-?r|하야부사|\bs\s*1000\s*rr|\bm\s*1000\s*rr|파니갈레|슈퍼스포츠|rs\s*660|rs\s*457|rsv4|rc\s*125|rc\s*390|450\s*sr|코멧\s*\d+\s*r|레플리카') { return $BT_SPORT }
    if ($t -match '골드윙|\bgs\b|r\s*1200\s*gs|r\s*1250\s*gs|r\s*1300\s*gs|f\s*750\s*gs|f\s*850\s*gs|f\s*900\s*gs|g\s*310\s*gs|\brt\b|\bk\s*1600|브이스트롬|v-?strom|버시스|멀티스트라다|아프리카\s*트윈|nc\s*750|타이거|히말라얀|어드벤처|노든|팬\s*아메리카|fjr|테네레|450\s*mt|800\s*mt|투어러') { return $BT_TOURER }
    if ($t -match '본네빌|t100|t120|스피드\s*트윈|스크램블러|알나인티|r\s*nine\s*t|\br9t|헌터\s*350|클래식\s*350|메테오|인터셉터|컨티넨탈|샷건|\bw800|메구로|xsr|스바르트필렌|비트필렌|\bcl\s*500|gb\s*350|몽키|그롬|msx|닥스|파피오|데이스타|모토구찌|\bv7\b') { return $BT_CLASSIC }
    if ($t -match '\bmt-?0|\bmt-?10|\bcb\s*\d|호넷|\bz\s*125|\bz\s*400|\bz\s*650|\bz\s*900|\bz\s*1000|gsx-?s|gsx-?8|sv\s*650|카타나|몬스터|스트리트\s*파이터|스트리트\s*트리플|스피드\s*트리플|트라이던트|듀크|duke|\bf\s*900\s*r|\bs\s*1000\s*r|\bg\s*310\s*r|투오노|네이키드') { return $BT_NAKED }
    return $BT_OTHER
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

$BrandRules = @(
    @{ Brand = (U "\uD63C\uB2E4");      Pattern = '(?i)(혼다|honda|(?<![a-z0-9])pcx|(?<![a-z0-9])forza|포르자|슈퍼커브|슈퍼\s*커브|헌터커브|(?<![a-z0-9])ct\s*125|(?<![a-z0-9])c\s*125(?![a-z0-9])|(?<![a-z0-9])cb\s*\d|(?<![a-z0-9])cbr\s*\d|호넷|레블|rebel|골드윙|x-?adv|(?<![a-z0-9])adv\s*(125|150|160|350)|몽키\s*125|그롬|(?<![a-z0-9])msx\s*125|닥스\s*125|(?<![a-z0-9])dax(?![a-z0-9])|벤리|비전\s*110|(?<![a-z0-9])scr\s*110|아프리카\s*트윈|(?<![a-z0-9])crf\s*\d|(?<![a-z0-9])cl\s*500|(?<![a-z0-9])gb\s*350|(?<![a-z0-9])nc\s*750|엘리트\s*125)' },
    @{ Brand = (U "\uC57C\uB9C8\uD558"); Pattern = '(?i)(야마하|yamaha|(?<![a-z0-9])nmax|엔맥스|(?<![a-z0-9])xmax|엑스맥스|(?<![a-z0-9])tmax|티맥스|테크맥스|(?<![a-z0-9])mt-?0[379]|(?<![a-z0-9])mt-?10|(?<![a-z0-9])mt\s*0[379]|(?<![a-z0-9])yzf|(?<![a-z0-9])r3(?![a-z0-9])|(?<![a-z0-9])r6(?![a-z0-9])|(?<![a-z0-9])r7(?![a-z0-9])|(?<![a-z0-9])r9(?![a-z0-9])|(?<![a-z0-9])r1m?(?![a-z0-9])|(?<![a-z0-9])xsr\s*(125|700|900)|트리시티|에어로스|시그너스|비위즈|복스|비노|테네레|트레이서\s*9|페이저|(?<![a-z0-9])fjr)' },
    @{ Brand = "BMW";                   Pattern = '(?i)((?<![a-z0-9])bmw(?![a-z0-9])|(?<![a-z0-9])r\s*1200|(?<![a-z0-9])r\s*1250|(?<![a-z0-9])r\s*1300|(?<![a-z0-9])s\s*1000|(?<![a-z0-9])m\s*1000|(?<![a-z0-9])r\s*18(?![a-z0-9])|알나인티|r\s*nine\s*t|(?<![a-z0-9])r9t(?![a-z0-9])|(?<![a-z0-9])r\s*12(?![a-z0-9])|(?<![a-z0-9])f\s*750|(?<![a-z0-9])f\s*800|(?<![a-z0-9])f\s*850|(?<![a-z0-9])f\s*900|(?<![a-z0-9])g\s*310|(?<![a-z0-9])c\s*400|(?<![a-z0-9])c\s*600|(?<![a-z0-9])c\s*650|(?<![a-z0-9])k\s*1600|(?<![a-z0-9])ce\s*04)' },
    @{ Brand = (U "\uD560\uB9AC\uB370\uC774\uBE44\uC2A8"); Pattern = '(?i)(할리|harley|스트리트\s*밥|스글|스트리트\s*글라이드|로드\s*글라이드|로글|로드킹|팻보이|펫보이|팻밥|브레이크\s*아웃|아이언\s*883|(?<!\d)883(?!\d)|포티에잇|스포스터|나잇스터|팬\s*아메리카|로우\s*라이더|소프테일|울트라\s*리미티드|헤리티지)' },
    @{ Brand = (U "\uC2A4\uC988\uD0A4"); Pattern = '(?i)(스즈키|스즈끼|suzuki|(?<![a-z0-9])gsx|하야부사|브이스트롬|v-?strom|버그만|어드레스|(?<![a-z0-9])nex(?![a-z0-9])|넥스\s*125|아베니스|스위시|카타나|(?<![a-z0-9])sv\s*650|(?<![a-z0-9])dr-?z)' },
    @{ Brand = (U "\uAC00\uC640\uC0AC\uD0A4"); Pattern = '(?i)(가와사키|kawasaki|닌자|ninja|(?<![a-z0-9])zx-?\d|(?<![a-z0-9])z\s*125|(?<![a-z0-9])z\s*400|(?<![a-z0-9])z\s*650|(?<![a-z0-9])z\s*900|(?<![a-z0-9])z\s*1000|버시스|발칸|엘리미네이터|(?<![a-z0-9])w800|(?<![a-z0-9])h2(?![a-z0-9])|메구로|(?<![a-z0-9])klx)' },
    @{ Brand = (U "\uB450\uCE74\uD2F0"); Pattern = '(?i)(두카티|ducati|파니갈레|스크램블러\s*아이콘|데저트\s*슬레드|데저트슬레드|멀티스트라다|디아벨|스트리트\s*파이터|하이퍼모타드|몬스터\s*(696|796|797|821|937|1200))' },
    @{ Brand = (U "\uBCA0\uC2A4\uD30C"); Pattern = '(?i)(베스파|vespa|피아지오|piaggio|(?<![a-z0-9])gts\s*125|(?<![a-z0-9])gts\s*300|(?<![a-z0-9])gtv\s*300|프리마베라|스프린트|스플린터|(?<![a-z0-9])lx\s*125|메들리|비버리)' },
    @{ Brand = (U "\uD2B8\uB77C\uC774\uC5C4\uD504"); Pattern = '(?i)(트라이엄프|triumph|본네빌|(?<![a-z0-9])t100(?![a-z0-9])|(?<![a-z0-9])t120(?![a-z0-9])|스피드\s*트윈|스트리트\s*트리플|스피드\s*트리플|타이거\s*(660|800|850|900|1200)|트라이던트|로켓\s*3|스피드\s*400|스크램블러\s*(400|900|1200))' },
    @{ Brand = (U "\uB85C\uC584\uC5D4\uD544\uB4DC"); Pattern = '(?i)(로얄엔필드|로열엔필드|royal\s*enfield|헌터\s*350|클래식\s*350|클래식\s*500|메테오\s*(350|650)|슈퍼\s*메테오|인터셉터\s*650|컨티넨탈\s*gt|히말라얀|샷건\s*650|게릴라\s*450)' },
    @{ Brand = "KTM";                   Pattern = '(?i)((?<![a-z0-9])ktm(?![a-z0-9])|듀크\s*(125|200|250|390|690|790|890|1290)|(?<![a-z0-9])duke\s*\d|(?<![a-z0-9])rc\s*125|(?<![a-z0-9])rc\s*390|슈퍼\s*어드벤처|390\s*어드벤처|슈퍼듀크|(?<![a-z0-9])exc(?![a-z0-9]))' },
    @{ Brand = (U "\uD5C8\uC2A4\uD06C\uBC14\uB098"); Pattern = '(?i)(허스크바나|husqvarna|스바르트필렌|비트필렌|노든\s*901)' },
    @{ Brand = "SYM";                   Pattern = '(?i)((?<![a-z0-9])sym(?![a-z0-9])|보이저|보이져|크루심|조이맥스|맥심\s*(400|600)|(?<![a-z0-9])drg(?![a-z0-9])|(?<![a-z0-9])adx(?![a-z0-9])|젯\s*14|피들)' },
    @{ Brand = (U "\uD0B4\uCF54");      Pattern = '(?i)(킴코|kymco|다운타운|다운다운\s*300|엑스타운|익사이팅|(?<![a-z0-9])ak\s*550|필리\s*125)' },
    @{ Brand = (U "\uB514\uC5D4\uC5D0\uC774(DNA/\uB300\uB9BC)"); Pattern = '(?i)(대림|디엔에이|디앤에이|(?<![a-z0-9])dna(?![a-z0-9])|시티베스트|시티에이스|유아이|데이스타|(?<![a-z0-9])vf100|(?<![a-z0-9])uh115|엠보이|(?<![a-z0-9])q2(?![a-z0-9])|(?<![a-z0-9])q3(?![a-z0-9])|(?<![a-z0-9])xq\s*(125|250))' },
    @{ Brand = (U "KR\uBAA8\uD130\uC2A4"); Pattern = '(?i)(kr모터스|효성|아퀼라|미라쥬|코멧|엑시브|델피노|티니\s*110|라온\s*100)' },
    @{ Brand = (U "\uC874\uD14C\uC2A4"); Pattern = '(?i)(존테스|zontes|(?<![a-z0-9])350d(?![a-z0-9])|(?<![a-z0-9])350e(?![a-z0-9])|(?<![a-z0-9])350gk(?![a-z0-9])|(?<![a-z0-9])368\s*g)' },
    @{ Brand = (U "CF\uBAA8\uD130");    Pattern = '(?i)(cf모토|cfmoto|파피오|(?<![a-z0-9])450\s*sr|(?<![a-z0-9])450\s*mt|(?<![a-z0-9])450\s*nk|(?<![a-z0-9])700\s*cl|(?<![a-z0-9])800\s*mt)' },
    @{ Brand = (U "\uC544\uD504\uB9B4\uB9AC\uC544"); Pattern = '(?i)(아프릴리아|aprilia|(?<![a-z0-9])rs\s*660|(?<![a-z0-9])rs\s*457|(?<![a-z0-9])rsv4|투오노|(?<![a-z0-9])sr\s*gt)' },
    @{ Brand = (U "\uC778\uB514\uC5B8"); Pattern = '(?i)(인디언|indian|스카우트|치프테인|치프태인)' },
    @{ Brand = (U "\uC774\uD0C8\uC82F/\uAE30\uD0C0\uC218\uC785"); Pattern = '(?i)(이탈젯|드래그스터|모토구찌|푸조\s*장고|몬디알|파가니|보그|voge|벤다|benda|베넬리|benelli|(?<![a-z0-9])tnt\s*125|슈퍼쏘코|supersoco|부캐너|모터스타|엘로이|한솜|베네트|베네타|하트포드|hartford|하우주|브릭스톤|람브레타|우랄|ural|빅토리아\s*xdv|고고로|(?<![a-z0-9])zeeho|지호|대동모빌리티|이누리|이륜테크|이디뚜뚜|캔암|스파이더|mv\s*아구스타|써론|surron|탈라리아)' }
)

$ReitwagenBrandIdMap = @{
    "1"  = "BMW"; "2" = (U "\uD63C\uB2E4"); "3" = (U "\uD560\uB9AC\uB370\uC774\uBE44\uC2A8"); "4" = (U "\uB450\uCE74\uD2F0")
    "5"  = (U "\uC57C\uB9C8\uD558"); "6" = (U "\uAC00\uC640\uC0AC\uD0A4"); "7" = "SYM"; "8" = (U "\uC2A4\uC988\uD0A4")
    "9"  = "KTM"; "10" = (U "\uBCA0\uC2A4\uD30C"); "11" = (U "\uD2B8\uB77C\uC774\uC5C4\uD504"); "12" = (U "\uB85C\uC584\uC5D4\uD544\uB4DC")
    "13" = (U "\uC778\uB514\uC5B8"); "14" = (U "\uD0B4\uCF54"); "15" = (U "\uC544\uD504\uB9B4\uB9AC\uC544")
    "21" = (U "\uB514\uC5D4\uC5D0\uC774(DNA/\uB300\uB9BC)"); "22" = (U "KR\uBAA8\uD130\uC2A4"); "29" = (U "\uD5C8\uC2A4\uD06C\uBC14\uB098")
}

function Resolve-Brand([string]$rawBrand, [string]$titleText, [string]$rwBrandId) {
    if ($rwBrandId -and $ReitwagenBrandIdMap.ContainsKey($rwBrandId)) { return $ReitwagenBrandIdMap[$rwBrandId] }
    $combined = "$rawBrand $titleText"
    foreach ($rule in $BrandRules) {
        if ($combined -match $rule.Pattern) { return $rule.Brand }
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
    if ($t -match '크루심\s*300|조이맥스\s*300|보이저\s*300|보이져\s*300|다운타운\s*300|다운다운\s*300') { return 279 }
    if ($t -match 'pcx|엔맥스|nmax|슈퍼\s*커브|헌터커브|ct\s*125|(?<![a-z0-9])c\s*125(?![a-z0-9])|몽키\s*125|그롬|msx|닥스\s*125|벤리|비전\s*110|scr\s*110|어드레스|넥스\s*125|스위시|아베니스|보이저\s*125|보이져\s*125|크루심\s*125|시티베스트|시티에이스|프리마베라|스프린트|(?<![a-z0-9])gts\s*125|필리\s*125|젯\s*14|파피오|스바르트필렌\s*125|(?<![a-z0-9])gsx-?[rs]?\s*125|(?<![a-z0-9])cb\s*125|(?<![a-z0-9])cbr\s*125|(?<![a-z0-9])tnt\s*125|부캐너\s*125|베네트\s*125|베네타\s*125|전기\s*스쿠터|전기\s*오토바이') { return 125 }
    if ($t -match 'adv\s*150|adv\s*160|트리시티|버그만\s*200|cbr\s*250|코멧\s*250|미라쥬\s*250|브이스트롬\s*250|(?<!\d)(250|155|160|125|110|100|50)\s*cc') { return 180 }
    if ($t -match '포르자\s*350|forza\s*350|adv\s*350|비버리\s*350|gb\s*350|다운타운\s*350|존테스\s*350|존테스\s*368') { return 330 }
    if ($t -match '헌터\s*350|클래식\s*350|메테오\s*350') { return 349 }
    if ($t -match 'mt-?03|(?<![a-z0-9])r3(?![a-z0-9])|yzf-?r3') { return 321 }
    if ($t -match '(?<![a-z0-9])g\s*310') { return 313 }
    if ($t -match '(?<![a-z0-9])c\s*400') { return 350 }
    if ($t -match '티맥스|tmax|테크맥스') { return 560 }
    if ($t -match '(?<![a-z0-9])r6(?![a-z0-9])|yzf-?r6|cbr\s*600|zx-?6r') { return 599 }
    if ($t -match 'mt-?07|(?<![a-z0-9])r7(?![a-z0-9])|cbr\s*650|cb\s*650|닌자\s*650|z\s*650|버시스\s*650|브이스트롬\s*650|sv\s*650|인터셉터\s*650|컨티넨탈\s*gt|트라이던트\s*660|rs\s*660') { return 689 }
    if ($t -match 'mt-?09|(?<![a-z0-9])r9(?![a-z0-9])|xsr\s*900|트레이서\s*9|f\s*900|z\s*900|타이거\s*900|노든\s*901') { return 890 }
    if ($t -match 'mt-?10|(?<![a-z0-9])r1m?(?![a-z0-9])|yzf-?r1|s\s*1000|m\s*1000|r\s*1000|cbr\s*1000|cb\s*1000|gsx-?[rs]?\s*1000|zx-?10|닌자\s*1000|버시스\s*1000') { return 999 }
    if ($t -match '할리|스트리트\s*밥|스글|로글|로드킹|브레이크\s*아웃|팻보이|펫보이|팻밥|아이언\s*883|포티에잇|스포스터|소프테일|울트라|(?<!\d)(114|117|883)(?!\d)') { return 1200 }
    if ($t -match '두카티|파니갈레|멀티스트라다|데저트\s*슬레드|디아벨|하야부사|골드윙|r\s*1200|r\s*1250|r\s*1300|(?<![a-z0-9])r\s*18(?![a-z0-9])|알나인티|r9t|본네빌|(?<![a-z0-9])t100(?![a-z0-9])|(?<![a-z0-9])t120(?![a-z0-9])|타이거|스피드\s*트윈|로켓\s*3|아프리카\s*트윈|x-?adv|우랄') { return 900 }
    $mCc = [regex]::Match($t, '(?<!\d)(50|80|90|100|110|125|150|155|160|180|200|250|300|310|320|350|390|400|401|450|500|530|550|560|600|650|660|700|750|790|800|850|883|890|900|901|950|1000|1050|1100|1200|1250|1290|1300|1400|1600|1800)\s*cc(?![a-z])')
    if ($mCc.Success) { return [int]$mCc.Groups[1].Value }
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
        foreach ($x in $todayIds) { if ($x) { [void]$todaySet.Add([string]$x) } }
    }
    $todayUnique = New-Object 'string[]' $todaySet.Count
    $todaySet.CopyTo($todayUnique)
    $todaySnapPath      = Join-Path $SnapshotDir "$($platformKey)_$($TodayDate).json"
    $latestSnapMetaPath = Join-Path $SnapshotDir "$($platformKey)_latest.json"

    $prevFiles = @(Get-ChildItem -Path $SnapshotDir -Filter "$($platformKey)_*.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "$($platformKey)_latest.json" -and $_.Name -ne "$($platformKey)_$($TodayDate).json" } |
        Sort-Object Name)

    $newFromDiff = $null; $soldFromDiff = $null; $prevTotal = 0
    if ($prevFiles.Count -gt 0) {
        $prevFile = $prevFiles[$prevFiles.Count - 1]
        try {
            $prevObj = [System.IO.File]::ReadAllText($prevFile.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            $prevIds = [string[]]@($prevObj.ids)
            $prevTotal = $prevIds.Count
            $prevSet = New-Object 'System.Collections.Generic.HashSet[string]'
            foreach ($px in $prevIds) { if ($px) { [void]$prevSet.Add([string]$px) } }

            $newCnt = 0; foreach ($id in $todayUnique) { if (-not $prevSet.Contains($id)) { $newCnt++ } }
            $soldCnt = 0; foreach ($id in $prevIds) { if (-not $todaySet.Contains($id)) { $soldCnt++ } }
            $newFromDiff = $newCnt; $soldFromDiff = $soldCnt
        } catch {}
    }

    $snapObj = [ordered]@{ date = $TodayDate; updatedAt = $Timestamp; count = $todayUnique.Count; ids = $todayUnique }
    $snapJson = $snapObj | ConvertTo-Json -Depth 4 -Compress

    return [pscustomobject]@{
        Count          = $todayUnique.Count
        PrevCount      = $prevTotal
        NewFromDiff    = $newFromDiff
        SoldFromDiff   = $soldFromDiff
        TodaySnapPath  = $todaySnapPath
        LatestSnapPath = $latestSnapMetaPath
        SnapJson       = $snapJson
    }
}

function Build-BikePortfolioSummary([object[]]$items, [int]$exactUnder300 = 0, [int]$exactOver300 = 0) {
    $totalSample = $items.Count
    $u300Sample = 0; $o300Sample = 0
    $priceSum = 0; $priceCnt = 0
    $priceBands = [ordered]@{ $PB_1 = 0; $PB_2 = 0; $PB_3 = 0; $PB_4 = 0; $PB_5 = 0 }
    $bikeTypes  = [ordered]@{
        $BT_SCOOTER = 0; $BT_NAKED = 0; $BT_SPORT = 0
        $BT_TOURER  = 0; $BT_CRUISER = 0; $BT_CLASSIC = 0; $BT_OTHER = 0
    }
    $regionCounts = @{}; $modelCounts = @{}; $brandCounts = @{}

    foreach ($it in $items) {
        if ($it.ccGroup -eq $KR_UNDER300) { $u300Sample++ } else { $o300Sample++ }
        $p = [int]$it.priceManwon
        if ($p -gt 0 -and $p -lt 50000) {
            $priceSum += $p; $priceCnt++
            $pb = $it.priceBand
            if ($priceBands.Contains($pb)) { $priceBands[$pb] = [int]$priceBands[$pb] + 1 }
        }
        $btCat = Get-BikeTypeCategory "$($it.manufacturer) $($it.model) $($it.fullTitle)"
        if ($bikeTypes.Contains($btCat)) { $bikeTypes[$btCat] = [int]$bikeTypes[$btCat] + 1 }

        $r = if ($it.sido) { [string]$it.sido } else { $KR_ETC }
        $regionCounts[$r] = [int]$regionCounts[$r] + 1

        $m = if ($it.model -and $it.model -ne $KR_ETC) { [string]$it.model } else { $null }
        if ($m) { $modelCounts[$m] = [int]$modelCounts[$m] + 1 }

        $b = if ($it.manufacturer) { [string]$it.manufacturer } else { $KR_ETC }
        $brandCounts[$b] = [int]$brandCounts[$b] + 1
    }

    $avgPrice = if ($priceCnt -gt 0) { [int][math]::Round($priceSum / $priceCnt) } else { 0 }
    if (($exactUnder300 + $exactOver300) -le 0) {
        $exactUnder300 = $u300Sample
        $exactOver300  = $o300Sample
    }
    $ccTotal = [Math]::Max(1, ($exactUnder300 + $exactOver300))

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
        bikeTypes        = $bikeTypes
        topRegions       = $topRegions
        topModels        = $topModels
        topBrands        = $topBrands
    }
}

$allRawBikes = New-Object System.Collections.Generic.List[object]

# ==============================================================================
# 1. DAANGN MOTORCYCLES (370+ Purified Keywords + 4-Stage Precision Filter + Sitemap - Minimum Floor)
# ==============================================================================
$daangnKeywords = @(
    # Motorcycle-Anchored General & Displacement Queries (36 - zero standalone ambiguous words)
    "오토바이", "스쿠터", "중고오토바이", "중고스쿠터", "오토바이 팝니다", "스쿠터 팝니다",
    "배달오토바이", "배달스쿠터", "출퇴근 오토바이", "출퇴근 스쿠터", "전기스쿠터", "전기오토바이",
    "메뉴얼바이크", "메뉴얼 오토바이", "매뉴얼 바이크", "네이키드 바이크", "크루저 바이크", "클래식 오토바이", "투어러 바이크",
    "50cc 스쿠터", "100cc 스쿠터", "110cc 오토바이", "125cc 오토바이", "125cc 스쿠터", "250cc 오토바이", "300cc 오토바이", "300cc 스쿠터",
    "350cc 스쿠터", "400cc 오토바이", "500cc 오토바이", "650cc 오토바이", "750cc 오토바이", "1000cc 오토바이",
    "쿼터급 오토바이", "쿼터급 바이크", "미들급 바이크", "리터급 오토바이", "리터급 바이크",
    # Brand + Motorcycle Anchored Superset (42 - blocks pianos, guitars, golf, bags, lawnmowers)
    "혼다 오토바이", "혼다 스쿠터", "혼다 바이크", "혼다 pcx", "혼다 포르자", "슈퍼커브", "혼다 cb", "혼다 cbr", "혼다 레블", "골드윙", "혼다 adv",
    "야마하 오토바이", "야마하 스쿠터", "야마하 바이크", "야마하 메뉴얼", "nmax", "엔맥스", "엑스맥스", "야마하 티맥스", "야마하 mt", "야마하 r3",
    "스즈키 오토바이", "스즈키 스쿠터", "스즈키 바이크", "스즈키 gsx", "하야부사", "브이스트롬", "버그만", "스즈키 어드레스",
    "가와사키 오토바이", "가와사키 바이크", "가와사키 닌자", "가와사키 z", "가와사키 버시스", "가와사키 발칸", "가와사키 엘리미네이터",
    "할리데이비슨", "할리 오토바이", "스트리트글라이드", "로드글라이드", "아이언883", "할리 브레이크아웃", "할리 팻보이", "할리 로드킹", "스포스터",
    "bmw 오토바이", "bmw 바이크", "bmw 모토라드", "bmw gs", "bmw s1000", "bmw c400", "bmw c650", "알나인티", "bmw r18",
    "두카티 오토바이", "두카티 바이크", "베스파 스쿠터", "베스파 오토바이", "트라이엄프 오토바이", "트라이엄프 바이크",
    "로얄엔필드", "ktm 오토바이", "ktm 듀크", "허스크바나 오토바이", "허스크바나 바이크",
    "sym 오토바이", "sym 스쿠터", "sym 보이저", "크루심", "킴코 스쿠터", "킴코 오토바이",
    "대림 오토바이", "디엔에이 스쿠터", "효성 오토바이", "kr모터스", "존테스", "cf모토", "아프릴리아 오토바이", "인디언 바이크", "푸조 장고", "이탈젯 드래그스터", "모토구찌",
    # Honda Fine-Grained Models & Model-Years (64)
    "pcx 125", "pcx 18년식", "pcx 19년식", "pcx 20년식", "pcx 21년식", "pcx 22년식", "pcx 23년식", "pcx 24년식", "pcx 25년식", "pcx abs",
    "포르자 300", "포르자 350", "포르자 750", "포르자 20년식", "포르자 21년식", "포르자 22년식", "포르자 23년식", "포르자 24년식", "포르자 25년식",
    "슈퍼커브 110", "슈퍼커브 19년식", "슈퍼커브 20년식", "슈퍼커브 21년식", "슈퍼커브 22년식", "슈퍼커브 23년식", "슈퍼커브 24년식", "슈퍼커브 25년식",
    "혼다 c125", "헌터커브", "ct125", "몽키 125", "그롬 125", "msx 125", "닥스 125", "혼다 벤리", "벤리 110", "엘리트 125", "비전 110", "혼다 scr 110",
    "adv 125", "adv 150", "adv 160", "adv 350", "x-adv 750", "혼다 xadv",
    "cb125r", "cb300r", "cb400sf", "cb500x", "cb650r", "cb750 호넷", "cb1000r",
    "cbr125r", "cbr250rr", "cbr500r", "cbr600rr", "cbr650r", "cbr1000rr",
    "레블 300", "레블 500", "레블 1100", "혼다 cl500", "혼다 gb350", "nc750x", "아프리카트윈", "crf300l", "골드윙 1800",
    # Yamaha Fine-Grained Models & Model-Years (44)
    "야마하 nmax", "엔맥스 125", "nmax 155", "엔맥스 20년식", "엔맥스 21년식", "엔맥스 22년식", "엔맥스 23년식", "엔맥스 24년식", "엔맥스 25년식",
    "야마하 xmax", "엑스맥스 300", "xmax 300", "엑스맥스 21년식", "엑스맥스 22년식", "엑스맥스 23년식", "엑스맥스 24년식",
    "티맥스 530", "티맥스 560", "테크맥스 560", "트리시티 125", "트리시티 155", "시그너스 125", "야마하 에어로스", "야마하 비노", "야마하 복스",
    "yzf r3", "r3 21년식", "r3 22년식", "r3 23년식", "r3 24년식", "야마하 r6", "야마하 r7", "야마하 r9", "야마하 r1", "yzf r125", "yzf r15",
    "야마하 mt03", "mt-03", "야마하 mt07", "mt-07", "야마하 mt09", "mt-09", "야마하 mt10", "xsr 125", "xsr 700", "xsr 900", "테네레 700", "트레이서 9", "fjr1300",
    # Suzuki (24)
    "gsx r125", "gsx s125", "gsx r600", "gsx r750", "gsx r1000", "gsx r1000r", "gsx s750", "gsx s1000", "gsx 8s", "gsx 8r",
    "스즈키 하야부사", "브이스트롬 250", "브이스트롬 650", "브이스트롬 800", "브이스트롬 1050",
    "버그만 125", "버그만 200", "버그만 400", "버그만 650", "어드레스 125", "스즈키 넥스", "아베니스 125", "스위시 125", "스즈키 sv650", "스즈키 카타나",
    # Kawasaki (21)
    "닌자 300", "닌자 400", "닌자 500", "닌자 650", "닌자 1000sx", "zx-4r", "zx-4rr", "zx-6r", "zx-10r",
    "가와사키 z125", "가와사키 z400", "가와사키 z650", "z650rs", "가와사키 z900", "z900rs", "가와사키 z1000",
    "버시스 650", "버시스 1000", "발칸 s", "가와사키 w800",
    # BMW (27)
    "bmw g310r", "bmw g310gs", "bmw c400x", "bmw c400gt", "bmw c600", "bmw c650gt", "bmw c650 스포츠", "bmw ce04",
    "bmw f750gs", "bmw f800", "bmw f850gs", "bmw f900r", "bmw f900xr", "bmw f900gs",
    "bmw s1000rr", "bmw s1000r", "bmw s1000xr", "bmw m1000rr",
    "bmw r9t", "bmw r12", "bmw r1200gs", "bmw r1200rt", "bmw r1250gs", "bmw r1250rt", "bmw r1300gs", "bmw k1600",
    # Harley-Davidson (19)
    "아이언 883", "할리 포티에잇", "할리 48", "스포스터 s", "할리 나잇스터", "할리 스트리트 750",
    "할리 스트리트밥", "팻보이 114", "할리 팻밥", "브레이크아웃 114", "브레이크아웃 117", "로우라이더 s", "로우라이더 st", "헤리티지 클래식",
    "할리 울트라", "할리 팬아메리카",
    # Ducati / Vespa / Triumph / Royal Enfield / KTM / Husqvarna / SYM / Kymco / KR / DNA / Others (80+)
    "두카티 파니갈레", "두카티 몬스터", "두카티 스크램블러", "두카티 멀티스트라다", "두카티 디아벨", "스트리트파이터 v4", "하이퍼모타드",
    "베스파 프리마베라", "베스파 스프린트", "베스파 gts 125", "베스파 gts 300", "피아지오 메들리", "피아지오 비버리",
    "트라이엄프 본네빌", "트라이엄프 t100", "트라이엄프 t120", "스피드트윈 900", "스피드트윈 1200", "스트리트트리플", "트라이던트 660", "트라이엄프 타이거", "트라이엄프 스피드 400", "스크램블러 400x", "트라이엄프 로켓3",
    "로얄엔필드 헌터 350", "로얄엔필드 클래식 350", "로얄엔필드 메테오 350", "로얄엔필드 인터셉터 650", "컨티넨탈 gt 650", "로얄엔필드 히말라얀", "슈퍼메테오 650", "샷건 650",
    "ktm 듀크 125", "ktm 듀크 390", "ktm rc390", "ktm 390 어드벤처", "ktm 790", "ktm 890",
    "스바르트필렌 125", "스바르트필렌 401", "비트필렌 401", "노든 901",
    "보이저 125", "보이저 300", "sym 크루심", "조이맥스 z", "맥심 400", "sym drg", "sym 젯14", "sym 피들",
    "킴코 다운타운", "킴코 엑스타운", "킴코 ak550", "킴코 필리", "익사이팅 400",
    "시티베스트", "시티에이스", "대림 q2", "대림 q3", "대림 데이스타", "엠보이", "유아이 100",
    "아퀼라 125", "아퀼라 300", "미라쥬 250", "코멧 125", "코멧 250", "코멧 650",
    "존테스 350d", "존테스 350e", "존테스 368g", "존테스 125", "cf모토 450sr", "파피오 xo", "cf모토 450mt",
    "아프릴리아 rs660", "아프릴리아 sr gt", "인디언 스카우트", "모토구찌 v7", "보그 300", "베넬리 tnt125", "슈퍼쏘코", "부캐너 125", "람브레타"
)
$daangnKeywords = @($daangnKeywords | Select-Object -Unique)
Write-Host "1. Collecting Daangn Nationwide C2C Motorcycles ($($daangnKeywords.Count) Purified Keywords + 4-Stage Filter)..." -ForegroundColor Yellow

$daangnFetchScript = {
    param([string]$kw)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            Start-Sleep -Milliseconds (120 * $attempt)
            $enc = [uri]::EscapeDataString($kw)
            $req = [System.Net.HttpWebRequest]::Create("https://www.daangn.com/kr/search/buy-sell/?q=$enc")
            $req.Method = "GET"
            $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            $req.Timeout = 20000
            $req.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
            $h = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
            $i1 = $h.IndexOf("window.__remixContext = ")
            if ($i1 -lt 0) { continue }
            $i1 += 24
            $i2 = $h.IndexOf(";__remixContext.p", $i1)
            if ($i2 -lt 0) { continue }
            $obj = ($h.Substring($i1, $i2 - $i1)) | ConvertFrom-Json
            return @($obj.state.loaderData.'routes/_buy-sell-shell'.buySellArticles)
        } catch {
            if ($attempt -eq 2) { return @() }
            Start-Sleep -Milliseconds 600
        }
    }
    return @()
}

# 4-Stage Precision Motorcycle Filter Regexes (Shared across Daangn & Batumae)
$nonBikeHardRx = [regex]::new('(?i)(피아노|디지털피아노|클라비노바|엘렉톤|건반|신디사이저|색소폰|섹소폰|플룻|플루트|클라리넷|트럼펫|바이올린|첼로|통기타|일렉기타|어쿠스틱|베이스기타|아치탑|펜더|깁슨|우쿨렐레|드럼세트|전자드럼|마우스피스|서브우퍼|사운드바|오디오\s*앰프|기타\s*앰프|베이스\s*앰프|리시버|디지털믹서|디지탈믹서|오디오인터페이스|턴테이블|이펙터|전기자전거|자전거|로드자전거|로드바이크|산악자전거|미니벨로|브롬톤|피나렐로|도그마|pinarello|dogma|에스웍스|스페셜라이즈드|비앙키|캐논데일|서벨로|메리다|치넬리|그래블|픽시|(?<![a-z0-9])mtb(?![a-z0-9])|엠티비|조립차|스핀바이크|실내바이크|실내사이클|헬스사이클|헬스바이크|운동기구|런닝머신|즈위프트|스마트로라|평로라|탁스|와후|울테그라|듀라에이스|사발이|(?<![a-z0-9])atv(?![a-z0-9])|(?<![a-z0-9])utv(?![a-z0-9])|4륜|사륜|삼발이|3륜\s*전동|3륜\s*전기|전기\s*삼륜|삼륜\s*스쿠터|삼륜\s*전기|삼륜\s*운반|삼륜\s*오토바이|삼륜짐칸|농용|운반차|유아\s*전동|아기\s*전동|어린이\s*전동|밸런스바이크|자토바이|팻바이크|엑스라이더|x-?rider|슈퍼73|super\s*73|전동킥보드|킥보드|전동\s*스쿠터|전동차|듀얼트론|위페드|나인봇|이노킴|미니모터스|전동휠|외발휠|전동보드|워터스쿠터|수중스쿠터|아쿠아스쿠터|의료용|노인|장애인|휠체어|유모차|1인승\s*자동차|(?<![a-z0-9])rc카|알씨카|트렉사스|프라모델|레고|다이캐스트|피규어|키링|포켓몬|트레이딩\s*카드|고반발|드라이버|\d\s*번\s*우드|아이언\s*세트|아이언\s*\d|퍼터|샤프트|골프채|골프|캐디백|스릭슨|테일러메이드|캘러웨이|타이틀리스트|거실형|터널\s*패밀리|텐트|타프|야전침대|잔디깎이|예초기|관리기|경운기|트랙터|콤바인|이앙기|스프레이어|농약|발전기|양수기|콤프레샤|선외기|보트|제트스키|요트|모니터|그래픽카드|(?<![a-z0-9])rtx\s*\d|지포스|라데온|라이젠|조립\s*pc|하이엔드\s*pc|게이밍\s*pc|키보드|노트북|맥북|아이패드|아이폰|갤럭시|인스타360|insta360|고프로|gopro|카메라|렌즈|냉장고|세탁기|안마의자|커피머신|자사호|다관|향수|오드퍼퓸|\d+\s*ml(?![a-z])|재즈마스터|롤렉스|오메가|태그호이어|자켓|재킷|고어텍스|다이네즈|알파인스타|코미네|헬멧|장갑|부츠|숄더백|토트백|크로스백|백팩|지갑|명품|프라다|구찌|샤넬|루이비통|디올|생로랑|발렌시아가|운동화|스니커즈|패딩|상품권|구합니다|삽니다|매입합니다|렌트카|승용차)', [System.Text.RegularExpressions.RegexOptions]::Compiled)

$vehContextRx = [regex]::new('(?i)(\d{2,4}\s*(년식|연식|년형|년\s*출고)|\d[\d,\.]*\s*(km|키로|킬로|만키로|만킬로)|적산|실키로|실주행|구변|구조변경|폐지|서류\s*3장|서류\s*완비|명의\s*이전|이전\s*가능|사용신고|번호판\s*폐지|우꿍|좌꿍|제자리꿍|무꿍|슬립|무슬립|화물\s*거래|용달)', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$positiveBikeContextRx = [regex]::new('(?i)(\d{2,4}\s*(년식|연식|년형|년\s*출고)|\d[\d,\.]*\s*(km|키로|킬로|만키로|만킬로)|적산|실키로|실주행|구변|구조변경|폐지|서류|명의\s*이전|이전\s*가능|사용신고|우꿍|좌꿍|무꿍|슬립|오토바이|스쿠터|이륜차|모터사이클|메뉴얼|매뉴얼|네이키드|크루저|투어러|레플리카|쿼터급|미들급|리터급|(?<!\d)(50|100|110|125|150|155|160|250|300|321|350|390|400|450|500|530|560|600|650|750|800|883|900|1000|1100|1200|1250|1300|1800)\s*cc(?![a-z]))', [System.Text.RegularExpressions.RegexOptions]::Compiled)

$partsAlwaysRx = [regex]::new('(?i)(순정\s*탈거|신차\s*탈거|부품용|부품차|무서류|서류\s*없음|차대만|엔진만|머플러만|배기만|카울만|배터리만|타이어만|시트만|휠만|오버홀\s*엔진|구동계\s*풀세트|호환\s*\)|까지\s*호환|전용\s*방수포|콜라보\s*한정판|핸들\s*커버|방한\s*토시|방수\s*커버)', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$partsEndRx = [regex]::new('(?i)(머플러|슬립온|백스텝|카울|순정카울|페어링|윈드스크린|스크린|탑박스|탑케이스|사이드케이스|사이드백|리어백|새들백|배달통|슬라이더|포크\s*브릿지|슬리퍼\s*클러치|디스크|쇼바|서스펜션|캘리퍼|휠\s*세트|계기판|등받이|시시바|거치대|인터콤|세나|카도|엔진|커버)\s*(\([^)]*\))?\s*(팝니다|판매|판매합니다|팔아요|새상품|새제품|신품|정품|중고)?\s*$', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$explicitBikeWordRx = [regex]::new('(?i)(오토바이|이륜차|모터사이클|스쿠터|(클래식|메뉴얼|매뉴얼|네이키드|크루저|배달|출퇴근|전기|투어러|스포츠)\s*바이크)', [System.Text.RegularExpressions.RegexOptions]::Compiled)

$tier4Rx = [regex]::new('(?i)(할리데이비슨|할리\s|두카티|골드윙|(?<![a-z0-9])s\s*1000|(?<![a-z0-9])m\s*1000|(?<![a-z0-9])r\s*1200|(?<![a-z0-9])r\s*1250|(?<![a-z0-9])r\s*1300|(?<![a-z0-9])r\s*18(?![a-z0-9])|(?<![a-z0-9])k\s*1600|알나인티|(?<![a-z0-9])r9t(?![a-z0-9])|하야부사|zx-?10r|cbr\s*1000|yzf-?r1|(?<![a-z0-9])r1m?(?![a-z0-9])|인디언|로켓\s*3|멀티스트라다|파니갈레|스트리트\s*글라이드|로드\s*글라이드|브레이크\s*아웃|팻보이|펫보이|로드킹)', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$tier3Rx = [regex]::new('(?i)(티맥스|tmax|테크맥스|포르자\s*750|x-?adv|(?<![a-z0-9])c\s*600|(?<![a-z0-9])c\s*650|ak\s*550|cbr\s*600|cbr\s*650|cb\s*650|cb\s*1000|(?<![a-z0-9])r6(?![a-z0-9])|(?<![a-z0-9])r7(?![a-z0-9])|mt-?07|mt-?09|mt-?10|xsr\s*[79]00|테네레|트레이서\s*9|gsx-?[rs]?\s*(600|750|1000|8s|8r)|브이스트롬\s*(650|800|1050)|닌자\s*(650|1000)|zx-?[46]r|z\s*650|z\s*900|z\s*1000|버시스\s*(650|1000)|발칸\s*s|트라이엄프|스트리트\s*트리플|트라이던트|본네빌|스피드\s*트윈|타이거\s*[89]|인터셉터\s*650|컨티넨탈\s*gt|슈퍼\s*메테오|샷건\s*650|스바르트필렌\s*401|비트필렌\s*401|노든\s*901|듀크\s*(390|790|890)|rs\s*660)', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$tier2Rx = [regex]::new('(?i)(포르자\s*(300|350)|엑스맥스|xmax|(?<![a-z0-9])c\s*400|(?<![a-z0-9])ce\s*04|(?<![a-z0-9])f\s*750|(?<![a-z0-9])f\s*800|(?<![a-z0-9])f\s*850|(?<![a-z0-9])f\s*900|보이저\s*(250|300)|보이져\s*(250|300)|크루심\s*300|맥심\s*400|다운타운\s*(300|350)|다운다운\s*300|익사이팅\s*400|존테스\s*(350|368)|(?<![a-z0-9])r3(?![a-z0-9])|yzf-?r3|mt-?03|닌자\s*(300|400|500)|cbr\s*(250|300|500)|cb\s*(300|400|500)|레블\s*(300|500)|cl\s*500|gb\s*350|베스파\s*gts\s*300|클래식\s*350|헌터\s*350|메테오\s*350|히말라얀|스피드\s*400|스크램블러\s*400|(?<![a-z0-9])g\s*310|아퀼라\s*300|코멧\s*650|450\s*sr|450\s*mt)', [System.Text.RegularExpressions.RegexOptions]::Compiled)

function Get-MinBikePriceManwon([string]$titleText) {
    if ($tier4Rx.IsMatch($titleText)) { return 300 }
    if ($tier3Rx.IsMatch($titleText)) { return 170 }
    if ($tier2Rx.IsMatch($titleText)) { return 110 }
    return 50
}

function Test-IsGenuineDaangnBike([string]$tit, [string]$bodyTxt, [double]$rawPriceWon, [ref]$outPriceManwon) {
    if (-not $tit) { return $false }
    $combined = "$tit $bodyTxt"

    # Normalize price (including rescue when seller typed manwon e.g. '730' in price field & wrote '730만' in text)
    $prcWon = $rawPriceWon
    if ($prcWon -ge 80 -and $prcWon -le 9999) {
        $intP = [int]$prcWon
        if ($combined -match "(?<!\d)$intP\s*만" -and $vehContextRx.IsMatch($combined)) {
            $prcWon = $prcWon * 10000.0
        }
    }
    if ($prcWon -lt 500000 -or $prcWon -gt 150000000) { return $false }
    $prcMan = [int][math]::Round($prcWon / 10000.0)

    # Stage 1: Tiered Minimum Price Floor by Bike Segment
    $minMan = Get-MinBikePriceManwon $tit
    if ($prcMan -lt $minMan) { return $false }

    # Stage 2: Hard Non-Bike Blacklist (title checked strictly; body checked for unmistakable non-bike categories)
    if ($nonBikeHardRx.IsMatch($tit)) { return $false }
    if ($bodyTxt -match '(?i)(업라이트\s*피아노|디지털\s*피아노|클라비노바|알토\s*색소폰|테너\s*색소폰|마우스피스|드라이버\s*샤프트|아이언\s*세트|스핀\s*바이크|스마트\s*로라|즈위프트|거실형\s*텐트|터널형\s*텐트|사발이|4륜\s*오토바이|사륜\s*오토바이|노인용\s*전동|의료용\s*스쿠터|그래픽카드\s*rtx)') { return $false }

    # Stage 3: Standalone Parts vs Complete Tuned Motorcycle Separation
    if ($partsAlwaysRx.IsMatch($tit)) { return $false }
    if ($partsEndRx.IsMatch($tit) -and -not $vehContextRx.IsMatch($tit)) { return $false }

    # Stage 4: Positive Motorcycle Identity + Context Signal Gate
    $brand = Resolve-Brand "" $tit ""
    if ($brand -eq $KR_ETC) {
        $brandBody = Resolve-Brand "" $combined ""
        if ($brandBody -eq $KR_ETC -and -not $explicitBikeWordRx.IsMatch($tit)) { return $false }
        if (-not $explicitBikeWordRx.IsMatch($combined)) { return $false }
    }
    if (-not $positiveBikeContextRx.IsMatch($combined)) { return $false }

    $outPriceManwon.Value = $prcMan
    return $true
}

$daangnSeenMap = @{}
$daangnPriceManMap = @{}
$pool = [runspacefactory]::CreateRunspacePool(1, 6)
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
            $prc = 0.0; [void][double]::TryParse([string]$a.price, [ref]$prc)
            $tit = ([string]$a.title -replace '\s+', ' ').Trim()
            $bdy = ([string]$a.content -replace '\s+', ' ').Trim()
            $validMan = 0
            if (-not (Test-IsGenuineDaangnBike $tit $bdy $prc ([ref]$validMan))) { continue }
            $daangnSeenMap[$a.id] = $a
            $daangnPriceManMap[$a.id] = $validMan
        }
    } catch {}
    $j.Pipe.Dispose()
}
$pool.Close(); $pool.Dispose()

# Scan Daangn buy-sell sitemap for additional active nationwide motorcycle slugs & save URL CSV
$daangnSitemapExtraIds = New-Object System.Collections.Generic.List[string]
$daangnAllUrlLines = New-Object System.Collections.Generic.List[string]
$daangnAllUrlLines.Add("collectedDate,slugId,decodedSlug,url")

try {
    $tmpGz = Join-Path $env:TEMP "daangn_bikes_sm_$($PID).xml.gz"
    curl.exe -s -L -A "Mozilla/5.0" "https://www.daangn.com/kr/buy-sell/sitemap-detail.xml.gz" -o $tmpGz
    if (Test-Path $tmpGz) {
        $rawBytes = [System.IO.File]::ReadAllBytes($tmpGz)
        Remove-Item $tmpGz -Force -ErrorAction SilentlyContinue
        if ($rawBytes.Length -gt 2 -and $rawBytes[0] -eq 0x1F -and $rawBytes[1] -eq 0x8B) {
            $ms = New-Object System.IO.MemoryStream(,$rawBytes)
            $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $sr = New-Object System.IO.StreamReader($gz, [System.Text.Encoding]::UTF8)
            $smXml = $sr.ReadToEnd()
            $sr.Close(); $gz.Close(); $ms.Close()
        } else {
            $smXml = [System.Text.Encoding]::UTF8.GetString($rawBytes)
        }

        $smBikeRx = [regex]::new('(?i)(오토바이|스쿠터|pcx|nmax|엔맥스|xmax|엑스맥스|티맥스530|티맥스560|포르자300|포르자350|포르자750|슈퍼커브|헌터커브|혼다-cb|혼다-c125|cbr\d|레블300|레블500|레블1100|골드윙|x-adv|adv125|adv160|adv350|yzf-r|mt-03|mt03|mt-07|mt07|mt-09|mt09|스즈키-gsx|버그만|브이스트롬|가와사키-닌자|할리데이비슨|두카티-파니갈레|두카티-몬스터|베스파-gts|베스파-프리마베라|베스파-스프린트|트라이엄프-본네빌|로얄엔필드|보이저125|보이저300|크루심|다운타운st|시티베스트|아퀼라)', [System.Text.RegularExpressions.RegexOptions]::Compiled)
        $locMs = [regex]::Matches($smXml, '<loc>https://www\.daangn\.com(/kr/buy-sell/[^<]+?)</loc>')
        foreach ($m in $locMs) {
            $relId = $m.Groups[1].Value
            if ($daangnSeenMap.ContainsKey($relId)) { continue }
            $slugDecoded = ([uri]::UnescapeDataString(($relId -replace '^/kr/buy-sell/|-[a-z0-9]{10,14}/?$', '')) -replace '-', ' ').Trim()
            if ($smBikeRx.IsMatch($slugDecoded) -and -not $nonBikeHardRx.IsMatch($slugDecoded) -and -not $partsAlwaysRx.IsMatch($slugDecoded) -and -not $partsEndRx.IsMatch($slugDecoded)) {
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
        try {
            $chkDt = if ($a.boostedAt) { [DateTimeOffset]::Parse([string]$a.boostedAt) } elseif ($a.createdAt) { [DateTimeOffset]::Parse([string]$a.createdAt) } else { $null }
            if ($chkDt -and $chkDt -gt $NewSinceCutoff) { $daangnClosedSample++ }
        } catch {}
        continue
    }
    $stKr = if ($stRaw -eq 'Reserved') { $KR_RESERVED } else { $KR_ONSALE }
    $cleanId = ([string]$a.id -replace '^/kr/buy-sell/|/$', '')
    $daangnActiveIds.Add("DG_" + $cleanId)
    $decSlug = [uri]::UnescapeDataString($cleanId)
    $daangnAllUrlLines.Add("$TodayDate,`"$cleanId`",`"$($decSlug -replace '"','""')`",`"https://www.daangn.com$($a.href)`"")

    $tit = ([string]$a.title -replace '\s+', ' ').Trim()
    $bodyTxt = ([string]$a.content -replace '\s+', ' ').Trim()
    $combinedTxt = "$tit $bodyTxt"

    $createdKst = ""
    if ($a.createdAt) {
        try {
            $dto = [DateTimeOffset]::Parse([string]$a.createdAt).ToOffset([TimeSpan]::FromHours(9))
            $createdKst = $dto.ToString("yyyy-MM-dd HH:mm")
            if ($dto -gt $NewSinceCutoff -or $dto.ToString("yyyy-MM-dd") -eq $TodayDate) { $daangnNewByCreated++ }
        } catch { $createdKst = [string]$a.createdAt }
    }

    $cc = Infer-DisplacementCc $combinedTxt $false 250
    $ccGrp = if ($cc -ge 300) { $daangnOver300++; $KR_OVER300 } else { $daangnUnder300++; $KR_UNDER300 }

    $prcMan = [int]$daangnPriceManMap[$a.id]

    $yr = ""
    $mYr = [regex]::Match($combinedTxt, '(?<!\d)(20\d{2}|\d{2})\s*(?:년식|연식)')
    if ($mYr.Success) {
        $yv = $mYr.Groups[1].Value
        $yr = if ($yv.Length -eq 2) { "20$yv" } else { $yv }
    }

    $kmNum = 0
    $mKm = [regex]::Match($combinedTxt, '(?<!\d)(\d{1,3}(?:,\d{3})+|\d{3,6})\s*(?:km|키로|킬로)')
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

    $brand = Resolve-Brand "" $tit ""
    if ($brand -eq $KR_ETC) { $brand = Resolve-Brand "" $combinedTxt "" }
    $model = Resolve-ModelShort $brand "" $tit

    $row = [pscustomobject][ordered]@{
        collectedDate = $TodayDate
        platform      = $PLAT_DAANGN
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
    $decSlug = [uri]::UnescapeDataString($cleanExtra)
    $daangnAllUrlLines.Add("$TodayDate,`"$cleanExtra`",`"$($decSlug -replace '"','""')`",`"https://www.daangn.com$extraRel`"")
    $slugTitle = ([uri]::UnescapeDataString(($cleanExtra -replace '-[a-z0-9]{10,14}$', '')) -replace '-', ' ').Trim()
    $ccExtra = Infer-DisplacementCc $slugTitle $false 250
    if ($ccExtra -ge 300) { $daangnOver300++ } else { $daangnUnder300++ }
}

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$daangnUrlCsvPath = Join-Path $RawDir "daangn_bike_urls_$($TodayDate).csv"

$daangnTotalCount  = $daangnUnder300 + $daangnOver300
$daangnPortfolio   = Build-BikePortfolioSummary $daangnNormItems.ToArray() $daangnUnder300 $daangnOver300
$daangnSnap        = Compare-And-SaveSnapshot "daangn_bike" $daangnActiveIds.ToArray()
$daangnNewToday    = if ($null -ne $daangnSnap.NewFromDiff -and $daangnSnap.PrevCount -ge 4500 -and $daangnSnap.NewFromDiff -gt $daangnNewByCreated) { $daangnSnap.NewFromDiff } else { $daangnNewByCreated }
$daangnSoldToday   = if ($null -ne $daangnSnap.SoldFromDiff -and $daangnSnap.PrevCount -ge 4500 -and $daangnSnap.SoldFromDiff -gt 0) { $daangnSnap.SoldFromDiff } else { $daangnClosedSample }
$daangnTurnoverPct = if ($daangnTotalCount -gt 0) { [math]::Round(($daangnSoldToday / $daangnTotalCount) * 100, 2) } else { 0 }

Write-Host "   -> Daangn Motorcycles Minimum Verified Floor=$daangnTotalCount (<=299cc: $daangnUnder300, >=300cc: $daangnOver300 | Keywords=$($daangnKeywords.Count)), NewToday=$daangnNewToday, RichSample=$($daangnNormItems.Count)" -ForegroundColor Green

# ==============================================================================
# 2. REITWAGEN (https://www.reitwagen.co.kr/ - Pure Fixed-Price Personal BAREE Used Bikes, Excluding Auction Dummy 135,790,000)
# ==============================================================================
Write-Host "2. Collecting Reitwagen Pure Fixed-Price Personal Used Bikes (Excluding Duplicate/Expired Auctions)..." -ForegroundColor Yellow

function Invoke-ReitwagenOrpc([string]$endpoint, [hashtable]$payload) {
    $bodyStr = (@{ json = $payload } | ConvertTo-Json -Depth 6 -Compress)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyStr)
    for ($att = 1; $att -le 3; $att++) {
        try {
            $req = [System.Net.HttpWebRequest]::Create("https://api.reitwagen.co.kr/api/orpc/$endpoint")
            $req.Method = "POST"; $req.ContentType = "application/json"; $req.UserAgent = "Mozilla/5.0"; $req.Timeout = 25000
            $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
            $txt = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
            return ($txt | ConvertFrom-Json).json
        } catch {
            if ($att -eq 3) { throw }
            Start-Sleep -Milliseconds (1200 * $att)
        }
    }
}

$RW_MAX_FIXED_PRICE = 135780000
$rwTotalCount = 0; $rwOver300Count = 0; $rwUnder300Count = 0; $rwCertifiedCount = 0
$rwNormItems = New-Object System.Collections.Generic.List[object]
$rwNewByPostedAt = 0; $rwSeenIds = @{}

try {
    $rwTotalCount     = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("BAREE"); maxPrice=$RW_MAX_FIXED_PRICE }).count
    $rwOver300Count   = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("BAREE"); maxPrice=$RW_MAX_FIXED_PRICE; minDisplacement=300 }).count
    $rwUnder300Count  = [Math]::Max(0, $rwTotalCount - $rwOver300Count)
    $rwCertifiedCount = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("BAREE_CERTIFIED") }).count

    for ($pg = 0; $pg -lt 40; $pg++) {
        $res = Invoke-ReitwagenOrpc "search/list" @{ page = $pg; skip = ($pg * 20); sourceType = @("BAREE"); maxPrice = $RW_MAX_FIXED_PRICE; sort = @{ field = "postedAt"; order = "desc" } }
        if (-not $res.data -or $res.data.Count -eq 0) { break }
        foreach ($entry in $res.data) {
            $g = $entry.goods
            if (-not $g -or -not $g._id -or $rwSeenIds.ContainsKey($g._id)) { continue }
            if ($null -ne $entry.quotationPublishedAt -or $null -ne $entry.quotationBookEndedAt -or [double]$g.salePrice -eq 135790000) { continue }
            $titRw = [string]$g.title
            if ($titRw -match '(?i)(사발이|\batv\b|4륜|사륜|삼발이|자토바이)') { continue }
            $rwSeenIds[$g._id] = $true

            $postedKst = ""
            if ($g.postedAt) {
                try {
                    $dto = [DateTimeOffset]::Parse([string]$g.postedAt).ToOffset([TimeSpan]::FromHours(9))
                    $postedKst = $dto.ToString("yyyy-MM-dd HH:mm")
                    if ($dto -gt $NewSinceCutoff -or $dto.ToString("yyyy-MM-dd") -eq $TodayDate) { $rwNewByPostedAt++ }
                } catch { $postedKst = [string]$g.postedAt }
            }

            $cc = [int]$g.cylinderCapacity
            $ccGrp = if ($cc -ge 300) { $KR_OVER300 } else { $KR_UNDER300 }
            $prcMan = [int][math]::Round(([double]$g.salePrice) / 10000.0)
            $brand = Resolve-Brand "" $titRw ([string]$g.brandId)
            $model = Resolve-ModelShort $brand "" $titRw
            $sido  = Normalize-Region ([string]$g.locationCategory + " " + [string]$g.address)

            $row = [pscustomobject][ordered]@{
                collectedDate = $TodayDate; platform = $PLAT_RW; bikeId = [string]$g._id
                cc = $cc; ccGroup = $ccGrp; manufacturer = $brand; model = $model
                fullTitle = $titRw; year = [string]$g.modelYear; mileageKm = [int]$g.mileage
                priceManwon = $prcMan; priceBand = Get-BikePriceBand $prcMan; sido = $sido
                sellType = $KR_PERSONAL; status = $KR_ONSALE; registeredAt = $postedKst
                url = "https://www.reitwagen.co.kr/products/detail/$($g.sourceId)"
            }
            $rwNormItems.Add($row); $allRawBikes.Add($row)
        }
    }
} catch { Write-Warning "Reitwagen API error: $_" }

$rwPortfolio   = Build-BikePortfolioSummary $rwNormItems.ToArray() $rwUnder300Count $rwOver300Count
$rwSnap        = Compare-And-SaveSnapshot "reitwagen" @($rwSeenIds.Keys)
$rwNewToday    = $rwNewByPostedAt
$rwSoldToday   = if ($PrevRec -and [int]$PrevRec.reitwagenCount -ge 1000) { [Math]::Max(0, ([int]$PrevRec.reitwagenCount + $rwNewToday - $rwTotalCount)) } else { 0 }
$rwTurnoverPct = if ($rwTotalCount -gt 0) { [math]::Round(($rwSoldToday / $rwTotalCount) * 100, 2) } else { 0 }

Write-Host "   -> Reitwagen Total=$rwTotalCount (<=299cc: $rwUnder300Count, >=300cc: $rwOver300Count), NewToday=$rwNewToday, SoldToday=$rwSoldToday" -ForegroundColor Green

# ==============================================================================
# 3. PASSO BIKE (http://bike.passo.co.kr/bike/ - Used Motorcycle Listings)
# ==============================================================================
Write-Host "3. Collecting Passo Bike Used Listings (Cloud-Accessible Real-Time Feed)..." -ForegroundColor Yellow

$passoAllUsedCount = 0; $passoUnder300Count = 0; $passoOver300Count = 0; $passoTotalCount = 0
$passoNormItems = New-Object System.Collections.Generic.List[object]
$passoSeenIds = @{}; $passoNewByPostedAt = 0

try {
    $passoTotalCount    = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("PASSO") }).count
    $passoOver300Count  = [int](Invoke-ReitwagenOrpc "search/countV2" @{ page=0; skip=0; sourceType=@("PASSO"); minDisplacement=300 }).count
    $passoUnder300Count = [Math]::Max(0, $passoTotalCount - $passoOver300Count)
    $passoAllUsedCount  = $passoTotalCount

    for ($pg = 0; $pg -lt 40; $pg++) {
        $res = Invoke-ReitwagenOrpc "search/list" @{ page = $pg; skip = ($pg * 20); sourceType = @("PASSO"); sort = @{ field = "postedAt"; order = "desc" } }
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
                    if ($dto -gt $NewSinceCutoff -or $dto.ToString("yyyy-MM-dd") -eq $TodayDate) { $passoNewByPostedAt++ }
                } catch { $postedKst = [string]$g.postedAt }
            }

            $rawTitle = ([string]$g.title -replace '\([A-Za-z0-9\-\s&]+\)', ' ' -replace '\s+', ' ').Trim()
            if ($rawTitle -match '(?i)(사발이|(?<![a-z0-9])atv(?![a-z0-9])|(?<![a-z0-9])utv(?![a-z0-9])|아웃랜더|매버릭|4륜|사륜|삼발이|자토바이|제트스키|스노우모빌)') { continue }
            $brand = Resolve-Brand "" $rawTitle ([string]$g.brandId)
            $model = Resolve-ModelShort $brand "" $rawTitle
            $cc = if ($null -ne $g.cylinderCapacity -and [int]$g.cylinderCapacity -gt 0) { [int]$g.cylinderCapacity } else { Infer-DisplacementCc $rawTitle $false 400 }
            $ccGrp = if ($cc -ge 300) { $KR_OVER300 } else { $KR_UNDER300 }
            $prcMan = [int][math]::Round(([double]$g.salePrice) / 10000.0)
            $sido = Normalize-Region ([string]$g.locationCategory + " " + [string]$g.address)
            $pUrl = if ($entry.url) { [string]$entry.url } else { "http://bike.passo.co.kr/bike/" }

            $row = [pscustomobject][ordered]@{
                collectedDate = $TodayDate; platform = $PLAT_PASSO; bikeId = $pIdx
                cc = $cc; ccGroup = $ccGrp; manufacturer = $brand; model = $model
                fullTitle = $rawTitle; year = [string]$g.modelYear; mileageKm = [int]$g.mileage
                priceManwon = $prcMan; priceBand = Get-BikePriceBand $prcMan; sido = $sido
                sellType = $KR_PERSONAL; status = $KR_ONSALE; registeredAt = $postedKst; url = $pUrl
            }
            $passoNormItems.Add($row); $allRawBikes.Add($row)
        }
    }
} catch { Write-Warning "Passo error: $_" }

if ($passoTotalCount -eq 0) { $passoTotalCount = $passoNormItems.Count }
$passoPortfolio   = Build-BikePortfolioSummary $passoNormItems.ToArray() $passoUnder300Count $passoOver300Count
$passoSnap        = Compare-And-SaveSnapshot "passo_used" @($passoSeenIds.Keys)
$passoNewToday    = $passoNewByPostedAt
$passoSoldToday   = if ($PrevRec -and [int]$PrevRec.passoCount -ge 1000) { [Math]::Max(0, ([int]$PrevRec.passoCount + $passoNewToday - $passoTotalCount)) } else { 0 }
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

$btSeenIds = @{}; $btActiveMap = @{}
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
            $req.Method = "GET"; $req.UserAgent = "Mozilla/5.0"; $req.Timeout = 15000
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
                if ($tsMs -lt $Cutoff30dMs) { $reachCutoff = $true; continue }

                $dtObj = [DateTimeOffset]::FromUnixTimeMilliseconds($tsMs).ToOffset([TimeSpan]::FromHours(9))
                $wDate = $dtObj.ToString("yyyy-MM-dd")
                $wFull = $dtObj.ToString("yyyy-MM-dd HH:mm")

                $subj = ([System.Net.WebUtility]::HtmlDecode([string]$a.subject) -replace '\s+', ' ').Trim()
                $head = ([System.Net.WebUtility]::HtmlDecode([string]$a.headName)).Trim()
                if ($subj -match '(?i)(사발이|(?<![a-z0-9])atv(?![a-z0-9])|(?<![a-z0-9])utv(?![a-z0-9])|4륜|사륜|삼발이|자토바이|구합니다|삽니다|매입합니다)' -or $head -match '구매|구함|삽니다') { continue }
                if ($partsAlwaysRx.IsMatch($subj) -or ($partsEndRx.IsMatch($subj) -and -not $vehContextRx.IsMatch($subj))) { continue }

                $saleStat = if ($a.productSale) { [string]$a.productSale.saleStatus } else { "" }
                $isSold = ($subj -match '판매\s*완료|거래\s*완료|판완|완료됨|판매\s*중지된') -or ($head -match '완료') -or ($saleStat -eq 'SOLD_OUT')

                if ($dtObj -gt $NewSinceCutoff -or $wDate -eq $TodayDate) {
                    $btNewTodayCount++
                    if ($isSold) { $btSoldTaggedToday++ }
                }
                if ($isSold) { $btTraded30dCount++; continue }

                $btActiveMap[$aid] = $wDate
                $cc = Infer-DisplacementCc $subj $bm.forceUnder125 400
                $ccGrp = if ($cc -ge 300) { $btOver300Count++; $KR_OVER300 } else { $btUnder300Count++; $KR_UNDER300 }

                $prcMan = if ($a.cost -and [double]$a.cost -ge 300000) { [int][math]::Round(([double]$a.cost) / 10000.0) } else { Parse-TitlePriceManwon $subj }

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
                    collectedDate = $TodayDate; platform = $PLAT_BT; bikeId = "BT$aid"
                    cc = $cc; ccGroup = $ccGrp; manufacturer = $brand; model = $model
                    fullTitle = $subj; year = $yr; mileageKm = 0
                    priceManwon = $prcMan; priceBand = Get-BikePriceBand $prcMan; sido = $sido
                    sellType = $bm.sellType; status = $KR_ONSALE; registeredAt = $wFull
                    url = "https://cafe.naver.com/bikecargogo/$aid"
                }
                $btNormItems.Add($row); $allRawBikes.Add($row)
            }
        } catch {
            Write-Warning "Batumae menu $($bm.menuId) page $pg error: $_"
            break
        }
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
            if ($entry.writeDate -ge $Cutoff29dDate -and -not $btActiveMap.ContainsKey([string]$entry.id)) { $soldCnt++ }
        }
        $btSoldFromDiff = $soldCnt
    } catch {}
}

$btSnapItems = @($btActiveMap.GetEnumerator() | ForEach-Object { [ordered]@{ id = $_.Key; writeDate = $_.Value } })
$btSnapObj = [ordered]@{ date = $TodayDate; updatedAt = $Timestamp; count = $btActiveMap.Count; items = $btSnapItems }
$btSnapJson = $btSnapObj | ConvertTo-Json -Depth 4 -Compress

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
# 6. 4-PLATFORM COMPLETENESS GUARD & PERSIST SNAPSHOTS + DAILY RAW CSV
# ==============================================================================
if ($daangnTotalCount -lt 1000 -or $rwTotalCount -lt 1000 -or $passoTotalCount -lt 1000 -or $btTotalCount -lt 500) {
    $guardMsg = "Daangn=$daangnTotalCount, Reitwagen=$rwTotalCount, Passo=$passoTotalCount, Batumae=$btTotalCount"
    throw "[$Timestamp] Incomplete 4-platform motorcycle collection ($guardMsg). Aborting before writing files so clean DB records are preserved."
}

[System.IO.File]::WriteAllLines($daangnUrlCsvPath, $daangnAllUrlLines, $utf8Bom)
foreach ($sn in @($daangnSnap, $rwSnap, $passoSnap)) {
    if ($null -ne $sn -and $sn.Count -gt 0) {
        [System.IO.File]::WriteAllText($sn.TodaySnapPath, $sn.SnapJson, $utf8NoBom)
        [System.IO.File]::WriteAllText($sn.LatestSnapPath, $sn.SnapJson, $utf8NoBom)
    }
}
[System.IO.File]::WriteAllText($btSnapTodayPath, $btSnapJson, $utf8NoBom)
[System.IO.File]::WriteAllText($btSnapLatestPath, $btSnapJson, $utf8NoBom)

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
# 7. MERGE DAILY SUMMARY DB + DEDUPLICATED CUMULATIVE MASTER DB + INCREMENTAL BUNDLE
# ==============================================================================
$records = @($ExistingRecords)
$defaultMemo = U "5\uB300 \uC624\uD1A0\uBC14\uC774 \uD50C\uB7AB\uD3FC (\uB2F9\uADFC \uCD5C\uC18C\uCE58 \u00B7 \uB77C\uC774\uD2B8\uBC14\uAC90 \u00B7 \uD30C\uC3D8 \u00B7 \uBC14\uD29C\uB9E4 \u00B7 \uCF00\uC774\uCE74 \uBE48\uCE78) \uC790\uB3D9 \uC218\uC9D1"

$newEntry = [ordered]@{
    date                    = $TodayDate
    updatedAt               = $Timestamp
    rawBikeCount            = $allRawBikes.Count
    daangnKeywordCount      = $daangnKeywords.Count
    daangnBikeCount         = $daangnTotalCount
    daangnUnder300Count     = $daangnUnder300
    daangnOver300Count      = $daangnOver300
    daangnOnSaleCount       = $daangnTotalCount
    daangnNewCount          = $daangnNewToday
    daangnSoldCount         = $daangnSoldToday
    daangnTurnoverPct       = $daangnTurnoverPct
    daangnAvgPrice          = $daangnPortfolio.avgPriceManwon
    daangnDiff              = 0
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
$recByDateMap = @{}
for ($i = 0; $i -lt $sortedRecords.Count; $i++) {
    $cur = $sortedRecords[$i]
    $recByDateMap[$cur.date] = $cur
    if (-not $cur.PSObject.Properties['daangnDiff']) { $cur | Add-Member -NotePropertyName 'daangnDiff' -NotePropertyValue 0 -Force }
    if ($i -eq 0) {
        $cur.daangnDiff = 0; $cur.reitwagenDiff = 0; $cur.passoDiff = 0; $cur.batumaeDiff = 0
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

$csvHeader = U (
    "\uC77C\uC790,\uC218\uC9D1\uC2DC\uAC01," +
    "\uB2F9\uADFC(\uCD5C\uC18C\uCE58)_\uC804\uCCB4,\uB2F9\uADFC_300cc\uC774\uD558,\uB2F9\uADFC_300cc\uC774\uC0C1,\uB2F9\uADFC_\uC2E0\uADDC\uB4F1\uB85D,\uB2F9\uADFC_\uC2E0\uADDC\uD310\uB9E4,\uB2F9\uADFC_\uD68C\uC804\uC728(%),\uB2F9\uADFC_\uD3C9\uADE0\uAC00(\uB9CC\uC6D0)," +
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
[System.IO.File]::WriteAllLines((Join-Path $DbDir "bike_daily_summary_db.csv"), $csvLines, $utf8Bom)

# Fast CSV splitter (100x faster than Import-Csv for large master DB & backfill)
$csvSplitRx = [regex]::new('(?:^|,)(?:"((?:[^"]|"")*)"|([^,]*))', [System.Text.RegularExpressions.RegexOptions]::Compiled)
function Split-CsvRow([string]$ln) {
    $ms = $csvSplitRx.Matches($ln)
    $arr = New-Object 'string[]' $ms.Count
    for ($k = 0; $k -lt $ms.Count; $k++) {
        $m = $ms[$k]
        $arr[$k] = if ($m.Groups[1].Success) { $m.Groups[1].Value -replace '""', '"' } else { $m.Groups[2].Value }
    }
    return ,$arr
}

function Parse-BikeRawCsvFast([string]$csvPath) {
    $lines = [System.IO.File]::ReadAllLines($csvPath, [System.Text.Encoding]::UTF8)
    $list = New-Object System.Collections.Generic.List[object]
    for ($li = 1; $li -lt $lines.Length; $li++) {
        $ln = $lines[$li]
        if (-not $ln) { continue }
        $c = Split-CsvRow $ln
        if ($c.Length -lt 17) { continue }
        $ccNum = 0; [void][int]::TryParse(($c[3] -replace '[^\d]',''), [ref]$ccNum)
        $kmNum = 0; [void][int]::TryParse(($c[9] -replace '[^\d]',''), [ref]$kmNum)
        $prNum = 0; [void][int]::TryParse(($c[10] -replace '[^\d]',''), [ref]$prNum)
        $list.Add([pscustomobject][ordered]@{
            collectedDate = $c[0]; platform = $c[1]; bikeId = $c[2]
            cc = $ccNum; ccGroup = $c[4]; manufacturer = $c[5]; model = $c[6]
            fullTitle = $c[7]; year = $c[8]; mileageKm = $kmNum
            priceManwon = $prNum; priceBand = $c[11]; sido = $c[12]
            sellType = $c[13]; status = $c[14]; registeredAt = $c[15]; url = $c[16]
        })
    }
    return $list
}

# 7A. Build Deduplicated Cumulative Master Vehicle DB (database/bike_vehicle_master_db.csv)
#     Keyed by (platform|bikeId) with firstSeenDate, lastSeenDate, and lifecycle status (active vs ended).
#     Includes an 80 MB automatic archive rollover so GitHub's 100 MB file limit is never reached.
$masterDbPath  = Join-Path $DbDir "bike_vehicle_master_db.csv"
$masterHeader  = U "\uCD5C\uCD08\uC218\uC9D1\uC77C,\uCD5C\uC885\uD655\uC778\uC77C,\uD50C\uB7AB\uD3FC,\uB9E4\uBB3CID,\uBC30\uAE30\uB7C9_cc,\uBC30\uAE30\uB7C9\uAD6C\uBD84,\uBE0C\uB79C\uB4DC_\uC81C\uC870\uC0AC,\uBAA8\uB378\uBA85,\uC804\uCCB4\uB9E4\uBB3C\uBA85,\uC5F0\uC2DD,\uC8FC\uD589\uAC70\uB9AC_km,\uD310\uB9E4\uAC00\uACA9_\uB9CC\uC6D0,\uAC00\uACA9\uB300\uAD6C\uAC04,\uC9C0\uC5ED_\uC2DC\uB3C4,\uAC70\uB798\uC720\uD615,\uD310\uB9E4\uC0C1\uD0DC,\uB4F1\uB85D\uC77C\uC2DC,\uC0C1\uC138URL"
$masterDict    = [ordered]@{}

function Upsert-MasterRowFromCols([string[]]$cols, [bool]$is18Col) {
    if ($is18Col) {
        if ($cols.Length -lt 18) { return }
        $fDate = $cols[0]; $lDate = $cols[1]; $plat = $cols[2]; $bid = $cols[3]
        $off = 1
    } else {
        if ($cols.Length -lt 17) { return }
        $fDate = $cols[0]; $lDate = $cols[0]; $plat = $cols[1]; $bid = $cols[2]
        $off = 0
    }
    if (-not $plat -or -not $bid) { return }
    $key = "$plat|$bid"
    if ($masterDict.Contains($key)) {
        $ex = $masterDict[$key]
        if ($fDate -lt $ex.firstSeen) { $fDate = $ex.firstSeen }
    }
    $masterDict[$key] = [pscustomobject]@{
        firstSeen    = $fDate
        lastSeen     = $lDate
        platform     = $plat
        bikeId       = $bid
        cc           = $cols[3 + $off]
        ccGroup      = $cols[4 + $off]
        manufacturer = $cols[5 + $off]
        model        = $cols[6 + $off]
        fullTitle    = $cols[7 + $off]
        year         = $cols[8 + $off]
        mileageKm    = $cols[9 + $off]
        priceText    = $cols[10 + $off]
        priceBand    = $cols[11 + $off]
        sido         = $cols[12 + $off]
        sellType     = $cols[13 + $off]
        status       = $cols[14 + $off]
        registeredAt = $cols[15 + $off]
        url          = $cols[16 + $off]
    }
}

if (Test-Path $masterDbPath) {
    $mLines = [System.IO.File]::ReadAllLines($masterDbPath, [System.Text.Encoding]::UTF8)
    if ($mLines.Length -gt 1) {
        $firstHdr = $mLines[0].TrimStart([char]0xFEFF)
        $is18 = $firstHdr.StartsWith((U "\uCD5C\uCD08\uC218\uC9D1\uC77C,"))
        if ($is18) {
            for ($mi = 1; $mi -lt $mLines.Length; $mi++) {
                if ($mLines[$mi]) { Upsert-MasterRowFromCols (Split-CsvRow $mLines[$mi]) $true }
            }
        } else {
            # One-time migration from 17-column historical CSV files
            $priorRawFiles = @(Get-ChildItem -Path $RawDir -Filter "raw_bikes_20*.csv" | Where-Object { $_.Name -ne "raw_bikes_$($TodayDate).csv" } | Sort-Object Name)
            foreach ($prf in $priorRawFiles) {
                $pLines = [System.IO.File]::ReadAllLines($prf.FullName, [System.Text.Encoding]::UTF8)
                for ($pi = 1; $pi -lt $pLines.Length; $pi++) {
                    if ($pLines[$pi]) { Upsert-MasterRowFromCols (Split-CsvRow $pLines[$pi]) $false }
                }
            }
        }
    }
} else {
    $priorRawFiles = @(Get-ChildItem -Path $RawDir -Filter "raw_bikes_20*.csv" | Where-Object { $_.Name -ne "raw_bikes_$($TodayDate).csv" } | Sort-Object Name)
    foreach ($prf in $priorRawFiles) {
        $pLines = [System.IO.File]::ReadAllLines($prf.FullName, [System.Text.Encoding]::UTF8)
        for ($pi = 1; $pi -lt $pLines.Length; $pi++) {
            if ($pLines[$pi]) { Upsert-MasterRowFromCols (Split-CsvRow $pLines[$pi]) $false }
        }
    }
}

$todayKeySet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($v in $allRawBikes) {
    $k = "$($v.platform)|$($v.bikeId)"
    [void]$todayKeySet.Add($k)
    $fSeen = if ($masterDict.Contains($k)) { $masterDict[$k].firstSeen } else { $TodayDate }
    $prcText = if ($v.priceManwon -gt 0) { [string]$v.priceManwon } else { "" }
    $masterDict[$k] = [pscustomobject]@{
        firstSeen    = $fSeen
        lastSeen     = $TodayDate
        platform     = [string]$v.platform
        bikeId       = [string]$v.bikeId
        cc           = [string]$v.cc
        ccGroup      = [string]$v.ccGroup
        manufacturer = [string]$v.manufacturer
        model        = [string]$v.model
        fullTitle    = [string]$v.fullTitle
        year         = [string]$v.year
        mileageKm    = [string]$v.mileageKm
        priceText    = $prcText
        priceBand    = [string]$v.priceBand
        sido         = [string]$v.sido
        sellType     = [string]$v.sellType
        status       = [string]$v.status
        registeredAt = [string]$v.registeredAt
        url          = [string]$v.url
    }
}

foreach ($entry in $masterDict.Values) {
    $k = "$($entry.platform)|$($entry.bikeId)"
    if (-not $todayKeySet.Contains($k) -and $entry.lastSeen -lt $TodayDate) {
        if ($entry.status -eq $KR_ONSALE -or $entry.status -eq $KR_RESERVED) {
            $entry.status = $KR_ENDED
        }
    }
}

function Format-MasterCsvLine($m) {
    return "{0},{1},`"{2}`",`"{3}`",{4},`"{5}`",`"{6}`",`"{7}`",`"{8}`",`"{9}`",{10},{11},`"{12}`",`"{13}`",`"{14}`",`"{15}`",`"{16}`",`"{17}`"" -f `
        $m.firstSeen, $m.lastSeen, $m.platform, ($m.bikeId -replace '"','""'), $m.cc, $m.ccGroup, `
        ($m.manufacturer -replace '"','""'), ($m.model -replace '"','""'), ($m.fullTitle -replace '"','""'), `
        $m.year, $m.mileageKm, $m.priceText, $m.priceBand, ($m.sido -replace '"','""'), `
        $m.sellType, $m.status, $m.registeredAt, $m.url
}

$masterOutLines = New-Object System.Collections.Generic.List[string]
$masterOutLines.Add($masterHeader)
foreach ($m in $masterDict.Values) { $masterOutLines.Add((Format-MasterCsvLine $m)) }

# Safety valve: if master DB ever exceeds 80 MB (~200k+ unique motorcycles), archive older ended listings so file stays well under GitHub's 100 MB limit
$approxMasterBytes = $masterOutLines.Count * 380
if ($approxMasterBytes -gt 80MB) {
    $archivePath = Join-Path $DbDir "bike_vehicle_master_archive_$($NowKst.Year).csv"
    $archCutoff  = $NowKst.AddDays(-90).ToString("yyyy-MM-dd")
    $archLines   = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path $archivePath)) { $archLines.Add($masterHeader) }
    $trimmedLines = New-Object System.Collections.Generic.List[string]
    $trimmedLines.Add($masterHeader)
    foreach ($m in $masterDict.Values) {
        $ln = Format-MasterCsvLine $m
        if ($m.status -eq $KR_ENDED -and $m.lastSeen -lt $archCutoff) { $archLines.Add($ln) }
        else { $trimmedLines.Add($ln) }
    }
    if ($archLines.Count -gt 0) { [System.IO.File]::AppendAllLines($archivePath, $archLines, $utf8Bom) }
    $masterOutLines = $trimmedLines
}
[System.IO.File]::WriteAllLines($masterDbPath, $masterOutLines, $utf8Bom)

# 7B. Incremental Date-Specific Portfolio Cache (database/portfolio_by_date.json) & Archive Manifest (database/db_manifest.json)
$pfCachePath  = Join-Path $DbDir "portfolio_by_date.json"
$manifestPath = Join-Path $DbDir "db_manifest.json"

$cachedPfMap = @{}
if (Test-Path $pfCachePath) {
    try {
        $pfRawObj = [System.IO.File]::ReadAllText($pfCachePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($prop in $pfRawObj.PSObject.Properties) {
            if ($prop.Name -ne "ALL" -and $prop.Name -match '^20\d{2}-\d{2}-\d{2}$') {
                $cachedPfMap[$prop.Name] = $prop.Value
            }
        }
    } catch {}
}

$cachedManifestMap = @{}
if (Test-Path $manifestPath) {
    try {
        $mRawObj = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($me in @($mRawObj)) {
            if ($me -and $me.date) { $cachedManifestMap[[string]$me.date] = $me }
        }
    } catch {}
}

$rawFiles = @(Get-ChildItem -Path $RawDir -Filter "raw_bikes_20*.csv" | Sort-Object Name)
$portfolioByDate = [ordered]@{}
$manifestEntries = New-Object System.Collections.Generic.List[object]

foreach ($rf in $rawFiles) {
    $dStr = ($rf.BaseName -replace '^raw_bikes_', '')
    $recD = $recByDateMap[$dStr]
    $urlRel = if (Test-Path (Join-Path $RawDir "daangn_bike_urls_$dStr.csv")) { "raw_data/daangn_bike_urls_$dStr.csv" } else { "" }

    if ($dStr -eq $TodayDate) {
        $portfolioByDate[$dStr] = [ordered]@{
            updatedAt = $Timestamp
            daangn    = $daangnPortfolio
            reitwagen = $rwPortfolio
            passo     = $passoPortfolio
            batumae   = $btPortfolio
            kcar      = [ordered]@{ notOperated = $true; sampleSize = 0 }
        }
        $manifestEntries.Add([ordered]@{
            date           = $dStr
            updatedAt      = $Timestamp
            rawCsvPath     = "raw_data/raw_bikes_$dStr.csv"
            daangnUrlPath  = $urlRel
            bikeCount      = $allRawBikes.Count
            daangnCount    = $daangnNormItems.Count
            reitwagenCount = $rwNormItems.Count
            passoCount     = $passoNormItems.Count
            batumaeCount   = $btNormItems.Count
        })
    } elseif ($cachedPfMap.ContainsKey($dStr) -and $cachedManifestMap.ContainsKey($dStr)) {
        $portfolioByDate[$dStr] = $cachedPfMap[$dStr]
        $manifestEntries.Add($cachedManifestMap[$dStr])
    } else {
        $dayItems = @(Parse-BikeRawCsvFast $rf.FullName)
        $dgItemsD = @($dayItems | Where-Object { $_.platform -eq $PLAT_DAANGN })
        $rwItemsD = @($dayItems | Where-Object { $_.platform -eq $PLAT_RW })
        $psItemsD = @($dayItems | Where-Object { $_.platform -eq $PLAT_PASSO })
        $btItemsD = @($dayItems | Where-Object { $_.platform -eq $PLAT_BT })

        $portfolioByDate[$dStr] = [ordered]@{
            updatedAt = if ($recD) { $recD.updatedAt } else { $dStr }
            daangn    = Build-BikePortfolioSummary $dgItemsD $(if ($recD -and $recD.daangnUnder300Count) { [int]$recD.daangnUnder300Count } else { 0 }) $(if ($recD -and $recD.daangnOver300Count) { [int]$recD.daangnOver300Count } else { 0 })
            reitwagen = Build-BikePortfolioSummary $rwItemsD $(if ($recD) { [int]$recD.reitwagenUnder300Count } else { 0 }) $(if ($recD) { [int]$recD.reitwagenOver300Count } else { 0 })
            passo     = Build-BikePortfolioSummary $psItemsD $(if ($recD) { [int]$recD.passoUnder300Count } else { 0 }) $(if ($recD) { [int]$recD.passoOver300Count } else { 0 })
            batumae   = Build-BikePortfolioSummary $btItemsD $(if ($recD) { [int]$recD.batumaeUnder300Count } else { 0 }) $(if ($recD) { [int]$recD.batumaeOver300Count } else { 0 })
            kcar      = [ordered]@{ notOperated = $true; sampleSize = 0 }
        }
        $manifestEntries.Add([ordered]@{
            date           = $dStr
            updatedAt      = if ($recD) { $recD.updatedAt } else { $dStr }
            rawCsvPath     = "raw_data/raw_bikes_$dStr.csv"
            daangnUrlPath  = $urlRel
            bikeCount      = $dayItems.Count
            daangnCount    = $dgItemsD.Count
            reitwagenCount = $rwItemsD.Count
            passoCount     = $psItemsD.Count
            batumaeCount   = $btItemsD.Count
        })
    }
}

function Merge-PlatformPortfolios([object[]]$pfList) {
    $sampleSum = 0; $pricedSum = 0; $weightedPrcSum = 0.0; $uSum = 0; $oSum = 0
    $pbMap = [ordered]@{ $PB_1 = 0; $PB_2 = 0; $PB_3 = 0; $PB_4 = 0; $PB_5 = 0 }
    $btMap = [ordered]@{ $BT_SCOOTER = 0; $BT_NAKED = 0; $BT_SPORT = 0; $BT_TOURER = 0; $BT_CRUISER = 0; $BT_CLASSIC = 0; $BT_OTHER = 0 }
    $regMap = @{}; $modMap = @{}; $brdMap = @{}

    foreach ($p in $pfList) {
        if (-not $p) { continue }
        $s = [int]$p.sampleSize
        $ps = if ($null -ne $p.pricedSampleSize) { [int]$p.pricedSampleSize } else { $s }
        $sampleSum += $s; $pricedSum += $ps
        $weightedPrcSum += ([double]$p.avgPriceManwon * $ps)
        $uSum += [int]$p.under300Count; $oSum += [int]$p.over300Count

        if ($p.priceBands) {
            foreach ($prp in $p.priceBands.PSObject.Properties) {
                if ($pbMap.Contains($prp.Name)) { $pbMap[$prp.Name] = [int]$pbMap[$prp.Name] + [int]$prp.Value }
            }
            if ($p.priceBands -is [System.Collections.IDictionary]) {
                foreach ($k in $p.priceBands.Keys) {
                    if ($pbMap.Contains($k)) { $pbMap[$k] = [int]$pbMap[$k] + [int]$p.priceBands[$k] }
                }
            }
        }
        if ($p.bikeTypes) {
            foreach ($prp in $p.bikeTypes.PSObject.Properties) {
                if ($btMap.Contains($prp.Name)) { $btMap[$prp.Name] = [int]$btMap[$prp.Name] + [int]$prp.Value }
            }
            if ($p.bikeTypes -is [System.Collections.IDictionary]) {
                foreach ($k in $p.bikeTypes.Keys) {
                    if ($btMap.Contains($k)) { $btMap[$k] = [int]$btMap[$k] + [int]$p.bikeTypes[$k] }
                }
            }
        }
        foreach ($it in @($p.topRegions)) { if ($it -and $it.name) { $regMap[[string]$it.name] = [int]$regMap[[string]$it.name] + [int]$it.count } }
        foreach ($it in @($p.topModels))  { if ($it -and $it.name) { $modMap[[string]$it.name] = [int]$modMap[[string]$it.name] + [int]$it.count } }
        foreach ($it in @($p.topBrands))  { if ($it -and $it.name) { $brdMap[[string]$it.name] = [int]$brdMap[[string]$it.name] + [int]$it.count } }
    }

    $ccTot = [Math]::Max(1, ($uSum + $oSum))
    return [ordered]@{
        sampleSize       = $sampleSum
        pricedSampleSize = $pricedSum
        under300Count    = $uSum
        over300Count     = $oSum
        under300Ratio    = [math]::Round(($uSum / $ccTot) * 100, 1)
        over300Ratio     = [math]::Round(($oSum / $ccTot) * 100, 1)
        avgPriceManwon   = if ($pricedSum -gt 0) { [int][math]::Round($weightedPrcSum / $pricedSum) } else { 0 }
        priceBands       = $pbMap
        bikeTypes        = $btMap
        topRegions       = @($regMap.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 8  | ForEach-Object { [ordered]@{ name = $_.Key; count = $_.Value } })
        topModels        = @($modMap.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object { [ordered]@{ name = $_.Key; count = $_.Value } })
        topBrands        = @($brdMap.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 8  | ForEach-Object { [ordered]@{ name = $_.Key; count = $_.Value } })
    }
}

$dateKeysOnly = @($portfolioByDate.Keys)
$portfolioByDate["ALL"] = [ordered]@{
    updatedAt = "ALL"
    daangn    = Merge-PlatformPortfolios @($dateKeysOnly | ForEach-Object { $portfolioByDate[$_].daangn })
    reitwagen = Merge-PlatformPortfolios @($dateKeysOnly | ForEach-Object { $portfolioByDate[$_].reitwagen })
    passo     = Merge-PlatformPortfolios @($dateKeysOnly | ForEach-Object { $portfolioByDate[$_].passo })
    batumae   = Merge-PlatformPortfolios @($dateKeysOnly | ForEach-Object { $portfolioByDate[$_].batumae })
    kcar      = [ordered]@{ notOperated = $true; sampleSize = 0 }
}

$pfByDateJson = $portfolioByDate | ConvertTo-Json -Depth 7
[System.IO.File]::WriteAllText($pfCachePath, $pfByDateJson, $utf8NoBom)

$manifestJson = ConvertTo-Json -InputObject @($manifestEntries.ToArray()) -Depth 4
if ($manifestEntries.Count -eq 1 -and -not $manifestJson.TrimStart().StartsWith("[")) {
    $manifestJson = "[`r`n" + $manifestJson + "`r`n]"
}
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)

# Build snappy browser search preview (latest 2 dates up to 20,000 rows so JS bundle stays ~6-7 MB forever)
$browserItems = New-Object System.Collections.Generic.List[object]
if ($rawFiles.Count -ge 2) {
    $prevRawFile = $rawFiles[$rawFiles.Count - 2]
    if ($prevRawFile.Name -ne "raw_bikes_$($TodayDate).csv") {
        foreach ($pi in @(Parse-BikeRawCsvFast $prevRawFile.FullName)) { $browserItems.Add($pi) }
    }
}
foreach ($ti in $allRawBikes) { $browserItems.Add($ti) }
$rawForBrowser  = @($browserItems.ToArray() | Select-Object -Last 20000)
$rawBrowserJson = $rawForBrowser | ConvertTo-Json -Depth 4 -Compress

$latestPortfolio = $portfolioByDate[$TodayDate]
$pfLatestJson    = $latestPortfolio | ConvertTo-Json -Depth 6

$jsContent = @"
// Auto-generated 5-Platform Used Motorcycle Apple-to-Apple Intelligence Bundle ($Timestamp)
window.COMPETITOR_TREND_LAST_UPDATED = "$Timestamp";
window.COMPETITOR_TREND_DATA = $jsonOutput;
window.COMPETITOR_PORTFOLIO_DATA = $pfLatestJson;
window.COMPETITOR_PORTFOLIO_BY_DATE = $pfByDateJson;
window.COMPETITOR_RAW_PREVIEW = $rawBrowserJson;
window.COMPETITOR_RAW_TOTAL_COUNT = $($masterDict.Count);
window.COMPETITOR_DB_ARCHIVE = $manifestJson;
"@
[System.IO.File]::WriteAllText($JsPath, $jsContent, $utf8NoBom)

# Stamp fresh cache-buster ?v=yyyyMMddHHmm into index.html & competitor_trend.html so repeat visitors never get stale cached JS
foreach ($htmlName in @("index.html", "competitor_trend.html")) {
    $hp = Join-Path $WorkDir $htmlName
    if (Test-Path $hp) {
        $ht = [System.IO.File]::ReadAllText($hp, [System.Text.Encoding]::UTF8)
        $htNew = [regex]::Replace($ht, 'competitor_trend_data\.js(\?v=[^"'']+)?', "competitor_trend_data.js?v=$CacheVer")
        if ($htNew -ne $ht) { [System.IO.File]::WriteAllText($hp, $htNew, $utf8NoBom) }
    }
}

Write-Host "[$Timestamp] Completed! Today RAW Bikes: $($allRawBikes.Count) | Unique Cumulative Master DB: $($masterDict.Count)" -ForegroundColor Cyan
Write-Host "  - Master DB CSV    : $masterDbPath"
Write-Host "  - Daily Summary CSV: $CsvPath"
