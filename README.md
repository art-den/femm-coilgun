# Скрипт для симуляции выстрела пушки гаусса в FEMM

* Здесь представлен переработанный и "причёсанный" скрипт, взятый с сайта http://foar.ru
* Что такое пушка гаусса [расписано в вики](https://ru.wikipedia.org/wiki/%D0%9F%D1%83%D1%88%D0%BA%D0%B0_%D0%93%D0%B0%D1%83%D1%81%D1%81%D0%B0)
* Скрипт нужен для того, чтобы перед постройкой пушки гаусса оценить параметры катушки, 
  пули и конденсатора, а также подобрать оптимальные параметры.
* Скрипт умеет оптимизировать начальные параметры и находить такие при которых скорость выстрела выше

# Необходимое ПО

Всё что нужно для работы скрипта можно скачать по следующим ссылкам: 

* [Программа FEMM](https://www.femm.info/wiki/HomePage) - программа скачивается в разделе Download. Требуемая версия - 4.2. 
* [Скрипт для FEMM](https://github.com/art-den/femm-coilgun/raw/master/coilgun.lua) ("Сохранить как..." на ссылке) * Файл настроек ("Сохранить как..." на ссылке)

# Подготовка

* Устанавливаем программу FEMM
* Записываем скрипт (coilgun.lua) и файл настроек (primer.txt) в один каталог

# Симуляция выстрела

Для начала надо отредактировать файл настроек под ваши параметры гаусса. Для этого открываем его в любом 
текстовом редакторе (например, блокноте). Файл выглядит следующим образом (формат файла не совпадает с оригинальным форматом):
