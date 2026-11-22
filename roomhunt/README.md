# Охота по комнатам (RoomHunt)

Android-игра в 3D от третьего лица: анимированный персонаж бегает по большому дому и ищет
7 спрятанных предметов (6 звёзд и ключ). Один предмет лежит в запертом кабинете — ключ от
него надо найти. Когда найдено всё, показывается экран победы с временем.

- Движок: **Godot 4.3**, GDScript, рендерер **Mobile** (Vulkan), ориентация landscape
- Пакет: `com.example.roomhunt`, minSdk 24, targetSdk 34, debug-подпись, результат — `.apk`

## Как играть

| Действие | Сенсор | Клавиатура / мышь (отладка на ПК) |
|---|---|---|
| Движение | виртуальный джойстик слева (появляется там, где коснулся) | WASD / ↑↓ |
| Камера | свайп по правой половине экрана | перетаскивание мышью справа, ←/→ или Q/R |
| Прыжок | кнопка «Прыжок» | Пробел |
| Взять / открыть | кнопка «Взять» (появляется рядом с предметом или запертой дверью) | E |

HUD: «Найдено: N из 7», подсказка «Ищи: <комната>» про следующий предмет, название текущей
комнаты и таймер. Двери открываются сами, когда подходишь. В шкафах дверцы тоже распахиваются.

Порядок поиска (по подсказкам): гостиная → кухня → спальня → детская (ключ) → подвал → чердак → кабинет.

## Структура проекта

```
roomhunt/
├── project.godot            настройки (Mobile, landscape, физика 60 Гц)
├── export_presets.cfg       пресет «Android» (Gradle, minSdk 24, targetSdk 34, APK, arm64+armv7)
├── debug.keystore           debug-ключ (пароль android, alias androiddebugkey)
├── main.tscn                точка входа (скрипт scripts/main.gd)
├── scenes/player.tscn       CharacterBody3D игрока
├── scripts/
│   ├── game_data.gd         ★ ДАННЫЕ: комнаты, стены/двери, предметы и подсказки
│   ├── house_builder.gd     строит дом из данных (склейка мешей, коллизии, лампы, лестницы)
│   ├── furniture.gd         ★ мебель по комнатам (из примитивов)
│   ├── door.gd              дверь на петле с анимацией, замок
│   ├── pickup.gd            предмет (звезда/ключ), вращение и свечение
│   ├── player.gd            движение, прыжок, AnimationTree (idle↔walk, «бег», прыжок), шаги
│   ├── camera_rig.gd        камера от 3-го лица + SpringArm3D
│   ├── touch_controls.gd    джойстик, свайп камеры, кнопки (мультитач)
│   ├── hud.gd               HUD, сообщения, экран победы
│   └── main.gd              игровой цикл, окружение/свет, подсказки, победа
├── assets/                  модель персонажа, звуки, музыка (+ лицензии)
└── tools/                   автотесты и вспомогательные скрипты (в APK не попадают)
```

## Как собрать APK

### В GitHub Actions (рекомендуется)

Workflow `.github/workflows/build-apk.yml` запускается при push в `roomhunt/**` (или вручную:
Actions → *Build Android APK (RoomHunt)* → *Run workflow*). Он:

1. ставит JDK 17, Android SDK (platform-tools, build-tools 34.0.0, platforms;android-34, NDK 23.2.8568313, CMake) и Godot 4.3 с export templates;
2. импортирует проект, **проходит игру ботом до победы** и гоняет стресс-тест физики;
3. экспортирует `build/roomhunt.apk`, проверяет пакет/minSdk/targetSdk/подпись и размер (≤ 150 МБ);
4. выкладывает `roomhunt-apk` как artifact.

Скачать на телефоне: открой страницу запуска workflow в приложении GitHub или в браузере →
**Artifacts → roomhunt-apk** → распакуй zip → `roomhunt.apk`.

### Локально

Нужно: JDK 17, Android SDK (`platform-tools`, `build-tools;34.0.0`, `platforms;android-34`,
`cmake;3.10.2.4988404`, `ndk;23.2.8568313`), Godot 4.3 и export templates 4.3.

```bash
# 1. пути SDK/JDK и debug-ключ — в настройках редактора Godot (~/.config/godot/editor_settings-4.3.tres):
#    export/android/android_sdk_path, export/android/java_sdk_path,
#    export/android/debug_keystore = <путь>/roomhunt/debug.keystore
#    (user: androiddebugkey, пароль: android)

cd roomhunt
# 2. Gradle-шаблон Android (один раз; то же делает пункт Project → Install Android Build Template)
mkdir -p android/build
unzip -q -o ~/.local/share/godot/export_templates/4.3.stable/android_source.zip -d android/build
echo -n "4.3.stable" > android/.build_version && touch android/build/.gdignore

# 3. импорт и экспорт
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-debug "Android" build/roomhunt.apk
```

## Как установить APK на телефон

1. Скопируй `roomhunt.apk` на телефон (или скачай artifact прямо на него).
2. Открой файл; Android попросит разрешить установку из этого источника («Установка неизвестных приложений») — разреши.
3. Или с компьютера: `adb install -r build/roomhunt.apk`.

Требования: Android 8.0+ и поддержка **Vulkan 1.0** (рендерер Mobile в Godot 4 работает только на Vulkan;
практически все телефоны с Android 8+ и GPU Adreno 5xx / Mali-G7x и новее его поддерживают).

## Как поменять предметы и комнаты

Всё в `scripts/game_data.gd`; после правок перезапусти игру (пересобирать вручную ничего не нужно).

- **Предметы** — массив `ITEMS`: `kind` (`"star"` или `"key"`), `room`, `pos` (мировые координаты `Vector3`),
  `hint` (подсказка в HUD), необязательный `scale`. Порядок в массиве — порядок подсказок. Сумма предметов =
  `ITEMS.size()` — счётчик и победа подстроятся сами. Предмет, лежащий за запертой дверью, помечай
  `"needs_door": "<id двери>"`; сама дверь задаётся `"locked": true` в `WALLS`.
- **Комнаты** — словарь `ROOMS`: `rect` (`Rect2(x, z, ширина, глубина)`), высота пола `y`, цвет, имя, торшеры `lamps`.
  Комнату-лестницу описывает поле `ramp`.
- **Стены и двери** — массив `WALLS`: стена задаётся концами `a`/`b` (строго вдоль X или Z), в `doors` —
  проёмы (`at` — координата центра вдоль стены, `locked`, `open` — просто арка без створки).
- **Мебель и декор** — `scripts/furniture.gd`, по функции на комнату (`_living`, `_kitchen`, …). Шкаф с
  дверцами: `b.cabinet(...)`. Если ставишь предмет внутрь мебели — задай его `pos` вручную в `ITEMS`.
- **Звуки / музыка** — `assets/sounds/`; музыку можно перегенерировать: `python3 tools/make_music.py` (нужны numpy и ffmpeg).

Координаты: X — на восток, Z — на юг, Y — вверх. Предмет берётся с расстояния ≤ 1.8 м при прямой видимости
(стены и полы пропускать не будут).

## Тесты и отладка (папка `tools/`)

```bash
cd roomhunt && godot --headless --path . --import          # один раз
godot --headless --fixed-fps 60 --path . -- --selftest     # бот проходит игру до победы
godot --headless --fixed-fps 60 --path . -- --fuzz         # случайное блуждание: провалы, выход за стены
# скриншоты из разных точек дома (нужен Xvfb; Compatibility-рендерер, т.к. Mobile требует Vulkan):
xvfb-run -a godot --rendering-driver opengl3 --rendering-method gl_compatibility --path . -- --shots=/tmp/shots
```

В headless-режиме Godot печатает сообщения `mesh_get_surface_count … "m" is null` — это особенность
dummy-рендерера, на игру не влияет.

## Технические заметки

- **Производительность**: статическая геометрия дома склеена в меши по ячейкам 4.5 м × материал (≈190 мешей),
  коллизии сгруппированы по ячейкам; 15 торшеров (OmniLight3D, диапазон 6.5 м ⇒ ≤ 8 ламп на меш — лимит Mobile),
  тени только у двух ближайших к игроку ламп и у «лунного» DirectionalLight3D; WorldEnvironment: Filmic + лёгкий
  glow, без SSAO/SDFGI. MSAA 2×.
- **Камера**: SpringArm3D (маска — только слой «мир»: стены, полы, двери), модель персонажа скрывается, если камера
  прижата вплотную.
- **Лестницы** — наклонные коллайдеры (21.8°) с «ступенями» только для вида: персонаж не цепляется.

## Ассеты и лицензии

| Что | Источник | Лицензия |
|---|---|---|
| Персонаж `character.glb` (анимации idle / walk / jump), `colormap.png` | Kenney, [Starter Kit 3D Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) | CC0 |
| Звуки `walking`, `jump`, `land`, `coin`, `break` (.ogg) | там же | CC0 |
| Музыка `music.ogg` | сгенерирована `tools/make_music.py` | CC0 (авторская) |
| Мебель, свет, интерфейс | собраны кодом из примитивов | — |

Лицензия стартового набора Kenney лежит в `assets/KENNEY_STARTER_KIT_LICENSE.md` (код набора — MIT, модели и звуки — CC0).

### Что не получилось

- У бесплатной модели персонажа есть анимации **idle, walk, jump**, но нет отдельной **run**: «бег» — это walk,
  ускоряемая через `AnimationNodeTimeScale` по скорости, со смешиванием idle↔walk в `AnimationNodeBlendSpace1D`.
- Мебель из пакетов Kenney/Quaternius/Poly Pizza скачать не удалось (хосты `kenney.nl`, `quaternius.com`,
  `poly.pizza`, `opengameart.org` недоступны из среды разработки), поэтому мебель — процедурная из примитивов.
