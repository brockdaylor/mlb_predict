# MLB 2026 Analysis Results Summary
**Generated:** 2026-06-18 | **Project:** mlb_predict | **Owner:** Brock Daylor

---

## Pipeline Status

| Step | Status | Output |
|------|--------|--------|
| openxlsx2 install | ✅ Complete | renv.lock updated |
| Statcast pull | ✅ Complete | 18,387 K events, 2026-03-26 → 2026-06-18 |
| xBA-BA Gap analysis | ✅ Complete | `output/tables/xba_ba_gap_2026.xlsx` (3 sheets) |
| Backwards-K analysis | ✅ Complete | `output/tables/backwards_k_2026.xlsx` (3 sheets) |
| Git commit/push | ⚠️ Pending | HEAD.lock conflict (RStudio holding lock) — run `git commit -m "Run 2026 analysis"` manually after closing RStudio git pane |

---

## Analysis 1: xBA vs BA Gap (2026)

**Source:** FanGraphs `fg_batters_all.parquet` | **Filter:** 2026 season, 50+ AB  
**Output:** `output/tables/xba_ba_gap_2026.xlsx` — sheets: MLB_Top200, Twins, All_50AB  
**Figures:** `xba_ba_gap_mlb_2026.png`, `xba_ba_gap_twins_2026.png`

**Universe:** 403 MLB qualifiers | 14 Twins qualifiers

### Most Unlucky Hitters (xAVG >> AVG — due for positive regression)

| Player | Team | AB | BA | xAVG | Gap |
|--------|------|----|----|------|-----|
| Ke'Bryan Hayes | CIN | 120 | .142 | .259 | +.118 |
| Jahmai Jones | DET | 79 | .139 | .239 | +.100 |
| Mookie Betts | LAD | 130 | .185 | .267 | +.083 |
| Edmundo Sosa | PHI | 99 | .202 | .282 | +.080 |
| Bo Naylor | CLE | 84 | .143 | .220 | +.077 |
| Blake Perkins | MIL | 71 | .113 | .188 | +.075 |
| Ha-Seong Kim | ATL | 52 | .096 | .172 | +.075 |
| Lawrence Butler | ATH | 164 | .165 | .239 | +.075 |
| Jake Cronenworth | SDP | 97 | .144 | .219 | +.074 |
| Rafael Marchán | PHI | 68 | .103 | .174 | +.071 |

**Headline finding:** Ke'Bryan Hayes is the most luck-suppressed hitter in MLB — his .142 BA is masking a .259 xAVG. That's a 118-point gap on 120 ABs; if his BABIP normalizes he's a .240+ hitter by August. Mookie Betts at .185/.267 is similarly worth buying low if he hits the trade market. Lawrence Butler (ATH) leads the group in volume with 164 ABs, suggesting his gap is durable signal, not noise.

### Most Lucky Hitters (AVG >> xAVG — regression risk)

| Player | Team | AB | BA | xAVG | Gap |
|--------|------|----|----|------|-----|
| Henry Bolte | ATH | 81 | .296 | .211 | -.085 |
| Colt Emerson | SEA | 62 | .242 | .159 | -.083 |
| Andrew Vaughn | MIL | 92 | .370 | .292 | -.078 |
| Taylor Trammell | HOU | 69 | .275 | .203 | -.072 |
| Joey Wiemer | WSN | 70 | .286 | .217 | -.069 |

**Headline finding:** Andrew Vaughn's .370 BA is the most visually alarming given his sample size (92 AB). His xAVG of .292 is still solid, but expect .340 → .290 mean reversion over the next 100 ABs. Colt Emerson's .242/.159 spread is severe for only 62 ABs — small sample lottery ball.

### Twins Hitters
14 Twins qualified (50+ AB). Individual breakdown in **Twins tab of `xba_ba_gap_2026.xlsx`**. Key question to check: are any Twins hitters showing large positive gaps (unlucky) that suggest lineup value is being understated?

---

## Analysis 2: Backwards-K Rate (2026)

**Source:** Statcast `statcast_strikeouts_2026.parquet` (18,387 K events)  
**Filter:** MLB leaders = 30+ total Ks | Twins = all pitchers regardless  
**Output:** `output/tables/backwards_k_2026.xlsx` — sheets: MLB_Top100, Twins, All_Pitchers  
**Figures:** `backwards_k_rate_mlb_2026.png`, `backwards_k_rate_twins_2026.png`, `backwards_k_pitch_mix_2026.png`

**Universe:** 679 total pitchers | 252 qualified (30+ K) | 24 Twins pitchers

### MLB Top 10: Highest Called-K Rate

| Pitcher | Team | Total K | Called K | Called K% |
|---------|------|---------|----------|-----------|
| Faucher, Calvin | MIA | 34 | 15 | 44.1% |
| Bender, Anthony | MIA | 36 | 15 | 41.7% |
| Klein, Will | LAD | 32 | 13 | 40.6% |
| Junk, Janson | MIA | 43 | 17 | 39.5% |
| Raley, Brooks | NYM | 31 | 12 | 38.7% |
| Warren, Will | NYY | 76 | 29 | 38.2% |
| Montero, Keider | DET | 50 | 19 | 38.0% |
| Lowder, Rhett | CIN | 37 | 14 | 37.8% |
| McLean, Nolan | NYM | 97 | 36 | 37.1% |
| Mikolas, Miles | WSH | 41 | 15 | 36.6% |

**Headline finding:** Miami is running a command-first pitching lab — three Marlins (Faucher, Bender, Junk) sit in the top 4, suggesting a systematic approach. Will Warren (NYY, 76 K) is the highest-volume pitcher in the top 10 at 38.2%, making him a legitimate high-leverage target. Nolan McLean (NYM) leads all qualified pitchers in raw called-K volume at 36.

### Twins Pitchers (Full Roster, 2026)

| Pitcher | Total K | Called K | Called K% | Notes |
|---------|---------|----------|-----------|-------|
| Laweryson, Cody | 17 | 7 | 41.2% | Small sample, but elite rate |
| Paredes, Mike | 10 | 4 | 40.0% | Very small sample |
| Abel, Mick | 23 | 9 | 39.1% | Promising young arm |
| Sands, Cole | 11 | 4 | 36.4% | |
| Rogers, Taylor | 24 | 8 | 33.3% | |
| Topa, Justin | 12 | 4 | 33.3% | |
| Morris, Andrew | 36 | 12 | 33.3% | Enough volume to trust rate |
| Bradley, Taj | 80 | 25 | 31.2% | High-volume starter, solid rate |
| Woods Richardson, Simeon | 26 | 8 | 30.8% | |
| **Ryan, Joe** | **92** | **28** | **30.4%** | **Twins ace, most meaningful rate** |
| Orze, Eric | 30 | 9 | 30.0% | |
| Prielipp, Connor | 51 | 15 | 29.4% | |
| Rojas, Kendry | 14 | 4 | 28.6% | |
| **Ober, Bailey** | **46** | **13** | **28.3%** | **Notable: lower than Ryan** |
| Lawrence, Justin | 8 | 2 | 25.0% | |
| Matthews, Zebby | 34 | 8 | 23.5% | |
| Acton, Garrett | 9 | 2 | 22.2% | |
| Adams, Travis | 20 | 4 | 20.0% | |
| Funderburk, Kody | 10 | 1 | 10.0% | |
| Gómez, Yoendrys | 21 | 2 | 9.5% | Pure swing-and-miss |
| García, Luis | 2 | 0 | 0.0% | |
| Banda, Anthony | 27 | 0 | **0.0%** | **All 27 Ks are swinging — pure stuff** |
| Kent, Zak | 2 | 0 | 0.0% | |
| Klein, John | 2 | 0 | 0.0% | |

**Twins headline findings:**

- **Joe Ryan** (92 K, 30.4%) is the Twins' most durable backwards-K pitcher by volume. His rate is respectable but not elite — he lives on swings, which makes his performance more weather-sensitive to count leverage and sequencing.
- **Taj Bradley** (80 K, 31.2%) is quietly one of the better command-K starters in the MIN rotation. His rate is marginally better than Ryan's on meaningful volume.
- **Mick Abel** (23 K, 39.1%) is the most interesting prospect-level finding: his called-K rate ranks inside the MLB top 20 if he stays there on larger samples. Worth watching as his workload expands.
- **Andrew Morris** (36 K, 33.3%) is a reliable middle-relief called-strike guy — legitimately useful in high-leverage count-protection situations.
- **Anthony Banda** (27 K, 0.0%) is pure swing-or-nothing: not a single called third strike all season. He relies entirely on movement and velocity; he's vulnerable if batters lay off.
- **Bailey Ober** (46 K, 28.3%) is slightly below Ryan, suggesting he's more reliant on chase than command. Might underperform in favorable counts if hitters stop expanding.

---

## Suggested Next Analyses

1. **xBA-BA Gap × BABIP decomposition** — Correlate the xAVG-AVG gap with BABIP for the 403 qualifiers to isolate how much of the gap is BABIP-driven vs. exit-velocity profile changes. Regression candidates should have both high gap AND high BABIP.

2. **Twins roster xBA-BA deep dive** — Pull the Twins tab from `xba_ba_gap_2026.xlsx` and cross with RotoWire/daily lineup data to identify any unlucky Twins hitters (positive gap) who are currently benched or in platoon — potential internal activation candidates.

3. **Backwards-K pitch mix analysis** — The pitch mix figure (`backwards_k_pitch_mix_2026.png`) shows aggregate breakdowns; next step is filtering: what pitch types generate called Ks for Twins pitchers specifically? If Riley/Bradley called Ks are heavily fastball-count, that predicts fatigue vulnerability late in games.

4. **Platoon splits for backwards-K leaders** — Do pitchers like Ryan and Bradley maintain their called-K rates vs. both handedness matchups, or is the rate LHH/RHH skewed? Identifying platoon dependency would refine roster usage recommendations.

5. **xwOBA vs wRC+ gap analysis** — Mirror the xBA-BA logic but at the plate-discipline level. FanGraphs `xwOBA` is already in the processed data. A large xwOBA-vs-wRC+ gap captures luck at the production level, not just hit rate — more actionable for DFS/fantasy targeting.

6. **Statcast expansion: count leverage × backwards-K** — Pull pitch-level count data (not just K outcomes) to compute called-strike rate by count state (0-2 vs 1-2 vs 2-2). Pitchers who get called Ks disproportionately on full counts are pitching to contact early and command only late — a fragile profile.

---

*All output files:* `output/tables/` and `output/figures/` in the mlb_predict project.  
*Raw data:* `data/raw/statcast/statcast_strikeouts_2026.parquet` (18,387 rows) and `data/processed/fg_batters_all.parquet`.
