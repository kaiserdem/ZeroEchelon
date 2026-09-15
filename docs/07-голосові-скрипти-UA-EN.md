# 07 — Голосові скрипти UA/EN

Дослівний текст, який застосунок каже вголос і показує на екрані. Реалізація не має права перефразувати. Ідентифікатори збігаються з вузлами [04](04-блок-схеми.md) і з полем `id` у [06](06-схема-даних-протоколу.md).

Терміни звіряються з [глосарієм](01-обсяг-роли-глосарій.md). Заборонена лексика — інваріант 7 валідатора графа.

---

## Принципи формулювання

1. Одна дія на фразу. Не «перевірте дихання і натисніть на рану».
2. Наказовий лад, теперішній час. Не «вам слід було б».
3. Спостережувані ознаки, не діагнози. Не «це пневмоторакс».
4. Українська і англійська — смислові близнюки, не літеральний підрядник.
5. Після наказу, якщо є типова помилка, — одне речення-заборона.
6. Питання — так / ні / не можу. Немає шкал і вільних «розкажіть».
7. Ніколи: мертвий / dead, все гаразд, можна не викликати, промийте шлунок, джгут із ременя, закрийте плівкою, розкажіть що сталося.

Довжина голосової фрази — бажано до 12 слів. Довші тексти (звіт диспетчеру) читаються з екрана, голос лише анонсує: «Зачитайте текст на екрані».

---

## Вхід

| id | UA | EN |
| --- | --- | --- |
| Start | Відкрито. Мережа не потрібна. | Opened. No network needed. |
| Home | Оберіть. Що потрібно зараз? | Choose. What do you need now? |
| Disclaimer | Спочатку викличте 103, якщо можете. Цей застосунок лише підказує кроки — рішення ваші. Закон сам по собі вас за допомогу не захищає. | Call 103 first if you can. This app only suggests steps — the decisions are yours. The law alone does not protect you for helping. |
| Loc-mode | Як передати місце диспетчеру? | How should we give the place to the dispatcher? |
| Loc-1 | Місце з коду: [адреса]. | Location from the code: [address]. |
| Loc-2 | Координати на екрані. Зачитаєте їх диспетчеру. | Coordinates on screen. Read them to the dispatcher. |
| Loc-3 | Назвіть населений пункт. Далі — вулицю. | Name the town or city. Then the street. |
| Type | Що сталося. Один вибір. | What happened. One choice. |
| Role | Ви допомагаєте іншим — чи допомога потрібна вам? | Are you helping others — or do you need help yourself? |
| Role-witness | Режим свідка. Спершу викличте 103, якщо можете. | Bystander mode. Call 103 first if you can. |
| Role-casualty | Режим постраждалого. Викличте 103. Далі — що зробити для себе. | Casualty mode. Call 103. Next — what to do for yourself. |
| Casualty-menu | Що потрібно вам зараз. Оберіть одне. | What do you need right now. Choose one. |
| Call | Викличте 103. Зачитайте текст на екрані. | Call 103. Read the text on the screen. |
| NEXT-PHASE | Вхід завершено. Далі — допомога за роллю. | Entry done. Next — help by role. |

---

## Виклик (завжди доступний)

| id | UA | EN |
| --- | --- | --- |
| CALL-103 | Викликати 103. | Call 103. |
| CALL-101 | Викликати 101. | Call 101. |
| CALL-read | Зачитайте текст на екрані. Не вигадуйте. | Read the text on the screen. Do not invent. |

---

## A. Безпека сцени

| id | UA | EN |
| --- | --- | --- |
| A1 | Чи бачите міну, уламок боєприпасу, дрон, підозрілий предмет? | Do you see a mine, munition fragment, drone, or a suspicious object? |
| A2 | Чи тріщить будинок, сиплеться пил, чути нові обвали? | Is the building cracking, dropping dust, or collapsing again? |
| A3 | Чи є вогонь, густий дим, запах газу? | Is there fire, thick smoke, or a smell of gas? |
| A4 | Чи є оголені дроти або вода біля проводів? | Are there bare wires, or water near wires? |
| A5 | Чи є різкий запах, невідома рідина, маслянисті плями? | Is there a sharp smell, an unknown liquid, or oily stains? |
| Out | Відійдіть на сто–триста метрів. Нічого не чіпайте. Натисніть 101 внизу. Не повертайтесь. | Move one hundred to three hundred metres away. Touch nothing. Tap 101 below. Do not go back. |
| Cont | Вважайте зону небезпечною. Не дійте тут. Натисніть 101 внизу. | Treat the area as unsafe. Do not act here. Tap 101 below. |
| CanLeave | Чи можете зараз відійти від небезпеки, не чіпаючи предмет і уламки? | Can you move away from the danger now without touching the object or rubble? |
| Out-trapped | Не чіпайте предмет і уламки. Не смикайте. Не звільняйте. Натисніть 101 внизу. У звіті зазначте: ви або люди тут. | Do not touch the object or rubble. Do not pull. Do not free anyone. Tap 101 below. In the report mark: you or people are here. |
| A6 | *За типом інциденту (рушій):* ДТП — проїжджа / аварійка / проводи; пожежа — дим; хімія — не чіпати; побут — вимкнути джерело; вибух/завал/потяг/стрілянина — не в завал. У `graph.json` лишається fallback «завал». | *By incident type (engine):* traffic — roadway / hazards / wires; fire — smoke; chemical — do not touch; household — turn off source; explosion/collapse/train/shooting — do not enter collapse. Graph fallback remains collapse wording. |
| A7 | Перевірте загрози знову. Повторний удар можливий. | Check the threats again. A second strike is possible. |

---

## B. Сортування

| id | UA | EN |
| --- | --- | --- |
| Count | Скільки людей постраждало. Один — чи двоє і більше? | How many people are hurt. One — or two or more? |
| B0 | Скажіть голосно: хто мене чує і може йти — ідіть до мене. | Say loudly: if you hear me and can walk — come to me. |
| B1 | Людина пішла сама? | Did the person walk to you? |
| Green | Зелений. Оглянете пізніше. Може тримати тиск, якщо скажете. | Green. Check later. This person can hold pressure if you ask. |
| B2 | Скажіть: хто не може йти — помахайте рукою. | Say: if you cannot walk — wave your hand. |
| B3 | Махає або тягнеться до вас? | Is the person waving or reaching for you? |
| First | Ідіть до того, хто не рухається. Не до того, хто кричить. | Go to the person who is not moving. Not to the one who is shouting. |
| Br | Грудна клітка піднімається? Повітря чути? | Does the chest rise? Can you feel air? |
| Kid | Це дитина? | Is this a child? |
| One | Закиньте голову обережно. Відкрийте рот. Приберіть видиме. | Tilt the head carefully. Open the mouth. Clear what you can see. |
| Two | Дитині: два вдихи рот до рота, якщо можете. | For a child: two rescue breaths if you can. |
| Again | Дихання зʼявилося? | Did breathing start? |
| NoResp | Не дихає, не реагує. Запамʼятайте місце. Ідіть до наступного. | Not breathing, not responding. Remember the place. Go to the next person. |
| Four | Чи реагує на голос? Чи є пульс на запʼясті? Чи дихає вільно? Чи кров зупинена? | Does the person respond? Is there a wrist pulse? Is breathing easy? Is bleeding stopped? |
| Red | Червоний. Допомагайте цій людині зараз. | Red. Help this person now. |
| Yellow | Жовтий. Допомога може зачекати. Повернетесь. | Yellow. Help can wait. You will return. |

---

## C. Кровотеча

| id | UA | EN |
| --- | --- | --- |
| C0 | Кров фонтанує? Є калюжа? Одяг мокрий від крові? Повʼязка промокає? | Is blood spurting? Is there a pool? Is clothing soaked? Is a dressing soaked through? |
| C2 | Натисніть на рану обома руками. Тисніть сильно. Не відпускайте. | Press on the wound with both hands. Press hard. Do not let go. |
| C3 | Кінцівка відірвана повністю або майже? | Is the limb torn off fully or almost? |
| C4 | Кров з руки чи ноги — і є справжній джгут з аптечки? | Is the blood from an arm or leg — and do you have a manufactured tourniquet? |
| Tq | Джгут — вище рани, не на суглоб. Затягніть до зупинки крові. Буде боляче. Не послаблюйте. | Tourniquet — above the wound, not on a joint. Tighten until the bleeding stops. It will hurt. Do not loosen. |
| Tq-anti | Не робіть джгут із ременя чи шарфа. Це може посилити кровотечу. | Do not make a tourniquet from a belt or a scarf. That can make bleeding worse. |
| Tq-time | Час записано. Назвіть його медикам. Не знімайте джгут. | Time is saved. Tell it to the medics. Do not take the tourniquet off. |
| Still | Кров іще йде? | Is blood still coming? |
| Second2 | Другий джгут ближче до тулуба. Перший не чіпайте. | A second tourniquet closer to the body. Do not touch the first one. |
| Pack | Заповніть рану чистою тканиною щільно. Зверху знову тисніть. | Pack the wound tightly with clean cloth. Then press again on top. |
| Hands | Треба йти до інших? | Do you need to go to others? |
| Hold | Тримайте. Не відпускайте до медиків. Я лишаюся з вами голосом. | Hold. Do not let go until medics arrive. I stay with you by voice. |
| Deleg | Підкличте людину, яка може ходити. Покладіть її руки на свої. Скажіть: тисніть, не відпускайте. | Call a person who can walk. Put their hands on yours. Say: press, do not let go. |
| Deleg-helper | Ви тримаєте тиск. Не відпускайте. Якщо слабшаєте — кричіть. | You are holding pressure. Do not let go. If you weaken — shout. |

---

## D. Дихання і положення

| id | UA | EN |
| --- | --- | --- |
| D0 | Людина дихає нормально? Грудна клітка піднімається рівно? | Is the person breathing normally? Does the chest rise evenly? |
| D1 | Був вибух? Або є рана, що проходить у тіло? | Was there an explosion? Or a wound that goes into the body? |
| NoCpr | Реанімація тут не допоможе. Ідіть до наступного, кого ще можна врятувати. | CPR will not help here. Go to the next person you can still save. |
| Cpr | Кладіть основу долоні на середину грудей. Тисніть глибоко. Часто. Без вдихів. | Heel of the hand on the centre of the chest. Push deep. Push fast. No breaths. |
| Metron | Слухайте ритм. Не зупиняйтесь, поки не зміниться стан або не приїдуть медики. | Follow the beat. Do not stop until the person changes or medics arrive. |
| D2 | Ви лишаєтесь біля цієї людини? | Are you staying with this person? |
| Sup | Залиште на спині. Не повертайте на бік. За потреби висуньте нижню щелепу вперед. | Leave the person on their back. Do not roll onto the side. If needed, push the lower jaw forward. |
| Lat | Поверніть на бік. Інакше може закритися дихання, поки вас немає. | Roll onto the side. Otherwise the airway may close while you are gone. |
| Neck | Шию силоміць не тримайте. Перевертати — лише разом і як одне ціле. | Do not force the neck still. Roll only together, as one piece. |

---

## E. Грудна клітка

| id | UA | EN |
| --- | --- | --- |
| E0 | Є дірка в грудях або спині між пупком і плечима? | Is there a hole in the chest or back between the navel and the shoulders? |
| E1 | Залиште рану відкритою. | Leave the wound open. |
| Anti | Не заклеюйте. Ні плівкою, ні скотчем, ні пакетом. Закрита рана може вбити. | Do not seal it. Not with film, tape, or a bag. A sealed wound can kill. |
| E2 | Є спеціальна наліпка з клапаном — і ви вмієте її клеїти? | Do you have a vented chest seal — and do you know how to apply it? |
| Open | Лишіть відкритою. Тисніть лише якщо кров іде сильно. | Leave it open. Press only if blood is coming fast. |
| Vent | Накладіть наліпку з клапаном. Дивіться, як дихає. | Apply the vented seal. Watch the breathing. |
| E3 | Тривога і задишка наростають? | Are fear and shortness of breath getting worse? |
| Burp | Зніміть наліпку. Дайте повітрю вийти. Потім накладіть знову, якщо вмієте. | Take the seal off. Let air out. Then put it back if you know how. |

---

## F. Тривале стискання

| id | UA | EN |
| --- | --- | --- |
| F0 | Частину тіла притиснуло — плита, вагон, стіна? | Is part of the body trapped — slab, carriage, wall? |
| F1 | Не звільняйте. Не піднімайте вагу. Не тягніть. | Do not free them. Do not lift the weight. Do not pull. |
| Why | Якщо зняти тиск зараз — людина, яка говорить, може раптово померти. | If you release the pressure now — a person who is talking can die suddenly. |
| F2 | Залишайтесь. Говоріть. Скажіть, що допомога їде. | Stay. Talk. Say that help is coming. |
| F3 | Запамʼятайте три речі: скільки вже притиснуто, яку частину тіла, чи у свідомості. | Remember three things: how long they have been trapped, which body part, and whether they are awake. |
| F4 | Скажіть це рятувальникам до того, як вони почнуть звільняти. | Tell the rescuers this before they start to free the person. |

---

## G. Психологічна підтримка

| id | UA | EN |
| --- | --- | --- |
| G0 | Огляньте: чи безпечно вам. Хто потребує води, тепла, тиші. | Look: are you safe. Who needs water, warmth, quiet. |
| G1 | Сядьте або станьте поруч. Тихий голос. Запитайте: що вам зараз потрібно. | Sit or stand nearby. Quiet voice. Ask: what do you need right now. |
| G2 | Скажіть правду, яку знаєте. Допоможіть знайти близьких, якщо це безпечно. | Tell the truth you know. Help find family if that is safe. |
| G3 | Людина каже, що важко дихати? | Does the person say it is hard to breathe? |
| Flags | Є кров у кашлі? Біль у грудях? Сині губи? Набряк обличчя? Шумне дихання? | Blood in the cough? Chest pain? Blue lips? Face swelling? Noisy breathing? |
| Organic | Це не просто страх. Викличте 103. Не заспокоюйте диханням. | This is not just fear. Call 103. Do not treat this with breathing. |
| Ground | Поставте стопи на підлогу. Постукайте пальцями по колінах. Назвіть три речі, які бачите. | Put your feet on the floor. Tap your knees. Name three things you can see. |
| Slow | Дихайте повільніше. Я з вами. Не рахуйте. | Breathe more slowly. I am with you. Do not count. |
| Ban | Не питайте, що сталося. Не просіть описати почуття. | Do not ask what happened. Do not ask them to describe feelings. |

---

## H. Звіт і передача

| id | UA | EN |
| --- | --- | --- |
| Form | Звіт для служб готовий. | The report for responders is ready. |
| Read | Зачитайте диспетчеру текст на екрані. | Read the on-screen text to the dispatcher. |
| Give | QR для медика. | QR for the medic. |
| Give-warn | *(прибрано з екрана — дубль попередження; текст звіту лишається на Form)* | *(removed from screen)* |
| Handed | Передали медику. Лишити журнал для нагадувань через 24 і 48 годин — чи стерти зараз? | Handed to the medic. Keep the log for 24 and 48 hour reminders — or erase now? |
| Erase | Стерти журнал зараз. | Erase the log now. |

Шаблон зачитування — [08](08-звіт-M-ETHANE-та-передача.md), розділ 3. Голос лише дає команду `Read`.

---

## I. Друга хвиля

| id | UA | EN |
| --- | --- | --- |
| I0 | Минуло двадцять чотири години після події. Короткі питання. | Twenty-four hours after the event. Short questions. |
| I1 | Є кров у кашлі, задишка, біль у грудях, сині губи? | Coughing blood, shortness of breath, chest pain, blue lips? |
| I2 | Сеча темна, як чай? Сечі стало менше? Кінцівка пухне і болить сильніше? | Is urine dark like tea? Less urine than usual? Is a limb more swollen and more painful? |
| I3 | Головний біль не минає або наростає? Було блювання? Сонливість, плутана мова? | Headache that stays or grows? Any vomiting? Sleepiness, confused speech? |
| I4 | Біль у животі? Кров у блювоті або в стільці? | Belly pain? Blood in vomit or stool? |
| Go | Негайно 103 або до лікарні. Не чекайте. | Call 103 or go to hospital now. Do not wait. |
| I5 | Немає цих ознак — спостереження триває. Це не висновок «усе добре». Повтор через двадцять чотири години. | No such signs — watching continues. This is not an all-clear. Repeat in twenty-four hours. |

---

## J. Щоденний модуль

| id | UA | EN |
| --- | --- | --- |
| J0 | Що бачите. Оберіть одне. | What do you see. Choose one. |
| Kit | Відкрийте аптечку. Позначте, що в ній є. Не вигадуйте решти. | Open the kit. Mark what is there. Do not assume the rest. |
| Str | Усмішка крива? Рука не піднімається? Мова плутана? Коли це почалося — запамʼятайте годину. Викличте 103. Не давайте їсти і пити. | Crooked smile? Arm will not rise? Speech jumbled? Remember when this started. Call 103. Give nothing to eat or drink. |
| Poi | Приберіть речовину. Викличте 103. Збережіть упаковку. | Remove the substance. Call 103. Keep the container. |
| Poi-anti | Не викликайте блювання. Не промивайте шлунок. Не давайте пити. | Do not make them vomit. Do not wash out the stomach. Give nothing to drink. |
| Ana | Свист у диханні? Набряк обличчя? Людина каже, що зараз втратить свідомість? | Wheeze? Face swelling? Does the person say they will pass out? |
| Adr | Адреналін — у зовнішню сторону стегна, крізь одяг якщо треба. Тримати. Викликати 103. Сидіти або лежати. Не вставати. | Adrenaline — into the outer thigh, through clothes if needed. Hold. Call 103. Sit or lie down. Do not stand up. |
| Adr-2 | Пʼять хвилин. Симптоми тяжкі? Друга доза так само в стегно. | Five minutes. Still severe? A second dose, same way, into the thigh. |
| NoAnti | Таблетка від алергії не замінює адреналін і не дає права чекати. | An allergy tablet does not replace adrenaline and is not a reason to wait. |
| Local | Холод на місце укусу. Дивіться, чи не зʼявиться свист або набряк обличчя. | Cold on the sting. Watch for wheeze or face swelling. |
| Side | Поверніть на бік. Контролюйте дихання. | Roll onto the side. Watch the breathing. |
| Comf | Зручно і не рухатися. | Comfortable and still. |

---

## Звірка з глосарієм

Обовʼязкові пари, які не замінюються синонімами в скриптах: нульовий ешелон / Zero Echelon; червоний / red; жовтий / yellow; зелений / green; «не дихає, не реагує» / «not breathing, not responding»; прямий тиск / direct pressure; тампонада / wound packing; джгут лише як manufactured tourniquet; відкрита рана грудної клітки / open chest wound; краш / crush; друга хвиля / second wave.

Якщо симуляція в [11](11-пілот-та-валідація.md) покаже, що фраза не спрацьовує, зміна йде сюди, потім у граф — не навпаки.
