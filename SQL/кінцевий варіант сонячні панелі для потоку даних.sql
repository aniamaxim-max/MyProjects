let
    BaseDate = Date.FromText(#"Базова дата"),            // З якої дати починати збір
    StepDays = #"Кількість днів для кроку",                           // Крок циклу (безпечно менше 31 дня)
    Today = Date.From(DateTime.LocalNow()),  // Поточна дата для зупинки циклу

    // 2. Функція для ОДНОГО запиту до API
    FetchData = (startDate as date, endDate as date) =>
        let
            // Перетворення дат у текстовий формат YYYY-MM-DD
            startText = Date.ToText(startDate, [Format="yyyy-MM-dd"]),
            endText = Date.ToText(endDate, [Format="yyyy-MM-dd"]),
            
            // Маскування ключа для хмарного обходу
            SecretKey = Text.From(#"Ключ"),
            
            // ВИПРАВЛЕНО: Повертаємо Headers замість ApiKeyName
            Source = Json.Document(Web.Contents(
                "http://46.225.81.144:8091/", 
                [
                    RelativePath = "hourly",  
                    Query = [
                        #"from" = startText,  
                        #"to" = endText       
                    ],
                    Headers = [
                        #"X-API-Key" = SecretKey
                    ]
                ]
            )),
            
            // Захист від порожніх відповідей API
            Items = if Record.HasFields(Source, "items") then Source[items] else {},
            
            // Ваш оригінальний спосіб перетворення списку на таблицю
            Table = Table.FromList(Items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
            Expanded = Table.ExpandRecordColumn(Table, "Column1",
                {"hour_kyiv", "produced_kwh", "price_uah_per_kwh", "revenue_uah"}
            )
        in
            Expanded,

    // 3. Цикл генерації періодів та виклику API
    GenerateData = List.Generate(
        () => [CurrentStart = BaseDate, CurrentEnd = Date.AddDays(BaseDate, StepDays)],
        each [CurrentStart] <= Today,
        each [
            CurrentStart = Date.AddDays([CurrentStart], StepDays + 1),
            CurrentEnd = List.Min({Date.AddDays([CurrentEnd], StepDays + 1), Today})
        ],
        each FetchData([CurrentStart], [CurrentEnd])
    ),

    // 4. Об'єднання всіх отриманих таблиць в одну
    CombinedTable = Table.Combine(GenerateData),
    
    // 5. Приведення типів для коректної аналітики
    FinalTable = Table.TransformColumnTypes(CombinedTable, {
        {"hour_kyiv", type text},
        {"produced_kwh", type number},
        {"price_uah_per_kwh", type number},
        {"revenue_uah", type number}
    }),
    #"Відсортовані рядки" = Table.Sort(FinalTable,{{"hour_kyiv", Order.Ascending}}),
    #"Змінений тип" = Table.TransformColumnTypes(#"Відсортовані рядки",{{"hour_kyiv", type datetime}}),
    #"Додано дату" = Table.AddColumn(#"Змінений тип", "date_kyiv", each DateTime.Date([hour_kyiv]), type date),
    #"Замінене значення" = Table.ReplaceValue(#"Додано дату",null,0,Replacer.ReplaceValue,{"produced_kwh"}),
    #"Замінене значення1" = Table.ReplaceValue(#"Замінене значення",null,0,Replacer.ReplaceValue,{"price_uah_per_kwh"}),
    #"Замінене значення2" = Table.ReplaceValue(#"Замінене значення1",null,0,Replacer.ReplaceValue,{"revenue_uah"})
in
    #"Замінене значення2"