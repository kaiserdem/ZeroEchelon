# Zero Echelon — дослідження чинних протоколів екстреної медицини та медицини катастроф

**Дата дослідження:** 13.09.2026
**Обʼєкт:** офлайн-first застосунок для нетренованого цивільного свідка масових втрат (перші 3 хвилини після ракетного удару / інциденту в пасажирському вагоні), голосове + візуальне ведення, українська та англійська мови.
**Метод:** усі версії/дати перевірені за первинними джерелами; кожне твердження про версію має інлайн-URL. Дати доступу — 13.09.2026, якщо не вказано інше.

> **Важливе застереження про предметну область.** Нижче систематично розмежовано три різні шари: (а) міжнародні клінічні гайдлайни (ERC, TCCC, TECC, WHO), (б) міжнародні операційні стандарти (METHANE, INSARAG, IMAS), (в) чинне право України, яке визначає, що саме цивільна особа *може* робити законно. Шар (в) є обмежувальним і має пріоритет над (а) і (б) у продуктових рішеннях.

---

## 1. Executive summary: що в поточній концепції продукту актуальне, а що застаріле або неправильно названо

Робочий каталог проєкту на момент дослідження порожній (немає файлів концепції в репозиторії), тому оцінка «поточної концепції» зроблена за переліком протоколів, наведеним у постановці задачі.

### 1.1 Застаріле або хибно назване

- **«MARCH / TCCC» як основа цивільного модуля — неправильний вибір рівня.** Чинні TCCC Guidelines від **01 May 2026** ([tccc.org.ua PDF](https://tccc.org.ua/files/downloads/clinical-guidelines-2026-en.pdf), [дзеркало CoTCCC/Allogy](https://learning-media.allogy.com/api/v1/pdf/18ccfdfc-a076-47e9-8a34-376efdd81b43/contents)) — це військовий документ, чиї ключові інтервенції (хірургічна крикотиреоїдотомія, голкова декомпресія 14G, конверсія турнікета, EtCO2-капнографія) юридично й практично недоступні цивільній особі в Україні. Коректний рівень — **TECC for Active Bystanders** (C-TECC), ухвалений **листопад 2024** ([c-tecc.org/news/guidelines-2024](https://www.c-tecc.org/news/guidelines-2024)). Крім того, у TECC акронім не «MARCH», а **MARCHE** (з фінальним *E — Everything else*) і застосовується лише у фазі **Indirect Threat Care** ([C-TECC Guidance](https://www.c-tecc.org/our-work/guidance)).
- **«SALT як національний стандарт США, який щойно оновили» — оновлення не існує.** SALT опубліковано у 2008 р. (Lerner et al., *Disaster Med Public Health Prep* 2008;2(Suppl 1):S25–S34, [DOI 10.1097/DMP.0b013e318182194e](https://doi.org/10.1097/DMP.0b013e318182194e)) і жодної нової редакції алгоритму не випущено. Національним *guideline* формально є не SALT, а **MUCC (Model Uniform Core Criteria for MCI Triage)**, а SALT — сумісна з MUCC реалізація ([ems.gov MUCC Addendum](https://www.ems.gov/assets/MUCC_Addendum_EMR.pdf)). Оновлення 2025 року стосується лише онлайн-курсу NDLSF, а не гайдлайну ([register3.ndlsf.org, last modified 19.06.2025](https://register3.ndlsf.org/mod/page/view.php?id=2056)).
- **Змішування SALT із «National Guideline for the Field Triage».** Це два різні документи. Field Triage Guideline (ред. **2021**, ACS) **прямо виключає масові втрати** зі своєї сфери застосування ([PMC9323557](https://pmc.ncbi.nlm.nih.gov/articles/PMC9323557/), [ACS](https://www.facs.org/quality-programs/trauma/systems/field-triage-guidelines/)). Для Zero Echelon він нерелевантний.
- **«ERC Guidelines 2021» / «AHA 2020» — застаріло.** Обидві родини гайдлайнів повністю переписані у **жовтні 2025**: ERC Guidelines 2025 (*Resuscitation* 2025;215(Suppl 1), 01.10.2025, [erc.edu](https://www.erc.edu/news/2025-erc-guidelines-is-released/)) і 2025 AHA Guidelines for CPR & ECC (*Circulation*, 22.10.2025, [DOI 10.1161/CIR.0000000000001372](https://www.ahajournals.org/doi/10.1161/CIR.0000000000001372)).
- **«WHO PFA — нова редакція» не існує.** Чинним залишається керівництво **2011** року ([who.int/publications/i/item/9789241548205](https://www.who.int/publications/i/item/9789241548205)); 2-ге видання 2024 р. — це вузька адаптація *для спалахів Ебола*, не заміна ([who.int 9789240101234](https://www.who.int/publications/i/item/9789240101234)).
- **«METHANE від MIMMS/NARU» — неточна атрибуція.** Канонічним власником формату є **JESIP Joint Doctrine Edition 3.1 (April 2024)**, і формат правильно записується **M/ETHANE** ([JESIP PDF v3.1](https://www.jesip.org.uk/wp-content/uploads/2022/03/JESIP_Joint-Doctrine_Version-3.1_April-2024.pdf)).
- **«Імпровізований турнікет як прийнятна опція» — суперечить чинному гайдлайну 2025.** ACS COT Stop the Bleed guideline (2025) прямо не підтримує імпровізовані турнікети ([DOI 10.1097/TA.0000000000004931](https://doi.org/10.1097/ta.0000000000004931), опубліковано у *J Trauma* 2026;100(6):989–992).
- **«Наказ МОЗ №441» — чинний, але його сфера дії вужча, ніж передбачає концепція.** Наказ №441 від 09.03.2022 чинний ([zakon.rada.gov.ua z0356-22](https://zakon.rada.gov.ua/go/z0356-22)), проте кожен Порядок у ньому адресований «особам, які **не мають медичної освіти, але за своїми службовими обов'язками повинні** надавати домедичну допомогу» — тобто не випадковому свідку. Це центральне юридичне обмеження продукту (див. розділ 4).

### 1.2 Актуальне і підтверджене

- **SALT** як алгоритм сортування — досі найкраща основа, бо єдиний, який *за конструкцією* однаковий для дорослих і дітей ([SALT 2008 PDF](https://em.umaryland.edu/files/uploads/ems/salt_2008.pdf)).
- **M/ETHANE** — актуальний формат (Ed. 3.1, April 2024).
- **IMAS 12.10 EORE** — чинна редакція Edition 2, Amendment 3, публікація 01.09.2020 ([mineactionstandards.org/standards/12-10](https://www.mineactionstandards.org/standards/12-10/)).
- **Наказ МОЗ №441** — чинний, і містить окремий Порядок «в умовах бойових дій / воєнного стану» з тризонною моделлю (пряма загроза / непряма загроза / евакуація), який структурно ідентичний фазам TECC. Це найкращий юридичний носій логіки продукту.

### 1.3 Три головні пропущені протоколи (детальніше в §§2.14, 2.6, 2.13)

1. **WHO / ICRC / MSF Mass Casualty – Interagency Integrated Triage Tool (MC-IITT)** — ліцензія CC BY-NC-SA 3.0 IGO, готова до легального повторного використання, з категоріями RED/YELLOW/GREEN/BLUE/GREY і віковими межами вітальних показників ([WHO MC-IITT PDF](https://cdn.who.int/media/docs/default-source/integrated-health-services-(ihs)/csy/mass-casualty---iitt.pdf?sfvrsn=3f2b7901_3)).
2. **ERC Guidelines 2025 First Aid** — єдиний чинний гайдлайн, який описує саме *first aid provider* (не клініциста) і вже містить порядок «bleeding перед A» + заборону цервікальних коміра для непрофесіоналів ([Resuscitation 2025](https://www.resuscitationjournal.com/article/S0300-9572(25)00264-3/fulltext)).
3. **ДСНС + IMAS 12.10 EORE як формальний scene-safety шар з правом вето**, включно з нормативом відходу 100–300 м і забороною повторного наближення ([bezpeka.dsns.gov.ua](https://bezpeka.dsns.gov.ua/materials/shcho-robyty-yakshcho-vyyavyly-minu-abo-inshyy-vybukhonebezpechnyy-predmet), [nmc.dsns.gov.ua](https://nmc.dsns.gov.ua/kyiv/news/ostanni-novini/shho-robiti-iakshho-vi-viiavili-zaliski-dronu-ci-bojepripasu)).

<!--APPEND-->
