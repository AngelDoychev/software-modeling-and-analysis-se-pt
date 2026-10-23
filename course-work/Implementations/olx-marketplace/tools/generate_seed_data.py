"""
Генератор на тестови данни за OlxDB.
Пуска се веднъж:  python tools/generate_seed_data.py
и записва sql/06_seed_data.sql

Използвам фиксиран seed, за да излизат едни и същи данни при всяко пускане.
"""
import hashlib
import random
from datetime import datetime, timedelta
from pathlib import Path

random.seed(2026)

NOW = datetime(2026, 10, 20, 18, 0, 0)
START = datetime(2025, 1, 5)

OUT = Path(__file__).resolve().parent.parent / "sql" / "06_seed_data.sql"

# ---------------------------------------------------------------- helpers
def q(v):
    """SQL литерал"""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, datetime):
        return "'" + v.strftime("%Y-%m-%dT%H:%M:%S") + "'"
    if isinstance(v, Money):
        return f"{v.value:.2f}"
    if isinstance(v, Ascii):
        return "'" + v.s.replace("'", "''") + "'"
    return "N'" + str(v).replace("'", "''") + "'"


class Money:
    def __init__(self, value):
        self.value = round(value, 2)


class Ascii:
    def __init__(self, s):
        self.s = s


def rand_dt(a, b):
    if b <= a:
        return a
    return a + timedelta(seconds=random.randint(0, int((b - a).total_seconds())))


out = []


def emit_insert(table, cols, rows, identity=True):
    if not rows:
        return
    out.append(f"------------ {table} ------------")
    if identity:
        out.append(f"SET IDENTITY_INSERT {table} ON;")
    for i in range(0, len(rows), 500):
        chunk = rows[i:i + 500]
        out.append(f"INSERT INTO {table}\n    ({', '.join(cols)})\nVALUES")
        out.append(",\n".join("    (" + ", ".join(q(v) for v in r) + ")" for r in chunk) + ";")
    if identity:
        out.append(f"SET IDENTITY_INSERT {table} OFF;")
    out.append("GO\n")


# ---------------------------------------------------------------- cities
cities = [
    ("София", "София-град", "1000", 30),
    ("Пловдив", "Пловдив", "4000", 14),
    ("Варна", "Варна", "9000", 12),
    ("Бургас", "Бургас", "8000", 9),
    ("Русе", "Русе", "7000", 5),
    ("Стара Загора", "Стара Загора", "6000", 5),
    ("Плевен", "Плевен", "5800", 4),
    ("Велико Търново", "Велико Търново", "5000", 4),
    ("Благоевград", "Благоевград", "2700", 3),
    ("Шумен", "Шумен", "9700", 3),
    ("Добрич", "Добрич", "9300", 2),
    ("Хасково", "Хасково", "6300", 2),
    ("Пазарджик", "Пазарджик", "4400", 3),
    ("Сливен", "Сливен", "8800", 2),
    ("Габрово", "Габрово", "5300", 2),
    ("Асеновград", "Пловдив", "4230", 2),
    ("Казанлък", "Стара Загора", "6100", 2),
    ("Перник", "Перник", "2300", 2),
]
city_rows = [(i + 1, c[0], c[1], Ascii(c[2])) for i, c in enumerate(cities)]
city_weights = [c[3] for c in cities]
city_ids = list(range(1, len(cities) + 1))
city_name = {i + 1: c[0] for i, c in enumerate(cities)}

# ---------------------------------------------------------------- couriers
couriers = [
    (1, "Speedy", Money(3.20), Ascii("https://www.speedy.bg")),
    (2, "Еконт", Money(3.40), Ascii("https://www.econt.com")),
    (3, "BOX NOW", Money(2.30), Ascii("https://boxnow.bg")),
]
courier_price = {1: 3.20, 2: 3.40, 3: 2.30}

# ---------------------------------------------------------------- promo packages
packages = [
    (1, Ascii("TOP7"), "Топ обява 7 дни", 7, Money(4.99), "Обявата стои най-отгоре в категорията за 7 дни."),
    (2, Ascii("TOP15"), "Топ обява 15 дни", 15, Money(8.99), "Обявата стои най-отгоре в категорията за 15 дни."),
    (3, Ascii("BUMP"), "Обнови на първа позиция", 1, Money(1.49), "Еднократно връщане на обявата най-отгоре в списъка."),
    (4, Ascii("HIGHLIGHT"), "Изтъкната обява", 30, Money(6.99), "Обявата се показва с цветна рамка 30 дни."),
    (5, Ascii("VIP"), "VIP пакет", 30, Money(14.99), "Топ обява + изтъкната + 3 обновявания."),
]
package_info = {p[0]: (p[3], p[4].value) for p in packages}

# ---------------------------------------------------------------- categories
# (име, slug, [(подкатегория, slug, тегло, (минЦена, максЦена), шанс за доставка, [заглавия])])
category_tree = [
    ("Електроника", "elektronika", [
        ("Телефони", "telefoni", 14, (60, 950), 0.95, [
            "iPhone 13 128GB", "iPhone 14 Pro 256GB", "Samsung Galaxy S23", "Samsung Galaxy A54",
            "Xiaomi Redmi Note 12", "Google Pixel 7a", "iPhone 11 64GB", "Motorola Edge 40",
            "Xiaomi 13T Pro", "Samsung Galaxy S21 FE"]),
        ("Компютри и лаптопи", "kompyutri", 10, (90, 1400), 0.9, [
            "Лаптоп Lenovo ThinkPad T480", "MacBook Air M1 8/256", "Геймърски компютър RTX 3060",
            "Монитор Dell 27\" QHD", "Лаптоп HP ProBook 450 G8", "Таблет iPad 9 поколение",
            "Клавиатура Logitech MX Keys", "Лаптоп ASUS TUF Gaming"]),
        ("ТВ и аудио", "tv-audio", 6, (25, 700), 0.85, [
            "Телевизор Samsung 55\" 4K", "Слушалки Sony WH-1000XM4", "Колонка JBL Charge 5",
            "Саундбар LG SN5Y", "Телевизор LG 43\" Smart", "Грамофон Audio-Technica"]),
        ("Игри и конзоли", "igri-konzoli", 6, (15, 500), 0.95, [
            "PlayStation 5 с два джойстика", "Nintendo Switch OLED", "Xbox Series S 512GB",
            "Игри за PS4 - комплект 5 бр.", "Джойстик DualSense", "Steam Deck 256GB"]),
    ]),
    ("Автомобили и части", "avto", [
        ("Автомобили", "avtomobili", 5, (2500, 19000), 0.0, [
            "VW Golf 6 1.6 TDI", "Opel Astra H 1.7 CDTI", "Toyota Yaris 1.3 бензин",
            "BMW 320d E90", "Skoda Octavia 2.0 TDI", "Renault Clio 1.2", "Ford Focus 1.6 TDCi"]),
        ("Авточасти и аксесоари", "avtochasti", 7, (20, 600), 0.9, [
            "Джанти 17\" 5x112 за VW/Audi", "Зимни гуми Michelin 205/55 R16", "Фар за BMW E90",
            "Навигация Garmin DriveSmart", "Видеорегистратор 70mai", "Стелки за Golf 7"]),
    ]),
    ("Дом и градина", "dom-gradina", [
        ("Мебели", "mebeli", 7, (30, 700), 0.25, [
            "Ъглов диван с функция сън", "Маса с 4 стола", "Гардероб с 3 крила", "Офис стол ергономичен",
            "Единично легло с матрак", "Шкаф за обувки", "Холна масичка"]),
        ("Домакински уреди", "uredi", 7, (25, 600), 0.6, [
            "Пералня Bosch 7кг", "Хладилник Liebherr", "Прахосмукачка Dyson V8", "Кафемашина DeLonghi Magnifica",
            "Микровълнова фурна Samsung", "Робот прахосмукачка Roborock", "Еър фрайър Philips"]),
        ("Инструменти", "instrumenti", 6, (20, 350), 0.9, [
            "Перфоратор Bosch GBH 2-26", "Комплект гедоре Makita", "Ъглошлайф DeWalt 125мм",
            "Косачка за трева бензинова", "Акумулаторен винтоверт Milwaukee", "Верижен трион Stihl"]),
    ]),
    ("Мода", "moda", [
        ("Дамски дрехи", "damski-drehi", 7, (8, 130), 1.0, [
            "Зимно яке Zara размер M", "Рокля Mango", "Дънки Levi's 501", "Палто от вълна",
            "Пухено яке Columbia", "Комплект блузи H&M"]),
        ("Мъжки дрехи", "mazhki-drehi", 6, (10, 220), 1.0, [
            "Яке The North Face размер L", "Костюм Hugo Boss 50", "Суитшърт Nike", "Риза Tommy Hilfiger",
            "Шушляк Adidas", "Дънки Diesel 32/32"]),
        ("Обувки", "obuvki", 6, (12, 160), 1.0, [
            "Маратонки Nike Air Max 42", "Боти Timberland 41", "Adidas Samba 43", "Дамски ботуши 38",
            "Обувки за бягане Asics 44", "New Balance 574 номер 40"]),
    ]),
    ("Спорт, книги, хоби", "sport-hobi", [
        ("Велосипеди и тротинетки", "velosipedi", 5, (60, 1200), 0.6, [
            "Планински велосипед Cube 29\"", "Шосеен велосипед Btwin", "Детско колело 20\"",
            "Електрическа тротинетка Xiaomi Pro 2", "Сгъваем велосипед", "Електрически велосипед"]),
        ("Книги и учебници", "knigi", 5, (3, 60), 1.0, [
            "Комплект книги Хари Потър", "Учебници за 10 клас", "Под игото - Иван Вазов",
            "Програмиране на C# - Светлин Наков", "Помагало за матура по БЕЛ", "Енциклопедия за деца"]),
        ("Фитнес", "fitnes", 4, (15, 500), 0.7, [
            "Дъмбели 2 x 10 кг", "Бягаща пътека", "Лежанка за фитнес", "Комплект гири",
            "Велоергометър", "Лост за набирания"]),
    ]),
    ("Детски и бебешки", "detski", [
        ("Колички и столчета", "kolichki", 4, (40, 450), 0.8, [
            "Бебешка количка Chipolino 3в1", "Количка Cybex Balios", "Столче за кола Maxi-Cosi",
            "Бебешка кошара", "Столче за хранене"]),
        ("Играчки", "igrachki", 5, (5, 150), 1.0, [
            "LEGO Technic комплект", "Дървена кухня", "Къща за кукли Barbie", "Конструктор Magformers",
            "Пъзел 1000 части", "Детски велосипед с помощни колела"]),
    ]),
    ("Животни", "zhivotni", [
        ("Аксесоари за животни", "aksesoari-zhivotni", 3, (8, 200), 0.9, [
            "Транспортна чанта за котка", "Аквариум 100л с филтър", "Кучешка колиба", "Клетка за папагал",
            "Драскалка за котки", "Легло за куче размер L"]),
    ]),
]

category_rows = []
leaf_categories = []  # (id, weight, price range, delivery chance, titles, name)
cid = 0
parents = []
for name, slug, _subs in category_tree:
    cid += 1
    parents.append(cid)
    category_rows.append((cid, None, name, Ascii(slug)))
for (name, slug, subs), pid in zip(category_tree, parents):
    for sname, sslug, w, pr, dlv, titles in subs:
        cid += 1
        category_rows.append((cid, pid, sname, Ascii(sslug)))
        leaf_categories.append((cid, w, pr, dlv, titles, sname))

# ---------------------------------------------------------------- users
male_first = ["Георги", "Иван", "Димитър", "Николай", "Петър", "Стефан", "Христо", "Александър", "Мартин",
              "Калоян", "Васил", "Тодор", "Михаил", "Борис", "Емил", "Кристиян", "Ангел", "Радослав", "Йордан", "Виктор"]
female_first = ["Мария", "Елена", "Иванка", "Десислава", "Гергана", "Николета", "Виктория", "Петя", "Надежда",
                "Радостина", "Цветелина", "Кристина", "Милена", "Теодора", "Йоана", "Симона", "Габриела", "Ралица"]
surname_roots = ["Иванов", "Георгиев", "Димитров", "Петров", "Николов", "Христов", "Стоянов", "Тодоров",
                 "Колев", "Ангелов", "Маринов", "Попов", "Костадинов", "Василев", "Стефанов", "Атанасов",
                 "Илиев", "Кирилов", "Добрев", "Младенов", "Методиев", "Йорданов", "Генчев", "Пенев"]

translit = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ж": "zh", "з": "z", "и": "i", "й": "y",
    "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
    "ф": "f", "х": "h", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sht", "ъ": "a", "ь": "y", "ю": "yu", "я": "ya",
}


def latin(s):
    return "".join(translit.get(ch, ch) for ch in s.lower())


business_names = [("Техно", "Маркет ЕООД"), ("ГСМ", "Сервиз"), ("Авто", "Части Плюс"),
                  ("Мебели", "Дизайн ООД"), ("Бейби", "Шоп"), ("Спорт", "Аутлет"), ("Книжарница", "Хеликон"),
                  ("ЗооМаг", "ЕООД")]

N_USERS = 90
users = []           # dict
emails = set()
domains = ["gmail.com", "abv.bg", "mail.bg", "yahoo.com", "outlook.com"]
for uid in range(1, N_USERS + 1):
    is_business = uid % 11 == 0  # около 8 бизнес профила
    city = random.choices(city_ids, weights=city_weights)[0]
    if is_business:
        first, last = business_names[(uid // 11 - 1) % len(business_names)]
        base = latin(first + last).replace(" ", "")
        email = f"office@{base[:14]}.bg"
    else:
        if random.random() < 0.5:
            first = random.choice(male_first)
            last = random.choice(surname_roots)
        else:
            first = random.choice(female_first)
            last = random.choice(surname_roots) + "а"
        base = f"{latin(first)}.{latin(last)}"
        email = f"{base}@{random.choice(domains)}"
        n = 1
        while email in emails:
            n += 1
            email = f"{base}{random.randint(1, 99)}@{random.choice(domains)}"
    emails.add(email)
    phone = "08" + random.choice("789") + "".join(str(random.randint(0, 9)) for _ in range(7))
    pwd = hashlib.sha256(f"pass-{uid}-{email}".encode()).hexdigest()
    registered = rand_dt(datetime(2019, 3, 1), datetime(2025, 9, 1))
    state = 0 if uid in (37, 74) else 1
    users.append(dict(id=uid, first=first, last=last, email=email, phone=phone, pwd=pwd, city=city,
                      business=is_business, registered=registered, state=state))

user_rows = [(u["id"], u["first"], u["last"], u["email"], Ascii(u["phone"]), Ascii(u["pwd"]), u["city"],
              u["business"], u["registered"], u["state"]) for u in users]
active_user_ids = [u["id"] for u in users if u["state"] == 1]
seller_weights = [6 if users[i - 1]["business"] else 1 for i in active_user_ids]

# ---------------------------------------------------------------- listings
conditions_text = ["отлично", "много добро", "добро", "като ново", "запазено"]
reasons = ["Продавам, защото си взех нов.", "Не го ползвам вече.", "Подарък, който не ми трябва.",
           "Местя се и разпродавам.", "Остана от ремонт.", "Причина за продажба - смяна на модела.",
           "Пазено, без забележки.", "Има леки следи от употреба, личат на снимките."]


# по-реалистични цени за някои конкретни артикули (иначе се взима диапазонът на категорията)
TITLE_PRICE = {
    "iPhone 13 128GB": (330, 420), "iPhone 14 Pro 256GB": (600, 760), "Samsung Galaxy S23": (380, 480),
    "Samsung Galaxy A54": (150, 210), "Xiaomi Redmi Note 12": (90, 140), "Google Pixel 7a": (200, 260),
    "iPhone 11 64GB": (180, 240), "Motorola Edge 40": (170, 230), "Xiaomi 13T Pro": (350, 430),
    "Samsung Galaxy S21 FE": (160, 220), "MacBook Air M1 8/256": (450, 560),
    "Лаптоп Lenovo ThinkPad T480": (190, 260), "Геймърски компютър RTX 3060": (650, 900),
    "Монитор Dell 27\" QHD": (140, 200), "Лаптоп HP ProBook 450 G8": (300, 420),
    "Таблет iPad 9 поколение": (190, 250), "Клавиатура Logitech MX Keys": (60, 85),
    "Лаптоп ASUS TUF Gaming": (500, 750), "Слушалки Sony WH-1000XM4": (130, 180),
    "Колонка JBL Charge 5": (70, 110), "PlayStation 5 с два джойстика": (330, 420),
    "Nintendo Switch OLED": (230, 290), "Xbox Series S 512GB": (180, 230), "Джойстик DualSense": (40, 55),
    "Steam Deck 256GB": (300, 380), "Игри за PS4 - комплект 5 бр.": (35, 70),
    "Прахосмукачка Dyson V8": (120, 180), "Еър фрайър Philips": (45, 80),
    "Електрическа тротинетка Xiaomi Pro 2": (180, 260), "Детско колело 20\"": (50, 90),
    "Под игото - Иван Вазов": (3, 8), "Пъзел 1000 части": (6, 15),
}


def nice_price(lo, hi):
    p = random.uniform(lo, hi)
    if random.random() < 0.6:  # повечето хора слагат "кръгли" цени
        p = random.uniform(lo, (lo + hi) / 2)
    if p >= 1000:
        return float(round(p / 50) * 50)
    if p >= 100:
        return float(round(p / 5) * 5)
    if p >= 20:
        return float(round(p))
    return round(p, 1) if random.random() < 0.3 else float(round(p))


N_LISTINGS = 460
listings = []
leaf_weights = [c[1] for c in leaf_categories]
for lid in range(1, N_LISTINGS + 1):
    cat = random.choices(leaf_categories, weights=leaf_weights)[0]
    cat_id, _, pr, dlv_chance, titles, cat_name = cat
    seller = random.choices(active_user_ids, weights=seller_weights)[0]
    su = users[seller - 1]
    city = su["city"] if random.random() < 0.92 else random.choices(city_ids, weights=city_weights)[0]
    title = random.choice(titles)
    if random.random() < 0.3:
        title += random.choice([" - спешно", " - като нов", " + подарък", " - с гаранция", " - перфектен"])
    is_new = random.random() < (0.35 if su["business"] else 0.12)
    price = nice_price(*TITLE_PRICE.get(title.split(" - ")[0].split(" + ")[0], pr))
    if is_new:
        price = float(round(price * 1.15))
    lo = max(START, su["registered"])
    if random.random() < 0.18:
        created = rand_dt(NOW - timedelta(days=30), NOW - timedelta(hours=3))
    else:
        created = rand_dt(lo, NOW - timedelta(days=1))
    delivery = random.random() < dlv_chance
    item = title.split(' - ')[0].split(' + ')[0]
    if "\u0400" <= item[0] <= "\u04ff" and not item.startswith("Под игото"):
        item = item[0].lower() + item[1:]
    descr = (f"Продавам {item}. Състояние: {'ново, неразопаковано' if is_new else random.choice(conditions_text)}. "
             f"{random.choice(reasons)} "
             f"{'Изпращам с OLX доставка.' if delivery else 'Само на място в ' + city_name[city] + '.'}"
             f"{' Цената е по договаряне.' if random.random() < 0.3 else ''}")
    age_days = (NOW - created).days + 1
    views = int(random.uniform(15, 60) * (age_days ** 0.45)) + random.randint(0, 40)
    listings.append(dict(id=lid, user=seller, cat=cat_id, cat_name=cat_name, city=city, title=title, descr=descr,
                         price=price, cond="New" if is_new else "Used", neg=random.random() < 0.4,
                         delivery=delivery, created=created, expires=created + timedelta(days=30),
                         views=views, status=None))

# статус преди поръчките (продадените ще ги маркира тригерът)
for l in listings:
    recent = l["expires"] > NOW
    if recent:
        l["status"] = "Active" if random.random() < 0.92 else "Inactive"
    else:
        l["status"] = "Expired" if random.random() < 0.7 else "Inactive"

# ---------------------------------------------------------------- orders
orders = []
oid = 0
street_names = ["Витоша", "Цар Борис III", "Васил Левски", "Христо Ботев", "Шипка", "Раковски",
                "Александър Стамболийски", "Княз Борис I", "Македония", "Оборище", "Гладстон", "Опълченска"]
for l in sorted(listings, key=lambda x: x["created"]):
    if not l["delivery"] or l["status"] == "Inactive" and l["expires"] > NOW:
        continue
    if random.random() > 0.36:
        continue
    ordered = rand_dt(l["created"] + timedelta(hours=5), min(l["expires"], NOW) - timedelta(hours=1))
    if ordered >= NOW or ordered <= l["created"]:
        continue
    buyer = random.choice([u for u in active_user_ids if u != l["user"]])
    age = (NOW - ordered).days
    if age < 2:
        status = random.choice(["Pending", "Pending", "Shipped"])
    elif age < 4:
        status = random.choice(["Shipped", "Delivered", "Delivered"])
    else:
        status = random.choices(["Delivered", "Cancelled", "Returned"], weights=[86, 8, 6])[0]
    courier = random.choices([1, 2, 3], weights=[45, 40, 15])[0]
    pay = "CashOnDelivery" if random.random() < 0.62 else "Card"
    fee = courier_price[courier]
    if pay == "CashOnDelivery":
        fee += max(0.50, round(l["price"] * 0.015, 2))
    delivered = None
    if status in ("Delivered", "Returned"):
        delivered = ordered + timedelta(days=random.choice([1, 1, 2, 2, 2, 3, 4]), hours=random.randint(0, 8))
        if delivered > NOW:
            delivered = NOW - timedelta(hours=1)
    bu = users[buyer - 1]
    addr = f"{city_name[bu['city']]}, ул. „{random.choice(street_names)}“ {random.randint(1, 140)}"
    if random.random() < 0.35:
        addr = f"{city_name[bu['city']]}, офис на {['Speedy', 'Еконт', 'BOX NOW автомат'][courier - 1]}"
    oid += 1
    orders.append(dict(id=oid, listing=l["id"], buyer=buyer, courier=courier, price=l["price"], fee=round(fee, 2),
                       pay=pay, status=status, addr=addr, ordered=ordered, delivered=delivered, seller=l["user"]))

# ---------------------------------------------------------------- images
images = []
img_id = 0
for l in listings:
    for s in range(1, random.choice([1, 2, 3, 3, 4, 5, 6]) + 1):
        img_id += 1
        h = hashlib.md5(f"{l['id']}-{s}".encode()).hexdigest()[:20]
        images.append((img_id, l["id"], Ascii(f"https://img.olx-demo.bg/listings/{l['id']}/{h}.jpg"), s,
                       l["created"] + timedelta(minutes=s)))

# ---------------------------------------------------------------- price history (свалени цени)
price_hist = []
ph_id = 0
for l in random.sample(listings, 85):
    changes = random.choice([1, 1, 1, 2])
    price_now = l["price"]
    hist = []
    for _ in range(changes):
        old = float(round(price_now * random.uniform(1.06, 1.25)))
        hist.append((old, price_now))
        price_now = old
    t = l["created"]
    for old, new in reversed(hist):
        t = rand_dt(t + timedelta(hours=6), t + timedelta(days=8))
        if t > NOW:
            t = NOW - timedelta(hours=2)
        ph_id += 1
        price_hist.append((ph_id, l["id"], Money(old), Money(new), t))

# ---------------------------------------------------------------- favorites
favorites = set()
fav_rows = []
attempts = 0
while len(fav_rows) < 650 and attempts < 10000:
    attempts += 1
    l = random.choice(listings)
    u = random.choice(active_user_ids)
    if u == l["user"] or (u, l["id"]) in favorites:
        continue
    favorites.add((u, l["id"]))
    fav_rows.append((u, l["id"], rand_dt(l["created"], min(l["expires"], NOW))))

# ---------------------------------------------------------------- promotions
promos = []
pr_id = 0
promo_candidates = random.sample(listings, 120)
for l in promo_candidates:
    if l["status"] == "Inactive":
        continue
    pkg = random.choices([1, 2, 3, 4, 5], weights=[30, 15, 35, 12, 8])[0]
    days, price = package_info[pkg]
    start = rand_dt(l["created"], l["created"] + timedelta(days=5))
    if start > NOW:
        start = l["created"]
    pr_id += 1
    promos.append((pr_id, l["id"], pkg, start, start + timedelta(days=days), Money(price)))
    if pkg == 3 and random.random() < 0.4:  # някои хора обновяват повторно
        s2 = start + timedelta(days=random.randint(3, 10))
        if s2 < NOW:
            pr_id += 1
            promos.append((pr_id, l["id"], 3, s2, s2 + timedelta(days=1), Money(price)))

# ---------------------------------------------------------------- conversations + messages
first_msgs = ["Здравейте, актуална ли е обявата?", "Здравейте, ще пуснете ли малко от цената?",
              "Може ли още снимки?", "Добър ден, в какво състояние е реално?",
              "Здравейте, изпращате ли до {city}?", "Има ли някакви забележки?",
              "Здравейте, кога може да се види на място?", "Последна цена?"]
seller_replies = ["Да, актуална е.", "Мога да сваля до {p} €, по-надолу не.", "Пратих ви още снимки.",
                  "Няма забележки, всичко работи.", "Изпращам до 2 дни след поръчката.",
                  "Може утре след 18ч.", "Цената е крайна, съжалявам.", "Да, изпращам с OLX доставка."]
buyer_follow = ["Добре, поръчвам през OLX доставка.", "Благодаря, ще помисля.", "Супер, взимам го.",
                "Добре, ще пиша пак.", "Може ли да е с наложен платеж?", "Окей, благодаря!"]

conversations = []
messages = []
conv_id = 0
msg_id = 0
conv_pairs = set()


def add_conversation(l, buyer, start, ends_with_order):
    global conv_id, msg_id
    conv_id += 1
    conv_pairs.add((l["id"], buyer))
    conversations.append((conv_id, l["id"], buyer, start))
    t = start
    n = random.randint(2, 6)
    bcity = city_name[users[buyer - 1]["city"]]
    for k in range(n):
        if k == 0:
            body, sender = random.choice(first_msgs).format(city=bcity), buyer
        elif k % 2 == 1:
            body = random.choice(seller_replies).format(p=int(l["price"] * 0.9))
            sender = l["user"]
        else:
            body = "Добре, поръчвам през OLX доставка." if (ends_with_order and k == n - 1) else random.choice(buyer_follow)
            sender = buyer
        t = t + timedelta(minutes=random.randint(2, 600))
        if t > NOW:
            t = NOW - timedelta(minutes=random.randint(1, 50))
        msg_id += 1
        is_read = not (k == n - 1 and (NOW - t).days < 2 and random.random() < 0.6)
        messages.append((msg_id, conv_id, sender, body, t, is_read))


listing_by_id = {l["id"]: l for l in listings}
for o in orders:
    l = listing_by_id[o["listing"]]
    start = rand_dt(l["created"], o["ordered"] - timedelta(minutes=30)) if o["ordered"] - l["created"] > timedelta(hours=1) else l["created"]
    if random.random() < 0.75:
        add_conversation(l, o["buyer"], start, True)

while conv_id < 320:
    l = random.choice(listings)
    buyer = random.choice(active_user_ids)
    if buyer == l["user"] or (l["id"], buyer) in conv_pairs:
        continue
    start = rand_dt(l["created"], min(l["expires"], NOW) - timedelta(hours=1))
    add_conversation(l, buyer, start, False)

# messages подредени по време в рамките на разговора - вече са

# ---------------------------------------------------------------- reviews
good_comments = ["Всичко беше точно, препоръчвам!", "Бърза доставка, продуктът е както е описан.",
                 "Коректен продавач.", "Супер комуникация, благодаря!", "Отлично състояние, точно като на снимките.",
                 None]
mid_comments = ["Добре е, но доставката се забави.", "Има малки драскотини, които не бяха споменати.",
                "Става, нищо особено.", None]
bad_comments = ["Продуктът не отговаря на описанието.", "Много бавно изпращане и никаква комуникация.",
                "Не препоръчвам.", "Пратиха ми друг размер."]
reviews = []
rv_id = 0
for o in orders:
    if o["status"] != "Delivered" or random.random() > 0.72:
        continue
    rating = random.choices([5, 4, 3, 2, 1], weights=[55, 25, 10, 5, 5])[0]
    comment = random.choice(good_comments if rating >= 4 else mid_comments if rating == 3 else bad_comments)
    created = o["delivered"] + timedelta(hours=random.randint(2, 96))
    if created > NOW:
        created = NOW - timedelta(minutes=30)
    rv_id += 1
    reviews.append((rv_id, o["id"], o["buyer"], o["seller"], rating, comment, created))

# ---------------------------------------------------------------- output
out.append("/*\n    Скрипт 6: тестови данни\n    ГЕНЕРИРАН от tools/generate_seed_data.py - не се редактира на ръка.\n*/")
out.append("USE OlxDB\nGO\n")

emit_insert("[Locations].[Cities]", ["CityId", "[Name]", "Region", "PostalCode"], city_rows)
emit_insert("[Orders].[Couriers]", ["CourierId", "[Name]", "BasePrice", "Website"], couriers)
emit_insert("[Promotions].[PromotionPackages]", ["PackageId", "Code", "[Name]", "DurationDays", "Price", "[Description]"], packages)
emit_insert("[Catalog].[Categories]", ["CategoryId", "ParentCategoryId", "[Name]", "Slug"], category_rows)
emit_insert("[Users].[Users]", ["UserId", "FirstName", "LastName", "Email", "Phone", "PasswordHash", "CityId",
                                "IsBusiness", "RegisteredOn", "[State]"], user_rows)
emit_insert("[Listings].[Listings]",
            ["ListingId", "UserId", "CategoryId", "CityId", "Title", "[Description]", "Price", "Currency",
             "ItemCondition", "IsNegotiable", "DeliveryAvailable", "[Status]", "ViewsCount", "CreatedOn", "ExpiresOn"],
            [(l["id"], l["user"], l["cat"], l["city"], l["title"], l["descr"], Money(l["price"]), Ascii("EUR"),
              Ascii(l["cond"]), l["neg"], l["delivery"], Ascii(l["status"]), l["views"], l["created"], l["expires"])
             for l in listings])
emit_insert("[Listings].[ListingImages]", ["ImageId", "ListingId", "ImageUrl", "SortOrder", "UploadedOn"], images)
emit_insert("[Listings].[ListingPriceHistory]", ["HistoryId", "ListingId", "OldPrice", "NewPrice", "ChangedOn"], price_hist)
emit_insert("[Listings].[Favorites]", ["UserId", "ListingId", "AddedOn"], fav_rows, identity=False)
emit_insert("[Promotions].[ListingPromotions]", ["PromotionId", "ListingId", "PackageId", "StartDate", "EndDate", "PaidAmount"], promos)
emit_insert("[Messaging].[Conversations]", ["ConversationId", "ListingId", "BuyerId", "StartedOn"], conversations)
emit_insert("[Messaging].[Messages]", ["MessageId", "ConversationId", "SenderId", "Body", "SentOn", "IsRead"], messages)
emit_insert("[Orders].[Orders]",
            ["OrderId", "ListingId", "BuyerId", "CourierId", "ItemPrice", "DeliveryFee", "PaymentMethod", "[Status]",
             "DeliveryAddress", "OrderedOn", "DeliveredOn"],
            [(o["id"], o["listing"], o["buyer"], o["courier"], Money(o["price"]), Money(o["fee"]), Ascii(o["pay"]),
              Ascii(o["status"]), o["addr"], o["ordered"], o["delivered"]) for o in orders])
emit_insert("[Orders].[Reviews]", ["ReviewId", "OrderId", "ReviewerId", "SellerId", "Rating", "Comment", "CreatedOn"], reviews)

out.append("-- бърза проверка на броя редове")
out.append("""SELECT 'Cities' AS [Table], COUNT(*) AS [Rows] FROM Locations.Cities
UNION ALL SELECT 'Users', COUNT(*) FROM Users.Users
UNION ALL SELECT 'Categories', COUNT(*) FROM [Catalog].Categories
UNION ALL SELECT 'Listings', COUNT(*) FROM Listings.Listings
UNION ALL SELECT 'ListingImages', COUNT(*) FROM Listings.ListingImages
UNION ALL SELECT 'ListingPriceHistory', COUNT(*) FROM Listings.ListingPriceHistory
UNION ALL SELECT 'Favorites', COUNT(*) FROM Listings.Favorites
UNION ALL SELECT 'PromotionPackages', COUNT(*) FROM Promotions.PromotionPackages
UNION ALL SELECT 'ListingPromotions', COUNT(*) FROM Promotions.ListingPromotions
UNION ALL SELECT 'Conversations', COUNT(*) FROM Messaging.Conversations
UNION ALL SELECT 'Messages', COUNT(*) FROM Messaging.Messages
UNION ALL SELECT 'Couriers', COUNT(*) FROM Orders.Couriers
UNION ALL SELECT 'Orders', COUNT(*) FROM Orders.Orders
UNION ALL SELECT 'Reviews', COUNT(*) FROM Orders.Reviews;
GO""")

OUT.write_text("\n".join(out) + "\n", encoding="utf-8-sig", newline="\r\n")
print(f"OK -> {OUT}")
print(f"users={len(users)} listings={len(listings)} orders={len(orders)} images={len(images)} "
      f"favorites={len(fav_rows)} promos={len(promos)} conversations={len(conversations)} "
      f"messages={len(messages)} reviews={len(reviews)} price_history={len(price_hist)}")
