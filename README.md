<div align="center">
  <img src="asset/ZET.png" alt="Zet Logo" width="700"/>
  
  <!-- Language Selection -->
  <p>
    <strong>🇷🇺  Русский</strong> | 
    <a href="translate/README_EN.md">🇺🇸 English</a> | 
    <a href="translate/README_CN.md">🇨🇳 中文</a> | 
    <a href="translate/README_DE.md">🇩🇪 Deutsch</a>
  </p>
  
  <h1>ZetGui: Ваш ИИ-агент</h1>
  <p><strong>Забудьте про запоминание команд. Начните разговор с вашим терминалом.</strong></p>
  <p> 
    <a href="#"><img src="https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white" alt="TypeScript"></a>
    <a href="#"><img src="https://img.shields.io/badge/React-61DAFB?style=for-the-badge&logo=react&logoColor=black" alt="React"></a> 
    <a href="#"><img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js"></a>
    <a href="#"><img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"></a>
    <a href="#"><img src="https://img.shields.io/badge/Neutralino-000000?style=for-the-badge" alt="Neutralino"></a>
  </p>
</div>

## 🤔 Зачем ZetGui?

В мире сложных CLI и бесконечных флагов, ZetGui предлагает революционную альтернативу: прямой разговор с ИИ-агентом, работающим в безопасной изолированной среде. Это не просто выполнение одной команды — это решение задач через диалог.

| Возможность | Описание |
|-------------|----------|
| 💬 **Естественный язык** | Просто скажите ZetGui, что хотите сделать. "Скачай Python, распакуй и добавь в PATH." Готово. |
| 🛡️ **Безопасность по умолчанию** | Каждая команда выполняется в изолированном контейнере `ubuntu:24.04`. Ваша система всегда в безопасности. |
| 🧠 **Прозрачный ИИ** | ZetGui показывает свой процесс мышления, объясняя *почему* он выбрал определенную команду перед выполнением. |
| 🔧 **Полноценная IDE** | Встроенный редактор кода, файловый менеджер и терминал в одном приложении. |
| 📱 **Desktop + Web** | Работает как настольное приложение (Neutralino) и в браузере. |

## 🚀 Как это работает

ZetGui работает в простом, но мощном цикле:

1. **Вы:** Даете задачу на обычном языке
2. **ZetGui (ИИ):** Анализирует запрос, составляет план и переводит его в точную команду shell
3. **ZetGui (Исполнитель):** Выполняет команду внутри безопасного Docker-контейнера
4. **Вы:** Видите результат и продолжаете диалог

## ⚡️ Быстрый старт

> **Требования:** [Node.js](https://nodejs.org/) (v18+), [Docker](https://www.docker.com/), и [Kiala API](https://github.com/derxanax/Kiala-api-qwen) запущенный локально.

### 🎯 Быстрый запуск (одна команда!)

```bash
# Клонируем проект
git clone https://github.com/derxanax/ZeroEnhanced.git
cd ZeroEnhanced

# Запускаем главный скрипт управления
./Zet-Install.sh    # Linux/Mac
# или
# .\Zet-Install.ps1  # Windows PowerShell
```

**Главный скрипт предоставляет интерактивное меню:**
- 📦 Установить все зависимости
- 🔨 Собрать все компоненты  
- 🖥️ Запустить CLI версию
- 🖥️ Запустить Desktop GUI
- 🌐 Запустить Web версию

### 🛠️ Ручная установка (опционально)

Если предпочитаете ручную установку:

```bash
# Установка зависимостей
./script/install-all-Dependencies.sh

# Сборка компонентов
./script/build-all.sh

# Запуск конкретной версии
./script/start-all-cli.sh     # CLI
./script/start-all-gui.sh     # Desktop GUI  
./script/start-all-web.sh     # Web версия
```

> **Примечание:** Папка `/sandbox` автоматически создается и монтируется в Docker контейнер для обмена файлами.

## 🏗️ Архитектура

```
ZeroEnhanced/
├── asset/             # Ресурсы (логотипы, изображения)
├── backend/           # Express.js API сервер
├── desktop/           # Neutralino desktop приложение
│   └── react-src/     # React UI компоненты
├── docker-sandbox/    # Docker окружение для выполнения команд
├── script/            # Скрипты установки и настройки
├── src/              # Основная логика (CLI версия)
└── translate/         # Переводы README на разные языки
```

## 🧠 Интеллектуальное редактирование кода

ZetGui использует революционную систему **атомарных операций** для редактирования кода:

### 🔧 Точечные изменения вместо переписывания
Вместо перезаписи всего файла, ИИ выполняет хирургически точные операции:

```python
# Исходный код:
# 1: import random
# 2: print("привет")

# Пользователь: "Добавь import jsonify между импортами"
# ИИ выполняет атомарную операцию:
# - Сдвигает строку 2 → 3 (print("привет") перемещается вниз)  
# - Записывает import jsonify в освободившуюся строку 2

# Результат:
# 1: import random
# 2: import jsonify  ← новая строка
# 3: print("привет") ← сдвинутая строка
```

### ⚛️ Принцип атомарности
- **Одна операция за запрос**: ИИ может либо сдвинуть строку, либо добавить код, но не одновременно
- **Контролируемые изменения**: Каждое изменение видимо и отслеживается
- **Никаких потерь**: Код никогда не теряется при редактировании

## 🛣️ Что дальше?

ZetGui - развивающаяся платформа. Планы на будущее:

- [x] **Desktop приложение** с Neutralino
- [x] **Многоязычный интерфейс** 
- [x] **Атомарное редактирование:** Точечные изменения кода без переписывания
- [ ] **Автономное программирование:** ИИ работает в цикле до команды `endcycle`, создавая полные программы за один запрос
- [ ] **Многошаговое выполнение:** Автономное выполнение сложных многокомандных процессов
- [x] **Веб и файловые операции:** Встроенные инструменты для работы с API и файловой системой
- [ ] **Постоянное состояние:** Память sandbox между сессиями
- [ ] **Плагины:** Расширяемая система плагинов
- [ ] **Облачная синхронизация:** Синхронизация настроек и проектов

## 📝 Примеры использования

### Разработка
```
Пользователь: "Создай новый React проект с TypeScript"
ZetGui: Создаю React проект с TypeScript поддержкой...
$ npx create-react-app my-app --template typescript
```

### Интеллектуальное редактирование кода
```
Пользователь: "Добавь import json между существующими импортами"
ZetGui: Вставляю import json на строку 2, сдвигая остальные вниз...
✓ Inserted line 2: import json
✓ Existing code shifted down automatically

Пользователь: "Замени print на logging в строке 5"  
ZetGui: Заменяю строку 5 на logging вызов...
✓ Replaced line 5: logging.info("message")
```

### DevOps
```
Пользователь: "Проверь статус всех Docker контейнеров и перезапусти остановленные"
ZetGui: Проверяю Docker контейнеры и перезапускаю остановленные...
$ docker ps -a && docker start $(docker ps -aq --filter "status=exited")
```

### Системное администрирование
```
Пользователь: "Найди все файлы больше 100MB и покажи топ-10"
ZetGui: Ищу большие файлы в системе...
$ find / -type f -size +100M -exec du -h {} + 2>/dev/null | sort -rh | head -10
```

## 👥 Авторы

👤 **Саша (zarazaex)**  
Telegram: [@zarazaex](https://t.me/zarazaex)

👤 **Derx / lyzt**  
Telegram: [@amyluutz](https://t.me/amyluutz)  
Mail: derx@derx.space

👤 **Алексей**

---

<div align="center">
  <p>Made with ❤️ by derx and zarazaex</p>
  
  <p>
    <a href="https://github.com/derxanax/ZeroEnhanced">⭐ Star on GitHub</a> |
    <a href="https://github.com/derxanax/ZeroEnhanced/issues">🐛 Report Bug</a> |
    <a href="https://github.com/derxanax/ZeroEnhanced/discussions">💬 Discussions</a>
  </p>
</div>
