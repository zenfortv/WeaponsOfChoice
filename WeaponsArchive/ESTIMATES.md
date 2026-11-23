# Death estimates per object - method (2026-11-20)

No archive counts deaths per weapon system. This file shows three levels, which are never mixed:

1. **DOCUMENTED**: single strikes where the weapon was identified from fragments or official statements. This is a floor.
2. **ARCHIVE TOTAL**: deaths in the whole campaign, from all weapons, taken from a recognised archive.
3. **ESTIMATE (MODEL)**: `campaign deaths x share caused by this type of attack x share of this weapon`. Results are low-high ranges. The shares are assumptions, listed below. Read every number as an order of magnitude, not a count.

## Archives used
| Archive | What it gives | Used for |
|---|---|---|
| Gaza Ministry of Health (via UN / Wikipedia, Sep 2026) | ~73,900 Palestinians killed | F-35, GBU-39 |
| Spagat et al. household survey | 75,200 violent deaths in Gaza, "vast majority by Israeli munitions" | cross-check |
| SIPRI Arms Transfers 2021-25 | Israel: 68% of imports from the US, 31% from Germany. Saudi Arabia: 77% from the US | buyer -> campaign link |
| FlightGlobal World Air Forces 2026 | Israeli fighters: 284 front-line, 45-48 of them F-35I | F-35 share |
| Bureau of Investigative Journalism | US drone and covert strikes: 6,263-9,049 killed since 2010; 910-2,200 civilians 2010-20 | MQ-9 |
| Airwars | 22,679+ civilians killed by US air strikes since 9/11 | context |
| Hengaw / HRANA / NIAC | 2026 Iran war: 3,375-7,650 killed in Iran (Feb-Apr) | F-35 |
| Mediazona / Meduza (probate registry) | ~352,000 Russian soldiers killed to end of 2025; 248,000+ named | HIMARS, 155mm |
| CNN / NYT / NPR / Sky munition analyses | GBU-39 identified at Rafah tent camp (45), Nuseirat school (32-45), al-Tabi'in school (80-93) | GBU-39 documented |
| Yemen Data Project | 8,759 civilians killed by Saudi/UAE coalition air raids 2015-22 | context (Apache, Saudi buyers) |

## Models
| Object | Formula | Estimate | Confidence |
|---|---|---|---|
| F-35 | Gaza 73,900 x 50-80% air-delivered x 5-16% F-35 share; plus Iran 3,375-7,650 x 10-30% | ~2,200 - 11,800 killed (civilians and fighters) | low |
| MQ-9 | US drone/covert strikes since 2010, 6,263-9,049 x 50-90% flown by MQ-9 (rest MQ-1 Predator and others) | ~3,100 - 8,100 killed, of whom ~450 - 2,000 civilians | medium-low |
| HIMARS | Russian dead 352,000 x 30-60% killed by artillery/rockets x 1-4% HIMARS share | ~1,000 - 8,400 soldiers | very low |
| 155mm shell | Russian dead 352,000 x 30-60% artillery x 30-60% NATO 155 mm share of Ukrainian fire | ~32,000 - 127,000 soldiers | low |
| GBU-39 | Gaza 73,900 x 50-80% air-delivered x 3-10% GBU-39 share of bombs | ~1,100 - 5,900 killed; documented floor 157-183 | low |
| Apache, Switchblade, Patriot, Javelin, Leopard 2, armed DJI | no data on shares - **no model**, documented incidents only | - | - |

## Assumptions to check before showing large
- **Air-delivered share of Gaza deaths (50-80%):** this is an assumption. Studies say "vast majority by Israeli munitions" but give no percentage for air strikes.
- **F-35 share (5-16%):** the upper bound is the F-35's share of the fighter fleet. Sortie shares are not public.
- **Artillery share of Russian deaths (30-60%):** early-war estimates were around 80% (contested). Drones overtook artillery by 2026.
- **NATO 155 mm share of Ukrainian artillery fire (30-60%):** an assumption based on deliveries of millions of shells as Soviet 152 mm stocks ran down.
- **HIMARS share (1-4%):** few rockets, but high lethality against concentrated targets (Makiivka). Very uncertain.
