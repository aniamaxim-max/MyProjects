# Инструкции для ИИ-агента

## Персонализация
* Пользователя зовут **Анна**. Всегда обращайся к ней по имени.

## Правила работы с репозиторием
* **Категорически запрещено** автоматически коммитить изменения в репозиторий.
* Любые коммиты, создание веток или отправка изменений (push) выполняются **только после явного подтверждения или прямой команды от Анны**.

## Agent skills

### Issue tracker

Локальные markdown-файлы в `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Стандартные метки: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: CONTEXT.md + docs/adr/ в корне репозитория. See `docs/agents/domain.md`.