# WeaponsArchive

An archive of 15 modern weapons made in Europe or the USA. It's meant as source material for point clouds in TouchDesigner. Research date: **2026-11-20**.

All the data is in `weapons.json`: name, maker, factories (city and country), buyers, past wars, current wars, a 3D model search link and point-cloud notes. TD can read it with a JSON DAT or a Python table.

| # | Object | Unit cost | Built / sold |
|---|---|---|---|
| 1 | F-35 Lightning II | ~$92M (A) / $121M (B) | 1,387 delivered |
| 2 | Eurofighter Typhoon | ~€100-140M | 618 delivered / 769 ordered |
| 3 | AH-64E Apache | ~$35-52M | ~2,500 Apaches, 800+ E-model |
| 4 | MQ-9 Reaper | ~$30M (system of 4 >$100M) | ~366 USAF + exports |
| 5 | Switchblade 600 | est. $70-175k | not disclosed |
| 6 | M142 HIMARS | ~$5M launcher, ~$200k rocket | ~750 launchers |
| 7 | Patriot PAC-3 MSE | battery $0.5-1B+, missile ~$4-5.3M | ~600 missiles/yr |
| 8 | IRIS-T SLM | fire unit ~€140-180M | Ukraine 11 systems |
| 9 | Storm Shadow / SCALP | ~£1-2M | ~2,000-3,000 |
| 10 | Javelin | ~$217k missile + $250k launcher | 50,000+ missiles |
| 11 | NLAW | ~$30-40k | 24,200+ |
| 12 | Leopard 2A8 | ~€27.6-34.4M | ~3,600 Leopard 2 total |
| 13 | CAESAR | ~€3.2-7.25M | ~700+ ordered |
| 14 | 155mm shell | ~$8,000 | US 36k/month; EU target 2M/yr |
| 15 | GBU-39 SDB | ~$40k | 17,000+ |

Factories, buyers and wars per object are in `weapons.json`.

## Caveats
- Costs and quantities are the best public estimates found (2026-11-20). Sources often disagree, so treat them as order of magnitude. Details per item are in `weapons.json` (`unit_cost`, `quantity_built_or_sold`).
- The buyer lists cover the main operators and orders. They aren't complete. Check exact deliveries in the [SIPRI Arms Transfers Database](https://www.sipri.org/databases/armstransfers).
- War status is as of 20 Nov 2026. Ukraine: the front is stalled and talks are deadlocked. Gaza: the October 2025 ceasefire is close to collapse. Iran war: started Feb/Mar 2026, current status not verified.
- `model_search` links open Sketchfab filtered to downloadable models. Check the licence of each model before using it.

## Point cloud pipeline (TD)
Download a glTF/FBX/OBJ model, load it with File In SOP/POP, sample points on the surface, render as point sprites.
Easiest to start with (most free models available): F-35, Apache, Leopard 2, Eurofighter, Javelin.

## Deaths (estimate)
No public source counts deaths per weapon system. Below: the best documented strike where the weapon was identified, or "no public count". Wider campaign totals (all weapons, not attributable) are in `weapons.json` → `deaths.context`.

| # | Object | Documented |
|---|---|---|
| 1 | F-35 | no public count (used in Gaza and Iran 2026 air campaigns) |
| 2 | Eurofighter | no public count (Saudi air war in Yemen: 8,759 civilians, all aircraft) |
| 3 | Apache | ~12 killed incl. 2 Reuters journalists, Baghdad 2007 |
| 4 | MQ-9 | 10 civilians incl. 7 children, Kabul 2021; US drone campaigns 2010-20: 910-2,200 civilians (incl. Predator) |
| 5 | Switchblade | no public count |
| 6 | HIMARS | 89 (Russia) to ~400 (Ukraine claim) Russian soldiers, Makiivka 2023 |
| 7 | Patriot | 3 allied aircrew, friendly fire 2003 (defensive system) |
| 8 | IRIS-T | none known (defensive) |
| 9 | Storm Shadow | 1 (Russia) to 34 (Ukraine claim) officers, Sevastopol 2023 |
| 10 | Javelin | no public count |
| 11 | NLAW | no public count |
| 12 | Leopard 2 | no public count |
| 13 | CAESAR | no public count (2019 leak: 436,370 Yemeni civilians within range of Saudi guns) |
| 14 | 155mm | not attributable; artillery est. main killer in Ukraine early in the war |
| 15 | GBU-39 | 45 killed, Rafah tent camp, May 2024 |
