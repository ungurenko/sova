# Картинки лендинга Sova

Образ: ночная смена совы. Сова не спит ночью и сторожит закрытый Мак.
Направление: «Ночная сцена» (alexander-web-style), акцент золото `#E6CF85`, громкость средняя.

Модель: встроенная генерация Codex (GPT Image) через
`~/claude-config/skills/wow/scripts/codex-image.sh <out.png> transparent "<subject> <STYLE>" "<composition>"`.
Все картинки вырезки с прозрачным фоном; свечение за ними и отражение сделаны в CSS.
По 2 варианта на картинку (суффиксы `-a`, `-b`; для телефонного героя ещё `-c`, `-d`), оригиналы в `../../../raw/`.
Обрезка полей и WebP: `../../../work/process.py` (поля по альфе + 3%, WebP q82).

## Общий хвост промпта (слово в слово для всей серии)

```
Rendered as a premium studio product sculpture: polished liquid chrome with mirror reflections that pick up warm amber-gold light, combined with smooth frosted glass parts that glow softly from within. Soft rim light from behind outlines the silhouette, a gentle warm key light from the upper left, deep calm shadows inside the folds. Clean crisp edges, nothing else in the frame, generous empty space around the object. No text, no letters, no numbers, no logos.
```

## Картинки

| Файл | Смысл для продукта | Выбран | Композиция |
|---|---|---|---|
| `hero-560/800.webp` | сова сторожит закрытый ноутбук: Мак не спит с закрытой крышкой | `hero-a` | horizontal 3:2 frame, the owl and the laptop together fill about 60% of the frame width, centered, a little empty space above the owl |
| `hero-m-500/800.webp` | тот же образ, свой кадр для телефона | `hero-m-c` | vertical 4:5 frame, the owl fills about 70% of the frame height, the laptop and the owl are fully inside the frame with empty space on every side |
| `hourglass-*.webp` | шаг 1: выбрать срок сессии | `hourglass-a` | square frame, the object fills about 70% of the frame height, centered |
| `backpack-*.webp` | шаг 2: крышка закрыта, Мак в рюкзаке | `backpack-a` | square frame, the object fills about 75% of the frame height, centered |
| `moon-*.webp` | шаг 3: сон возвращается сам | `moon-a` | square frame, the object fills about 70% of the frame height, centered |
| `lantern-*.webp` | сторож проверяет сессию раз в минуту | `lantern-a` | square frame, the object fills about 75% of the frame height, centered |
| `battery-320.webp` | заряд ниже 15%: сессия заканчивается | `battery-b` | square frame, the object fills about 70% of the frame height, centered |
| `thermometer-320.webp` | перегрев: сессия заканчивается | `thermometer-a` | square frame, the object fills about 75% of the frame height, centered |
| `final-600/900.webp` | финал повторяет начало: сова на ночной смене | `final-a` | horizontal 3:2 frame, the owl fills about 75% of the frame width, centered |
| `og.jpg` | превью для ссылок 1200×630 | вёрстка | собрано из `hero-800.webp` и заголовка в Chrome |
| `sova-icon.svg` | иконка приложения «Рассвет» | из репозитория | `Resources/AppIcon.svg` |

## Предметы (начало промпта)

- **hero:** A single sculpture of a calm owl perched upright on top of a closed slim laptop. The owl faces the viewer with two large round eyes made of glowing warm amber glass, its wings folded, its feathers sculpted as layered chrome plates. The closed laptop lies flat under its talons, and a thin line of warm amber light leaks from the seam of the lid. Camera slightly below eye level, three-quarter front view.
- **hero-m (c, d):** A single sculpture of a calm owl, large in the frame, perched upright on a closed slim laptop and facing the viewer with two large round eyes made of glowing warm amber glass, wings folded, feathers sculpted as layered chrome plates. The whole closed laptop is visible under its talons, seen from the front, both of its corners inside the frame, and a thin line of warm amber light leaks from the seam of the lid.
  (Варианты a, b с промптом «close portrait … whose front corner shows at the bottom» отброшены: ноутбук обрезан краем кадра.)
- **hourglass:** A single sculpture of an hourglass with a slim chrome frame and two frosted glass bulbs, fine glowing amber sand running from the upper bulb into the lower one.
- **backpack:** A single sculpture of a closed slim laptop sliding halfway into an open soft backpack. The backpack is sculpted from frosted glass with chrome zippers and chrome straps; the laptop is polished chrome, and a thin line of warm amber light leaks from the seam of its lid.
- **moon:** A single sculpture of a crescent moon floating upright, its outer surface polished chrome and its inner curve frosted glass glowing a faint warm amber.
- **lantern:** A single sculpture of an old night watchman's lantern with a chrome frame, a curved carry handle on top and four frosted glass panes, a small warm amber flame glowing inside.
- **battery:** A single sculpture of an upright cylindrical battery cell with a polished chrome casing and a frosted glass window on its front; the window shows a low warm amber charge level near the bottom.
- **thermometer:** A single sculpture of a classic thermometer standing upright on a small round chrome base, its long frosted glass tube holding a column of glowing warm amber liquid that reaches the middle, plain tick marks without numbers.
- **final:** A single sculpture of an owl in flight gliding toward the viewer with its wings spread wide, two large round eyes made of glowing warm amber glass, feathers sculpted as layered chrome plates, seen from slightly below.
