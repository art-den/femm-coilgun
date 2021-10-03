-- Скрипт для программы FEMM 4.2
--------------------------------------------------------------------------------

setcompatibilitymode(1) -- Совместимость с версией 4.2

----[ Всякие константы ]-----------------------------------------------------------------------------------------------
vers          = 127          -- Версия скрипта
k_rc          = 140          -- Постоянная константа RC для распространённых электрколитических нденсаторов, Ом*мкФ
coil_meshsize = 0.5          -- Размер сетки катушки, мм
proj_meshsize = 0.35         -- Размер сетки пули, мм
max_segm      = 5            -- Максимальный размер сегмента пространства, град
sigma         = 0.0000000175 -- Удельное сопротивление меди, Ом * Метр
ro            = 7800         -- Плотность железа, Кг/Метр^3
pi            = 3.1415926535  
name_mat      = "Iron"
air_mat       = "Air"
coil_name     = "katushka"
cu_mat        = "Cu"

----[ Чтение начальных данных из текстового файла ]--------------------------------------------------------------------
function read_config_file(file_name)
	conf = {}
	opt = {}
	
	dofile(file_name)
	
	local config = conf
	conf = nil
	config.opt_params = opt or {}
	opt = nil
	
	local t_iz = sqrt(config.d_pr) * 0.07
	config.d_pr_iz = config.d_pr+t_iz -- Диаметр провода в изоляции
	if (config.r_cc == nil) or (config.r_cc == 0) then
		config.r_cc = (k_rc / config.c) -- Внутреннее сопротивление конденсатора
	end
	
	-- защита от неумех 
	if config.d_stv < config.d_puli then config.d_stv = config.d_puli + 0.1 end 
	if config.l_otv > (config.l_puli-0.5) then config.l_otv = config.l_puli - 0.5 end
	if config.l_otv < 0 then config.l_otv = 0 end
	if config.d_otv > (config.d_puli-0.5) then config.d_otv = config.d_puli - 0.5 end
	if config.d_otv < 0 then config.d_otv = 0 end
	
	return config
end

----[ Добавляет таблицу свойств материала "мягкая сталь" ]-------------------------------------------------------------
function add_iron_material()
	local iron_props = {
		{0,      0       },
		{0.0001, 50      },
		{0.001,  100     },
		{0.01,   150     },
		{0.015,  175     },
		{0.0253, 200     },
		{0.15,   300     },
		{0.5031, 400     },
		{1.0059, 500     },
		{1.3706, 700     },
		{1.4588, 900     },
		{1.51,   1200    },
		{1.55,   1600    },
		{1.58,   2000    },
		{1.62,   2700    },
		{1.77,   10000   },
		{1.84,   20000   },
		{1.93,   42000   },
		{2.01,   75000   },
		{2.10,   123300  },
		{2.25,   207000  },
		{2.439,  350000  },
		{3.13,   900000  },
		{7.65,   4500000 },
		{13.3,   9000000 },
		{22.09,  16000000}
	}

	mi_addmaterial(name_mat,"","","","","",0)        
	for i, prop in iron_props do
		mi_addbhpoint(name_mat, prop[1], prop[2]) 
	end
end

----[ Создаёт проект в FEMM для расчётов ]-----------------------------------------------------------------------------

function add_all_points(points)
	for i, pt in points do mi_addnode(pt[1], pt[2]) end
end

function select_all_points(points)
	for i, pt in points do mi_selectnode(pt[1], pt[2]) end
end

function add_all_segments(points)
	local last_i = getn(points)
	local pt2
	for i, pt1 in points do
		if i == last_i then pt2 = points[1]
		else pt2 = points[i+1] end
		mi_addsegment(pt1[1], pt1[2], pt2[1], pt2[2])
	end
end

function create_project(config)
	local Vol = 1.5 -- Кратность свободного пространства вокруг модели
	
	local d_otv = config.d_otv
	local d_kat = config.d_kat
	local l_kat = config.l_kat
	local l_mag = config.l_mag
	local l_mag_y = config.l_mag_y
	local d_stv = config.d_stv
	local l_puli = config.l_puli
	local l_sdv = config.l_sdv
	local d_puli = config.d_puli
	local l_otv = config.l_otv
	local d_pr = config.d_pr
	
	create(0) -- создаем документ для магнитных задач
	mi_probdef(0,"millimeters","axi",1E-8,30) -- создаем задачу
	mi_saveas("temp.fem") -- сохраняем файл под другим именем
	mi_addmaterial(air_mat,1,1) -- добавляем материал воздух
	mi_addmaterial(cu_mat,1,1,"","","",58,"","","",3,"","",1,d_pr) -- добавляем материал медный провод диаметром d_pr проводимостью 58
	mi_addcircprop(coil_name,0,0,1) -- добавляем катушку 
	add_iron_material()

-- Располагаем объекты

	--Создаем пространство в Vol раз большее чем катушка
	local vol_base = max(l_puli + l_kat/2 + l_mag_y - l_sdv, l_mag + d_kat/2)
	mi_addnode(0, vol_base * -Vol) -- ставим точку
	mi_addnode(0, vol_base * Vol) -- ставим точку
	mi_addsegment(0, vol_base * -Vol, 0, vol_base * Vol) -- рисуем линию
	mi_addarc(0, vol_base * -5, 0, vol_base * Vol, 180, max_segm) -- рисуем дугу
	mi_addblocklabel(vol_base * 0.7 * Vol, 0) -- добавляем блок
	mi_clearselected() -- отменяем все 
	mi_selectlabel(vol_base * 0.7 * Vol, 0) -- выделяем метку блока
	mi_setblockprop(air_mat, 1, "", "", "",0) -- устанавливаем свойства блока с имнем Air и номером блока 0
	mi_zoomnatural() -- устанавливаем зум так что бы было видно на весь экран

-- Создаем пулю

-- если длина пули равна диаметру значит шар
	if l_puli==d_puli then 
		mi_addnode(0,l_kat/2-l_sdv)
		mi_addnode(0,l_kat/2+l_puli-l_sdv)
		mi_clearselected()
		mi_selectnode (0,l_kat/2-l_sdv)
		mi_selectnode (0,l_kat/2+l_puli-l_sdv)
		mi_setnodeprop("",1)
		mi_addarc(0,l_kat/2-l_sdv,0,l_kat/2+l_puli-l_sdv,180,5)

	-- иначе просто цилиндр
	else
		local y1 = l_kat / 2 + l_puli - l_sdv
		local y2 = l_kat / 2 - l_sdv
		local x = d_puli / 2
		local projectile_points;

		if d_otv > 0 then 
--              (6) *-----* (1)
--                  |     |
--          (4) *---*(5)  |
--              |         |
--              |         |
--              |         |
--              |         |
--          (3) *---------* (2)
			projectile_points = {
				{ x,       y1       }, -- 1
				{ x,       y2       }, -- 2
				{ 0,       y2       }, -- 3
				{ 0,       y1-l_otv }, -- 4
				{ d_otv/2, y1-l_otv }, -- 5
				{ d_otv/2, y1       }  -- 6
			}		
		else
--          (1) *---------* (2)
--              |         |
--              |         |
--              |         |
--              |         |
--              |         |
--              |         |
--          (4) *---------* (3)
			projectile_points = {
				{ 0, y1 }, -- 1
				{ x, y1 }, -- 2
				{ x, y2 }, -- 3
				{ 0, y2 }  -- 4
			}
		end
		
		add_all_points(projectile_points)
		mi_clearselected()
		select_all_points(projectile_points)
		mi_setnodeprop("",1)
		add_all_segments(projectile_points)
	end

	mi_addblocklabel(d_puli/4,l_kat/2+l_puli/2-l_otv/2-l_sdv)
	mi_clearselected()
	mi_selectlabel(d_puli/4,l_kat/2+l_puli/2-l_otv/2-l_sdv)
	mi_setblockprop(name_mat, 1, proj_meshsize, "", "",1) -- номер блока 1


-- Создаем катушку
	if (config.k_ark <= 0) then config.k_ark = 0.5 end

--  (1)    (2)
--   *------*
--   |      |
--   |      |
--   |      |
--   *------*
--  (4)    (3)

	local intern_coil_points = {
		{  config.k_ark + d_stv/2,  config.k_ark - l_kat/2 }, -- 1
		{ -config.k_ark + d_kat/2,  config.k_ark - l_kat/2 }, -- 2
		{ -config.k_ark + d_kat/2, -config.k_ark + l_kat/2 }, -- 3
		{  config.k_ark + d_stv/2, -config.k_ark + l_kat/2 }  -- 4
	}

	add_all_points(intern_coil_points)
	add_all_segments(intern_coil_points)

	mi_addblocklabel(d_stv/2+(d_kat/2-d_stv/2)/2,0)
	mi_clearselected()
	mi_selectlabel(d_stv/2+(d_kat/2-d_stv/2)/2,0)
	mi_setblockprop(cu_mat, 0, coil_meshsize, coil_name, "",2) -- номер блока 2

-- Создаем внешний магнитопровод
	if (l_mag > 0) then 
		if (l_mag_y <=0) then l_mag_y = l_mag end

--  (1)           (2)
--   *-------------*
--   |             |
--   *-------*     |
-- (8)    (7)|     |
--           |     |
-- (5)    (6)|     |
--   *-------*     |
--   |             |
--   *-------------*
--  (4)           (3)
		
		local mag_core_points = {
			{ d_stv / 2,          l_kat / 2 + l_mag_y }, -- 1
			{ d_kat / 2 + l_mag,  l_kat / 2 + l_mag_y }, -- 2
			{ d_kat / 2 + l_mag, -l_kat / 2 - l_mag_y }, -- 3
			{ d_stv / 2,         -l_kat / 2 - l_mag_y }, -- 4
			{ d_stv / 2,         -l_kat / 2           }, -- 5
			{ d_kat / 2,         -l_kat / 2           }, -- 6
			{ d_kat / 2,          l_kat / 2           }, -- 7
			{ d_stv / 2,          l_kat / 2           }  -- 8
		};
		
		add_all_points(mag_core_points)
		add_all_segments(mag_core_points)

		mi_addblocklabel(d_kat/2+l_mag/2,0)
		mi_clearselected()
		mi_selectlabel(d_kat/2+l_mag/2,0)
		mi_setblockprop(name_mat, 1, "", "", "",3) -- номер блока 3
	end
	mi_clearselected()
end

----[ Симуляция одного выстрела по параметрам, заданным в config ]-----------------------------------------------------
function simulate(config)
	local result = {}
	
	-- переводим в состему Си
	local c       = config.c       / 1000000
	local d_pr    = config.d_pr    / 1000
	local d_pr_iz = config.d_pr_iz / 1000
	local l_puli  = config.l_puli  / 1000
	local l_kat   = config.l_kat   / 1000
	local l_sdv   = config.l_sdv   / 1000
	local nagr    = config.nagr    / 1000

	-- Начинаем
	result.start_date = date()

	result.r_v = config.r_sw+config.r_cc -- Сопротивление ключа + внутреннее сопротивление конденсатора, Ом

	-- Анализируем и запускаем постпроцессор
	mi_analyze(1)                        -- анализируем (скрывая окно анализа "1")
	mi_loadsolution()                    -- запускаем саму программу пост процессора
	mo_groupselectblock(2)
	local Skat = mo_blockintegral(5)     -- Площадь сечения катушки, Метр^2 
	local Vkat = mo_blockintegral(10)    -- Объем катушки, Метр^3
	mo_clearblock()
	mo_groupselectblock(1)
	local Vpuli = mo_blockintegral(10)   -- Объем пули, Метр^3
	mo_clearblock()
	result.m_puli=ro*Vpuli + nagr -- Масса пули плюс оперение, кг

	if config.k_mot < 1 then
		result.n = config.k_mot * Skat / (d_pr_iz * d_pr_iz) -- Количество витков в катушке уточнённое
	else 
		result.n = config.k_mot -- или явно задано
	end

	local end_x = l_puli + l_kat - l_sdv -- Положение пули за пределом катушки

	result.dl_provoda = result.n * 2 * pi * ((config.d_kat + config.d_stv)/1000) / 4 -- Длина обмоточного провода уточнённая, м
	result.r_kat = sigma * result.dl_provoda / (pi * (d_pr / 2)^2)     -- Сопротивление всего обмоточного провода катушки, Ом
	result.r = result.r_v + result.r_kat                                      -- Полное сопротивление системы

	--Устанавливаем число витков, а силу тока 100 А для оценки индуктивности
	mi_clearselected()
	mi_selectlabel(config.d_stv / 2 + (config.d_kat / 2 - config.d_stv / 2) / 2, 0) 
	mi_setblockprop("Cu", 0, coil_meshsize, coil_name, "", 2, result.n) -- последнее значение - число витков
	mi_clearselected()
	mi_modifycircprop(coil_name, 1, 100)

	-- Анализируем и запускаем постпроцессор
	mi_analyze(1)                                                   -- анализируем (скрывая окно анализа "1")
	mo_reload()                                                     -- перезапускаем программу пост процессора
	current_re,_,_,_,flux_re,_ = mo_getcircuitproperties(coil_name) -- получаем данные с катушки
	result.l = flux_re / current_re                                 -- Оценочная индуктивность, Генри

	-- НАчало симуляции
	local dt = config.delta_t / 1000000 -- перевод приращения времени в секунды 
	local x = 0                         -- начальная позиция пули
	local I0 = 0.01                     -- достаточно малое значение тока  I0=0.01
	local Uc = config.u
	local I = I0                        -- начальное значение тока
	local Force = 0
	local Fii = 0
	local kc = 1                        -- счетчик циклов, для индекса записи в массив result.items

	result.v_max = config.vel0
	result.f_aver = 0
	result.t = 0                        -- общее время
	result.vel = config.vel0
	result.items = {}                   -- создаем массив (таблицу как её называют в Lua)

	local have_to_stop = 0
	repeat -- начинаем цикл
		result.t = result.t+dt

		--- Рассчитываем dFi/dI при I и силу
		mi_modifycircprop(coil_name, 1, I)                     -- Устанавливает ток 
		mi_analyze(1)                                          -- анализируем (скрывая окно анализа "1")
		mo_reload()                                            -- перезапускаем программу пост процессора
		mo_groupselectblock(1)
		Force = mo_blockintegral(19)                           -- Сила действующая на пулю, Ньютон
		Force = Force * -1                                     -- ставим "-" из за координат (направление силы в сторону уменьшения координаты)
		result.f_aver = result.f_aver + Force * dt
		_,_,_,_,flux_re,_ = mo_getcircuitproperties(coil_name) -- получаем данные с катушки
		local Fi0=flux_re                                      -- магнитный поток

		mi_modifycircprop(coil_name, 1, I * 1.001)             -- Устанавливает ток, увеличенный на 1.001
		mi_analyze(1)                                          -- анализируем (скрывая окно анализа "1")
		mo_reload()                                            -- перезапускаем программу пост процессора
		_,_,_,_,flux_re,_ = mo_getcircuitproperties(coil_name) -- получаем данные с катушки
		local Fi1 = flux_re                                    -- магнитный поток при I=I+0.001*I, dI=0.001*I 
		Fii = (Fi1 - Fi0) / (0.001 * I)                        -- Рассчитываем dFi/dI

		local apuli = Force / result.m_puli                    -- Ускорение пули, Метр/секунда^2 
		local dx = result.vel * dt                             -- Приращение координаты, метр (исправленое)
		x = x + dx                                             -- Новая позиция пули
		result.vel = result.vel + apuli * dt                   -- Скорость после приращения, метр/секунда
		if result.v_max < result.vel then result.v_max = result.vel end

		mi_selectgroup(1)                                      -- Выделяем пулю
		mi_movetranslate(0, -dx * 1000)                        -- Перемещаем её на dx
		mi_modifycircprop(coil_name, 1, I)                     -- Устанавливает ток 
		mi_analyze(1)                                          -- анализируем (скрывая окно анализа "1")
		mo_reload()                                            -- перезапускаем программу пост процессора
		mo_groupselectblock(1)
		_,_,_,_,flux_re,_ = mo_getcircuitproperties(coil_name) -- получаем данные с катушки
		local Fi0 = flux_re                                    -- магнитный поток

		mi_modifycircprop(coil_name, 1 , I * 1.001)            -- Устанавливает ток, увельченный на 1.001
		mi_analyze(1)                                          -- анализируем (скрывая окно анализа "1")
		mo_reload()                                            -- перезапускаем программу пост процессора
		current_re,_,_,_,flux_re,_ = mo_getcircuitproperties(coil_name) -- получаем данные с катушки
		Fi1 = flux_re                                          -- магнитный поток при I=I+0.001*I, dI=0.001*I 

		-- Рассчитываем dFi/dI
		Fif = (Fi1 - Fi0) / (0.001 * I)                              

		-- Рассчитываем dL
		local dL=Fif-Fii

		-- Расчитываем ток и напряжение на конденсаторе
		I = I + dt * (Uc - I * result.r - I * dL / dt) / Fii
		
		-- Ограничиваем ток, если выставлена соотвествующая настройка
		if config.i_max and (config.i_max > 0.1) and (I > config.i_max) then I = config.i_max end
		Uc = Uc - dt * I / c
		if Uc < 0 then Uc = 0 end --если стоит паралельный диод

	
		-- записываем данные в массив
		local res_item = {}
		res_item.i   = I
		res_item.f   = Force
		res_item.vel = result.vel
		res_item.x   = x*1000
		res_item.t   = result.t*1000000
		res_item.u   = Uc
		res_item.l   = 1000000 * flux_re / current_re
		result.items[kc] = res_item
		kc = kc + 1

		-- Проверка, не пора ли остановить симуляцию:
		-- ... закончился ток
		if I <= 0 then have_to_stop = 1 end
		-- ... пуля полетела в обратную сторону
		if result.vel < 0 then have_to_stop = 1 end 
		-- ... пуля вылетела за пределы катушки и сила очень маленькая
		if (x > end_x) and (Force < 0) then have_to_stop = 1 end 
		-- ... пуля вылетела назад
		if x < 0 then have_to_stop = 1 end 
		-- ... режим "транзистор" и пуля начала тормозиться
		if (config.mode > 0) and (result.vel < result.v_max) then have_to_stop = 1 end 
	
	until have_to_stop ~= 0

	result.f_aver    = result.f_aver / (dt * kc)
	result.e_puli    = (result.m_puli * result.vel^2) / 2 
	result.e_puli0   = (result.m_puli * config.vel0^2) / 2
	result.e_c0      = (c * config.u^2) / 2
	result.e_c       = (c * Uc^2) / 2
	result.de_puli   = result.e_puli - result.e_puli0
	result.de_c      = result.e_c0 - result.e_c
	result.eff       = result.de_puli * 100 / result.de_c
	result.stop_date = date()

	-- Удаляем промежуточные файлы
	remove ("temp.fem")
	remove ("temp.ans")
	
	mi_close()

	return result
end

----[ Запись полученных результатов в файл ]---------------------------------------------------------------------------
function save_result_to_file(file_name, config, result)
	local handle = openfile(file_name, "a")
	function save(text) write (%handle, text .. "\n") end

	save("------------------------------------------------------------")
	save(format("Начало расчёта %s", result.start_date))
	save(format("Конец расчёта  %s", result.stop_date))
	save(format("Версия скрипта %i", vers))
	save(format("Общее время, микросекунд  = %i", result.t*1000000))
	save(format("Интервал расчёта,  мкс    = %i", config.delta_t))
	save(format("Ёмкость конденсатора, мкФ = %.1f", config.c))
	save(format("ESR конденсатора, Ом      = %.2f", config.r_cc))
	save(format("Начальное напряжение, В   = %.1f", config.u))
	save(format("Общее сопротивление, Ом   = %.3f", result.r))
	save(format("Внешнее сопротивление, Ом = %.3f", result.r_v))

	save("\n----- ПРОВОД ---------------------------------------------")
	save(format("Сопротивление обмотки, Ом = %.3f", result.r_kat))
	save(format("Количество витков         = %i", result.n))
	save(format("Диаметр провода, мм       = %.2f", config.d_pr))
	save(format("Общая длина провода, м    = %.1f", result.dl_provoda))

	save("\n----- КАТУШКА --------------------------------------------")
	save(format("Длина катушки, мм                            = %.1f", config.l_kat))
	save(format("Внешний диаметр катушки, мм                  = %.1f", config.d_kat))
	save(format("Индуктивность катушки в старт. позиции, мкГн = %.1f", result.l*1000000))
	save(format("Толщина щёчек внешнего магнитопровода, мм    = %.1f", config.l_mag_y))
	save(format("Толщина корпуса внешнего магнитопровода, мм  = %.1f", config.l_mag))
	save(format("Внутренний диаметр катушки, мм               = %.1f", config.d_stv))

	save("\n----- ПУЛЯ --------------------------------------------")
	save(format("Масса пули без оперения, г       = %.2f", result.m_puli*1000-config.nagr))
	save(format("Длина пули, мм                   = %.1f", config.l_puli))
	save(format("Диаметр пули, мм                 = %.1f", config.d_puli))
	save(format("Глубина отверстия в пуле, мм     = %.1f", config.l_otv))
	save(format("Диаметр отверстия, мм            = %.2f", config.d_otv))
	save(format("Масса оперения, г                = %.2f", config.nagr))
	save(format("Масса пули вместе с оперением, г = %.2f", result.m_puli*1000))
	save(format("Стартовая позиция пули, мм       = %.1f", config.l_sdv))

	save("\n----- ЭНЕРГИЯ ------------------------------------------")
	save(format("Энергия пули начальная, Дж         = %.1f", result.e_puli0))
	save(format("Энергия пули  конечная, Дж         = %.1f", result.e_puli))
	save(format("Приращение энергии пули, Дж        = %.1f", result.de_puli))
	save(format("Энергия конденсатора начальная, Дж = %.1f", result.e_c0))
	save(format("Энергия конденсатора конечная, Дж  = %.1f", result.e_c))
	save(format("Расход энергии конденсатора, Дж    = %.1f", result.de_c))
	save(format("Средняя сила, Н                    = %.1f", result.f_aver))
	save(format("КПД, %%                             = %.2f", result.eff))

	save("\n------ СКОРОСТЬ ----------------------------------------")
	save(format("Начальная скорость пули, м/с    = %.1f", config.vel0))
	save(format("Конечная скорость пули, м/с     = %.1f", result.vel))
	save(format("Максимальная скорость пули, м/с = %.1f", result.v_max))

	save("\n------ Data of simulation -------------------------------")
	save("    Ток(А)    Напр(В)    Сила(Н) Скор.(м/с)   Поз.(мм) Врем.(мкс) Инд-ть(мкГн)")
	for i, item in result.items do
		save(
			format(
				"%10.1f %10.1f %10.2f %10.2f %10.3f %10.0f %12.0f", 
				item.i, item.u, item.f, item.vel, item.x, item.t, item.l
			)		
		)
	end

	save("\n------ Data for export to Excel sheet --------------------")
	save("Сила тока (А)\tНапряжение (В)\tСила (Н)\tСкорость (м/с)\tПозиция x (мм)\tВремя (мкс)");
	for i, item in result.items do
		save(item.i .. "\t" .. item.u .. "\t" .. item.f .. "\t" .. item.vel .. "\t" .. item.x .. "\t" .. item.t)
	end
	closefile(handle)
end

----[ Функция, которая пытается найти оптимальные значения для data, перебирая opt_params ]----------------------------
function optimize(data, opt_params, fun, log)
	function get_values_str()
		local str = ""
		for o_name, o_value in %opt_params do
			if str ~= "" then str = str .. " " end
			str = str .. format("%s=%.3f", o_name, %data[o_name])
		end
		return str
	end
	
	local cache = {}
	function get_cached_result()
		local key = get_values_str()
		if %cache[key] == nil then %cache[key] = %fun(%data) end
		return %cache[key]
	end

	function log_str(str)
		if %log == nil then return end
		%log(str)
	end
	
	function log_cur_values()
		local str = get_values_str()
		log_str("пробую " .. str .. "...")
	end
	
	local cur_result = get_cached_result()
	log_str("исх. результат = " .. cur_result .. " для " .. get_values_str())
	
	while 1 do
		local was_optimized = 0
		for o_name, o_value in opt_params do
			local prev_value = data[o_name]
			data[o_name] = data[o_name] + o_value
			log_cur_values()
			local next_result = get_cached_result()
			log_str("результат = " .. next_result)
			if next_result > cur_result then
				log_str("хорошо :)")
				was_optimized = 1
				cur_result = next_result
			else
				log_str("плохо :(")
				data[o_name] = prev_value
				opt_params[o_name] = -opt_params[o_name]
				data[o_name] = data[o_name] + opt_params[o_name]
				log_cur_values()
				next_result = get_cached_result()
				log_str("результат = " .. next_result)
				if next_result > cur_result then
					log_str("хорошо :)")
					was_optimized = 1
					cur_result = next_result
				else
					log_str("плохо :(")
					data[o_name] = prev_value
				end
			end
		end
		if was_optimized == 0 then break end
	end
	log_str("Готово! Оптимальные значения: " .. get_values_str())
end

-- [ Показывает и очищает консоль ]------------------------------------------------------------------------------------
function prepare_console()
	showconsole()
	clearconsole()
end

-- [ Функция, которая проверяет, есть ли на диске файл с именем name ]-------------------------------------------------
function file_exists(name)
	local f = openfile(name, "r")
	if f ~= nil then 
		closefile(f)
		return 1
	else 
		return 0
	end
end

----[ Собственно, вся работа скрипта ]---------------------------------------------------------------------------------

-- Читаем конфиг
local conf_file_name=prompt("Введите имя файла даных, без расширения .txt") 
local conf_full_name = conf_file_name .. ".txt"
if file_exists(conf_full_name) == 0 then
	prepare_console()
	print('Не найден файл настроек "' .. conf_full_name .. '"')
	return
end
local config = read_config_file(conf_full_name)

-- Если не надо ничего оптимизировать
if (config.opt == null) or (config.opt == 0) or (config.opt_params == {}) then 

	-- Создаём проект
	create_project(config)

	-- Симулируем выстрел
	local result = simulate(config)

	-- Сохраняем результаты в файл
	local res_file_name = conf_file_name .. " V = " .. result.vel .. ".txt"
	save_result_to_file(res_file_name, config, result)

	-- Выводим информацию в консоль
	prepare_console()
	print ("-----------------------------------")
	print ("Полученные данные записаны в файл: " .. res_file_name)
	
-- Оптимизируем по config.opt_params
else
	prepare_console()

	-- Ф-ция, выполняющая выстрел с параметрами, записанными в config и возвращающая полученную скорость пули или КПД
	function opt_shot(config)
		create_project(config)
		local result = simulate(config)
		if (config.opt_t == nil) then return result.vel end
		return result[config.opt_t]
	end

	-- Подбираем оптимальные значения
	optimize(config, config.opt_params, opt_shot, print)
	
	-- Считаем ещё раз с оптимальным результатом
	create_project(config)
	local result = simulate(config)

	-- Сохраняем результаты в файл
	local res_file_name = conf_file_name .. " Vopt = " .. result.vel .. ".txt"
	save_result_to_file(res_file_name, config, result)

	-- Выводим информацию в консоль
	print ("-----------------------------------")
	print ("Оптимизированные данные записаны в файл: " .. res_file_name)
end
