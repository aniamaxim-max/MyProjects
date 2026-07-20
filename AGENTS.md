# Инструкции для ИИ-агента

## Персонализация
* Пользователя зовут **Анна**. Всегда обращайся к ней по имени.

## Правила работы с репозиторием
* **Категорически запрещено** автоматически коммитить изменения в репозиторий.
* Любые коммиты, создание веток или отправка изменений (push) выполняются **только после явного подтверждения или прямой команды от Анны**.
* Если Анна пишет **"сохрани изменения в репозиторий"** — ты коммитишь все изменения и пушишь в origin, самостоятельно придумывая сообщение коммита.

## Agent skills

### Issue tracker

Локальные markdown-файлы в `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Стандартные метки: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: CONTEXT.md + docs/adr/ в корне репозитория. See `docs/agents/domain.md`.

## Правила роботи з створенням вьюх

### View з датами
Якщо потрібно зробити view, де є поле з датою з 1C (datetime зі зсувом +2000 років), завжди використовуй конструкцію:
```sql
IIF(column_name >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, column_name), column_name)
```
Якщо дата має повертатися як NULL для порожніх значень, то:
```sql
IIF(column_name >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, column_name), NULL)
```

### Дві в'юхи в одному файлі (v_ та vb_)
Якщо в одному файлі створюються дві в'юхи (наприклад, `pbi.v_DimXxx` та `pbi.vb_DimXxx`), то **кожна в'юха** повинна мати свою пару `IF EXISTS(DROP VIEW) / CREATE VIEW`. Не можна ставити DROP тільки для першої в'юхи.