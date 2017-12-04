#Использовать cmdline
#Использовать logos
#Использовать restler
#Использовать tempfiles
#Использовать asserts
#Использовать json

Перем ВозможныеКоманды;
Перем Лог;
Перем Логин;
Перем Пароль;
Перем ВерсияАПИ_ТФС;
Перем HTTPСоединение;

Процедура ОсновнаяРабота()

	СистемнаяИнформация = Новый СистемнаяИнформация;

	Лог = Логирование.ПолучитьЛог("oscript.app.vanessa-tfs");
	Лог.УстановитьРаскладку(ЭтотОбъект);
	// Лог.УстановитьУровень(УровниЛога.Отладка);

	ВозможныеКоманды = Новый Структура("get", "get");
	
	Парсер = Новый ПарсерАргументовКоманднойСтроки();
	
	ОписаниеКоманды = Парсер.ОписаниеКоманды(ВозможныеКоманды.get);
	Парсер.ДобавитьКоманду(ОписаниеКоманды);
	Парсер.ДобавитьИменованныйПараметр("--user", "Логин пользователя");
	Парсер.ДобавитьИменованныйПараметр("--password", "пароль пользователя (для TFS c http) или personal access token (для VSTS или TFS с https) ");
	Парсер.ДобавитьИменованныйПараметр("--collectionURI", "URL-ссылка на коллекцию TFS. Например, http://localhost:8080/tfs/Collection или https://aartbear.visualstudio.com");
	Парсер.ДобавитьИменованныйПараметр("--project", "Имя проекта TFS. Например, Project1");
	Парсер.ДобавитьИменованныйПараметр("--buildId", "ID выполненой сборки. Например, 341");
	Парсер.ДобавитьИменованныйПараметр("--out", "Путь сохраняемого файла. Например, file1.zip, d:\file2.zip");

	Аргументы = Парсер.Разобрать(АргументыКоманднойСтроки);
	Если Аргументы.Количество() = 0 Тогда
		Парсер.ВывестиСправкуПоПараметрам();
	Иначе
		Логин = Аргументы["--user"];
		Пароль = Аргументы["--password"];

		Попытка
			СкачатьАртефакты(Аргументы["--collectionURI"], Аргументы["--project"], Аргументы["--buildId"],
				Аргументы["--out"]);
		Исключение
			ВременныеФайлы.Удалить();
			ВызватьИсключение;
		КонецПопытки;
	КонецЕсли;
	
	Лог.Информация("ВСЕ!");
КонецПроцедуры

Процедура СкачатьАртефакты(Знач СсылкаНаКоллекцию, Знач ИмяПроекта, Знач ИдСборки, Знач КудаСохранять)
	ВерсияАПИ_ТФС = "2.0";

	ЛогРестлер = Логирование.ПолучитьЛог("oscript.lib.restler");
	ЛогРестлер.УстановитьУровень(ЛогРестлер.Уровень());
	ЛогРестлер.УстановитьРаскладку(ЭтотОбъект);
	
	HTTPСоединение = Новый HTTPСоединение(СсылкаНаКоллекцию, , Логин, Пароль);

	ОписаниеАртефактов = СкачатьОписаниеАртефактов(ИмяПроекта, ИдСборки);
	Ожидаем.Что(ОписаниеАртефактов).ИмеетТип("Соответствие");
	
	Ожидаем.Что(ОписаниеАртефактов["count"]).Равно(2);
	Ожидаем.Что(ОписаниеАртефактов["value"]).ИмеетДлину(2);
	Строка0 = ОписаниеАртефактов["value"][0];
	Ожидаем.Что(Строка0["name"]).Равно("ConfigVersion_341");
	Ожидаем.Что(Строка0["resource"]["type"]).Равно("Container");
	Ожидаем.Что(Строка0["resource"]["downloadUrl"]).ЭтоНе().Равно("");
	
	Лог.Информация("Нашли URL скачивания артефакта 
		|	%1", Строка0["resource"]["downloadUrl"]);
	
	Для каждого ОписаниеАртефакта Из ОписаниеАртефактов["value"] Цикл
		СкачатьАртефакт(ОписаниеАртефакта, КудаСохранять);
	КонецЦикла;
КонецПроцедуры

Функция СкачатьОписаниеАртефактов(ИмяПроекта, ИдСборки)
	// Урл = СтрШаблон("%1/%2/_apis/build/builds/%3/artifacts?api-version=%4", 
	// СсылкаНаКоллекцию, ИмяПроекта, ИдСборки, ВерсияАПИ_ТФС);
	Урл = СтрШаблон("%1/%2/_apis/build/builds/%3/artifacts?api-version=%4", 
		"", ИмяПроекта, ИдСборки, ВерсияАПИ_ТФС);
	Лог.Отладка("УРЛ описания артефактов сборки %1", Урл);

	Клиент = ПолучитьВебКлиент(HTTPСоединение);
	
	ОписанияАртефактов = Клиент.Получить(Урл);
	
	ПарсерJSON  = Новый ПарсерJSON();
	JsonДокумент = ПарсерJSON.ЗаписатьJSON(ОписанияАртефактов);
	Лог.Отладка("JsonДокумент %1", JsonДокумент);

	Возврат ОписанияАртефактов;
КонецФункции

Процедура СкачатьАртефакт(Знач ОписаниеАртефакта, Знач КудаСохранять)
	ТипАртефакта = ОписаниеАртефакта["resource"]["type"];
	Если ТипАртефакта <> "Container" Тогда
		Лог.Информация("Пропускаем артефакт с типом %1", ТипАртефакта);
	Иначе
		ИмяАртефакта = ОписаниеАртефакта["name"];
		URL_файла = ОписаниеАртефакта["resource"]["downloadUrl"];

		Клиент = ПолучитьВебКлиент(HTTPСоединение);
		HTTPЗапрос = Клиент.ПолучитьHTTPЗапрос(URL_файла);

		ИмяВременногоФайла = ВременныеФайлы.НовоеИмяФайла();
		HTTPОтвет = HTTPСоединение.Получить(HTTPЗапрос, ИмяВременногоФайла);

		Для каждого КлючЗначение Из HTTPОтвет.Заголовки Цикл
			Лог.Отладка("Заголовок %1:%2", КлючЗначение.Ключ, КлючЗначение.Значение);
		КонецЦикла;

		ПутьФайла = HTTPОтвет.ПолучитьИмяФайлаТела();
		СообщениеОшибки = СтрШаблон("Должны были получить артефакт по имени артефакта, а его не удалось скачать. 
		|Имя %1", ОписаниеАртефакта["name"]);
		Ожидаем.Что(ПутьФайла, СообщениеОшибки).ЭтоНе().Равно(Неопределено);
		
		Ожидаем.Что(Новый Файл(ИмяВременногоФайла).Существует(), СообщениеОшибки).Равно(Истина);
		Ожидаем.Что(ПутьФайла, СообщениеОшибки).Равно(ИмяВременногоФайла);
		Ожидаем.Что(Новый Файл(ПутьФайла).Существует(), СообщениеОшибки).Равно(Истина);

		ПутьВыходногоФайла = "";
		ВыходнойФайл = Новый Файл(КудаСохранять);
		Если ВыходнойФайл.Существует() Тогда
			Если ВыходнойФайл.ЭтоКаталог() Тогда
				ПутьВыходногоФайла = ОбъединитьПути(ВыходнойФайл.ПолноеИмя, ИмяАртефакта);
			Иначе
				ПутьВыходногоФайла = ВыходнойФайл.ПолноеИмя;
			КонецЕсли;
		Иначе
			Если ВыходнойФайл.Имя = ВыходнойФайл.ИмяБезРасширения Тогда
				ПутьВыходногоФайла = ОбъединитьПути(ВыходнойФайл.ПолноеИмя, ИмяАртефакта);
			Иначе
				ПутьВыходногоФайла = ВыходнойФайл.ПолноеИмя;
			КонецЕсли;
		КонецЕсли;
		ВыходнойФайл = Новый Файл(ПутьВыходногоФайла);
		Если ВыходнойФайл.Имя = ВыходнойФайл.ИмяБезРасширения Тогда
			ПутьВыходногоФайла = ОбъединитьПути(ВыходнойФайл.Путь, ВыходнойФайл.Имя + ".zip");
		КонецЕсли;
		Лог.Информация("Перемещаем полученный артефакт в <%1>", ПутьВыходногоФайла);
		ПереместитьФайл(ПутьФайла, ПутьВыходногоФайла);

		СообщениеОшибки = СтрШаблон("Должны были получить результирующий файл, а его не удалось скачать. 
		|Путь файла %1", ПутьВыходногоФайла);
		Ожидаем.Что(Новый Файл(ПутьВыходногоФайла).Существует(), СообщениеОшибки).Равно(Истина);

	КонецЕсли;
КонецПроцедуры

Функция ПолучитьВебКлиент(Знач HTTPСоединение)
	Клиент = Новый КлиентВебAPI();
	Клиент.ИспользоватьСоединение(HTTPСоединение);
	СтрокаЛогинПароль = СтрШаблон("%1:%2", Логин, Пароль);
	Лог.Отладка("логин:пароль это %1", СтрокаЛогинПароль);
	
	ИмяВременногоФайла = ВременныеФайлы.НовоеИмяФайла();
    ЗаписьТекста = Новый ЗаписьТекста(ИмяВременногоФайла, КодировкаТекста.UTF8NoBOM);
    ЗаписьТекста.Записать(СтрокаЛогинПароль);
    ЗаписьТекста.Закрыть();

	ДвоичныеДанные = Новый ДвоичныеДанные(ИмяВременногоФайла);

	СтрокаЛогинПароль = Base64Строка(ДвоичныеДанные);
	Лог.Отладка("Base64Строка для логин:пароль это %1", СтрокаЛогинПароль);

	Заголовки = Новый Соответствие;
	Заголовки.Вставить("authorization", СтрШаблон("Basic %1==", СтрокаЛогинПароль));
	Клиент.УстановитьЗаголовки(Заголовки);

	Возврат Клиент;
КонецФункции

Функция Форматировать(Знач Уровень, Знач Сообщение) Экспорт

	Возврат СтрШаблон("%1: %2 - %3", ТекущаяДата(), УровниЛога.НаименованиеУровня(Уровень), Сообщение);

КонецФункции

ОсновнаяРабота();
