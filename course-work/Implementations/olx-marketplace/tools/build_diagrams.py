"""
Генерира трите диаграми в папка diagrams/:
  - olx_conceptual_chen.drawio   (концептуален модел, Chen's notation)
  - olx_logical_crowsfoot.drawio (логически модел, Crow's Foot notation)
  - olx_datawarehouse_uml.drawio (физически модел на DW, UML database notation)
Файловете се отварят с draw.io (app.diagrams.net) и могат да се редактират ръчно.
"""
from pathlib import Path
from drawio import Diagram

OUT = Path(__file__).resolve().parent.parent / "diagrams"
OUT.mkdir(exist_ok=True)

# =====================================================================================
# 1) КОНЦЕПТУАЛЕН МОДЕЛ - CHEN
# =====================================================================================
ENT = "rounded=0;whiteSpace=wrap;html=1;fontStyle=1;fontSize=14;fillColor=#dae8fc;strokeColor=#6c8ebf;"
WEAK = "shape=ext;double=1;rounded=0;whiteSpace=wrap;html=1;fontStyle=1;fontSize=14;fillColor=#dae8fc;strokeColor=#6c8ebf;"
REL = "shape=rhombus;perimeter=rhombusPerimeter;whiteSpace=wrap;html=1;align=center;fontSize=12;fillColor=#fff2cc;strokeColor=#d6b656;"
IDREL = "shape=rhombus;double=1;perimeter=rhombusPerimeter;whiteSpace=wrap;html=1;align=center;fontSize=12;fillColor=#fff2cc;strokeColor=#d6b656;"
ATTR = "ellipse;whiteSpace=wrap;html=1;align=center;fontSize=12;fillColor=#ffffff;strokeColor=#666666;"
MULTI = "ellipse;shape=doubleEllipse;margin=3;whiteSpace=wrap;html=1;align=center;fontSize=12;fillColor=#ffffff;strokeColor=#666666;"
DERIVED = "ellipse;whiteSpace=wrap;html=1;align=center;fontSize=12;dashed=1;fillColor=#ffffff;strokeColor=#666666;"
LINE = "endArrow=none;html=1;rounded=0;strokeColor=#333333;"
TOTAL = "endArrow=none;html=1;rounded=0;shape=link;strokeColor=#333333;"   # пълно участие (двойна линия)
ALINE = "endArrow=none;html=1;rounded=0;strokeColor=#999999;"

c = Diagram("Conceptual model (Chen)")
E = {}


def ent(key, label, cx, cy, weak=False):
    E[key] = c.vertex(label, cx - 75, cy - 27, 150, 54, WEAK if weak else ENT)


def attr(owner, label, cx, cy, kind="simple", w=None):
    style = {"simple": ATTR, "key": ATTR, "multi": MULTI, "derived": DERIVED, "partial": ATTR}[kind]
    if kind == "key":
        label = f"<u>{label}</u>"
    if kind == "partial":
        label = f"<span style=\"text-decoration: underline dashed;\">{label}</span>"
    plain = label.replace("<u>", "").replace("</u>", "")
    if kind == "partial":
        plain = label.split(">")[1].split("<")[0]
    w = w or max(96, 8 * len(plain) + 26)
    a = c.vertex(label, cx - w / 2, cy - 21, w, 42, style)
    c.edge(owner, a, ALINE)
    return a


def rel(label, cx, cy, ends, identifying=False, w=130, h=72):
    """ends = [(entity_key, cardinality, total_participation)]"""
    r = c.vertex(label, cx - w / 2, cy - h / 2, w, h, IDREL if identifying else REL)
    for k, card, total in ends:
        e = c.edge(E[k], r, TOTAL if total else LINE)
        c.edge_label(e, card, -0.55, 0)
    return r


# обекти
ent("cat", "Category", 220, 190)
ent("pkg", "PromotionPackage", 1520, 190)
ent("city", "City", 220, 660)
ent("lst", "Listing", 880, 660)
ent("img", "ListingImage", 1520, 660, weak=True)
ent("ord", "Order", 220, 1180)
ent("usr", "User", 880, 1180)
ent("conv", "Conversation", 1520, 1180)
ent("msg", "Message", 2120, 1180, weak=True)
ent("cour", "Courier", 220, 1700)
ent("rev", "Review", 880, 1700)

# връзки
r_sub = c.vertex("has subcategory", 420 - 65, 40 - 36, 130, 72, REL)
e1 = c.edge(E["cat"], r_sub, LINE + "exitX=0.5;exitY=0;entryX=0;entryY=0.5;")
c.edge_label(e1, "1", -0.6, 0)
e2 = c.edge(E["cat"], r_sub, LINE + "exitX=1;exitY=0.25;entryX=0.5;entryY=1;")
c.edge_label(e2, "N", -0.4, 0)

rel("belongs to", 550, 425, [("lst", "N", True), ("cat", "1", False)])
r_promo = rel("promoted<br>with", 1200, 425, [("lst", "M", False), ("pkg", "N", False)])
rel("located in", 550, 660, [("lst", "N", True), ("city", "1", False)])
rel("has", 1200, 660, [("lst", "1", False), ("img", "N", True)], identifying=True)
rel("lives in", 418, 816, [("usr", "N", True), ("city", "1", False)])
rel("is for", 682, 816, [("ord", "N", True), ("lst", "1", False)])
rel("publishes", 790, 920, [("usr", "1", False), ("lst", "N", True)])
r_fav = rel("favorites", 980, 920, [("usr", "M", False), ("lst", "N", False)])
rel("is about", 1300, 920, [("conv", "N", True), ("lst", "1", False)])
rel("starts", 1200, 1180, [("usr", "1", False), ("conv", "N", True)])
rel("contains", 1820, 1180, [("conv", "1", False), ("msg", "N", True)], identifying=True)
rel("sends", 1820, 1400, [("usr", "1", False), ("msg", "N", True)])
rel("places", 550, 1180, [("usr", "1", False), ("ord", "N", True)])
rel("delivers", 220, 1440, [("cour", "1", False), ("ord", "N", True)])
rel("rates", 550, 1440, [("rev", "0..1", False), ("ord", "1", True)])
rel("writes", 790, 1440, [("usr", "1", False), ("rev", "N", True)])
rel("receives", 970, 1440, [("usr", "1", False), ("rev", "N", True)])

# атрибути
attr(E["cat"], "CategoryId", 70, 110, "key")
attr(E["cat"], "Name", 70, 270)
attr(E["cat"], "Slug", 220, 310)

attr(E["pkg"], "PackageId", 1400, 60, "key")
attr(E["pkg"], "Name", 1560, 50)
attr(E["pkg"], "DurationDays", 1720, 100)
attr(E["pkg"], "Price", 1720, 260)
attr(r_promo, "StartDate", 1040, 330)
attr(r_promo, "EndDate", 1200, 300)
attr(r_promo, "PaidAmount", 1350, 530)

attr(E["city"], "CityId", 70, 560, "key")
attr(E["city"], "Name", 60, 660)
attr(E["city"], "Region", 70, 760)
attr(E["city"], "PostalCode", 220, 790)

attr(E["lst"], "ListingId", 765, 500, "key")
attr(E["lst"], "Title", 850, 440)
attr(E["lst"], "PriceHistory", 965, 440, "multi")
attr(E["lst"], "Description", 990, 525)
attr(E["lst"], "Price", 1085, 595)
attr(E["lst"], "Condition", 690, 598)
attr(E["lst"], "Status", 700, 722)
attr(E["lst"], "CreatedOn", 1190, 760)

attr(E["img"], "SortOrder", 1690, 560, "partial")
attr(E["img"], "ImageUrl", 1720, 660)
attr(E["img"], "UploadedOn", 1690, 760)

attr(r_fav, "AddedOn", 1110, 860)

attr(E["usr"], "UserId", 690, 1115, "key")
u_name = attr(E["usr"], "FullName", 700, 1275)
fn = c.vertex("FirstName", 512, 1249, 96, 42, ATTR)
c.edge(u_name, fn, ALINE)
ln = c.vertex("LastName", 560, 1320, 96, 42, ATTR)
c.edge(u_name, ln, ALINE)
attr(E["usr"], "Phone", 1050, 1030)
attr(E["usr"], "Email", 1070, 1105)
attr(E["usr"], "IsBusiness", 1030, 1335)
attr(E["usr"], "Rating", 1150, 1290, "derived")

attr(E["conv"], "ConversationId", 1600, 1070, "key")
attr(E["conv"], "StartedOn", 1745, 1112)

attr(E["msg"], "MessageNo", 2040, 1040, "partial")
attr(E["msg"], "Body", 2230, 1060)
attr(E["msg"], "SentOn", 2280, 1180)
attr(E["msg"], "IsRead", 2200, 1300)

attr(E["ord"], "OrderId", 245, 1060, "key")
attr(E["ord"], "OrderedOn", 100, 1065)
attr(E["ord"], "DeliveryAddress", 120, 990)
attr(E["ord"], "ItemPrice", 30, 1150)
attr(E["ord"], "DeliveryFee", 30, 1222)
attr(E["ord"], "TotalAmount", 70, 1300, "derived")
attr(E["ord"], "PaymentMethod", 80, 1380)
attr(E["ord"], "Status", 290, 1335)

attr(E["cour"], "CourierId", 70, 1630, "key")
attr(E["cour"], "Name", 80, 1790)
attr(E["cour"], "BasePrice", 270, 1820)

attr(E["rev"], "ReviewId", 740, 1810, "key")
attr(E["rev"], "Rating", 890, 1835)
attr(E["rev"], "Comment", 1040, 1800)
attr(E["rev"], "CreatedOn", 1070, 1700)

# легенда
c.vertex("<b>Легенда (Chen)</b><br>правоъгълник - обект; двоен правоъгълник - слаб обект<br>ромб - връзка; двоен ромб - идентифицираща връзка<br>"
         "елипса - атрибут; <u>подчертан</u> - ключ; пунктир - производен; двойна елипса - многостойностен<br>"
         "двойна линия - пълно участие; 1 / N / M - кардиналност",
         1700, 1890, 560, 110,
         "text;html=1;align=left;verticalAlign=top;whiteSpace=wrap;fontSize=12;strokeColor=#999999;fillColor=#f5f5f5;spacing=8;")

c.save(OUT / "olx_conceptual_chen.drawio")


# =====================================================================================
# 2) ЛОГИЧЕСКИ МОДЕЛ - CROW'S FOOT
# =====================================================================================
TBL = ("swimlane;fontStyle=1;childLayout=stackLayout;horizontal=1;startSize=30;horizontalStack=0;resizeParent=1;"
       "resizeParentMax=0;resizeLast=0;collapsible=0;marginBottom=0;html=1;fontSize=13;rounded=1;arcSize=6;"
       "fillColor={fill};strokeColor={stroke};swimlaneFillColor=#ffffff;")
ROW = ("text;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;spacingLeft=8;spacingRight=4;"
       "overflow=hidden;rotatable=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;html=1;fontSize=12;fontFamily=Courier New;")
ER = "edgeStyle=entityRelationEdgeStyle;fontSize=12;html=1;endFill=0;startFill=0;rounded=0;strokeColor=#333333;strokeWidth=1.2;"

lg = Diagram("Logical model (Crow's Foot)")
T = {}
ROW_H = 22


def table(key, name, cols, x, y, w=320, fill="#dae8fc", stroke="#6c8ebf"):
    h = 30 + ROW_H * len(cols)
    t = lg.vertex(name, x, y, w, h, TBL.format(fill=fill, stroke=stroke))
    rows = {}
    for i, col in enumerate(cols):
        rid = lg.vertex(col.replace(" ", "&nbsp;"), 0, 30 + i * ROW_H, w, ROW_H, ROW, parent=t)
        rows[col.split()[1] if col.split()[0] in ("PK", "FK", "PK,FK") else col.split()[0]] = rid
    T[key] = rows
    return t


def rel_cf(a, acol, b, bcol, a_end, b_end, extra="", points=None):
    """връзката се закача за конкретния PK/FK ред.
    a_end / b_end: 'mandOne', 'one', 'zeroToOne', 'oneToMany', 'zeroToMany'"""
    style = ER + f"startArrow=ER{a_end};endArrow=ER{b_end};" + extra
    if points:  # връзка между таблици в една колона - заобикаля отвън
        style = style.replace("edgeStyle=entityRelationEdgeStyle;", "edgeStyle=orthogonalEdgeStyle;")
    lg.edge(T[a][acol], T[b][bcol], style, points=points)


C0, C1, C2, C3, C4 = 40, 430, 820, 1230, 1640
GRN, GRS = "#d5e8d4", "#82b366"
BLU, BLS = "#dae8fc", "#6c8ebf"
PUR, PUS = "#e1d5e7", "#9673a6"
ORA, ORS = "#ffe6cc", "#d79b00"
YEL, YES = "#fff2cc", "#d6b656"
RED, RES = "#f8cecc", "#b85450"
GRY, GYS = "#f5f5f5", "#666666"

table("cat", "Categories", ["PK  CategoryId        INT", "FK  ParentCategoryId  INT", "    Name              NVARCHAR(100)",
                            "    Slug              VARCHAR(100)"], C1, 40, fill=BLU, stroke=BLS)
table("city", "Cities", ["PK  CityId      INT", "    Name        NVARCHAR(100)", "    Region      NVARCHAR(100)",
                         "    PostalCode  VARCHAR(10)"], C1, 220, fill=BLU, stroke=BLS)
table("fav", "Favorites", ["PK,FK  UserId     INT", "PK,FK  ListingId  INT", "       AddedOn    DATETIME2"], C1, 410,
      fill=RED, stroke=RES)
table("ord", "Orders", ["PK  OrderId          INT", "FK  ListingId        INT", "FK  BuyerId          INT",
                        "FK  CourierId        INT", "    ItemPrice        DECIMAL(10,2)", "    DeliveryFee      DECIMAL(10,2)",
                        "    /TotalAmount     DECIMAL(10,2)", "    PaymentMethod    VARCHAR(20)", "    Status           VARCHAR(12)",
                        "    DeliveryAddress  NVARCHAR(250)", "    OrderedOn        DATETIME2", "    DeliveredOn      DATETIME2"],
      C1, 580, fill=GRY, stroke=GYS)
table("rev", "Reviews", ["PK  ReviewId    INT", "FK  OrderId     INT", "FK  ReviewerId  INT", "FK  SellerId    INT",
                         "    Rating      TINYINT", "    Comment     NVARCHAR(1000)", "    CreatedOn   DATETIME2"],
      C1, 950, fill=GRY, stroke=GYS)
table("cour", "Couriers", ["PK  CourierId  INT", "    Name       NVARCHAR(50)", "    BasePrice  DECIMAL(10,2)",
                           "    Website    VARCHAR(100)"], C0, 640, fill=GRY, stroke=GYS)

table("lst", "Listings", ["PK  ListingId          INT", "FK  UserId             INT", "FK  CategoryId         INT",
                          "FK  CityId             INT", "    Title              NVARCHAR(150)", "    Description        NVARCHAR(2000)",
                          "    Price              DECIMAL(10,2)", "    Currency           CHAR(3)", "    ItemCondition      VARCHAR(10)",
                          "    IsNegotiable       BIT", "    DeliveryAvailable  BIT", "    Status             VARCHAR(10)",
                          "    ViewsCount         INT", "    CreatedOn          DATETIME2", "    ExpiresOn          DATETIME2",
                          "    UpdatedOn          DATETIME2"], C2, 40, fill=GRN, stroke=GRS)
table("usr", "Users", ["PK  UserId        INT", "    FirstName     NVARCHAR(50)", "    LastName      NVARCHAR(50)",
                       "    Email         NVARCHAR(150)", "    Phone         VARCHAR(20)", "    PasswordHash  CHAR(64)",
                       "FK  CityId        INT", "    IsBusiness    BIT", "    AvgRating     DECIMAL(3,2)",
                       "    RegisteredOn  DATETIME2", "    State         TINYINT"], C2, 560, fill=GRN, stroke=GRS)

table("img", "ListingImages", ["PK  ImageId     INT", "FK  ListingId   INT", "    ImageUrl    NVARCHAR(400)",
                               "    SortOrder   TINYINT", "    UploadedOn  DATETIME2"], C3, 40, fill=PUR, stroke=PUS)
table("hist", "ListingPriceHistory", ["PK  HistoryId  INT", "FK  ListingId  INT", "    OldPrice   DECIMAL(10,2)",
                                      "    NewPrice   DECIMAL(10,2)", "    ChangedOn  DATETIME2"], C3, 230, fill=PUR, stroke=PUS)
table("promo", "ListingPromotions", ["PK  PromotionId  INT", "FK  ListingId    INT", "FK  PackageId    INT",
                                     "    StartDate    DATETIME2", "    EndDate      DATETIME2", "    PaidAmount   DECIMAL(10,2)"],
      C3, 420, fill=ORA, stroke=ORS)
table("conv", "Conversations", ["PK  ConversationId  INT", "FK  ListingId       INT", "FK  BuyerId         INT",
                                "    StartedOn       DATETIME2"], C3, 640, fill=YEL, stroke=YES)
table("msg", "Messages", ["PK  MessageId       INT", "FK  ConversationId  INT", "FK  SenderId        INT",
                          "    Body            NVARCHAR(2000)", "    SentOn          DATETIME2", "    IsRead          BIT"],
      C3, 820, fill=YEL, stroke=YES)
table("pkg", "PromotionPackages", ["PK  PackageId     INT", "    Code          VARCHAR(10)", "    Name          NVARCHAR(50)",
                                   "    DurationDays  SMALLINT", "    Price         DECIMAL(10,2)", "    Description   NVARCHAR(300)"],
      C4, 420, fill=ORA, stroke=ORS)

rel_cf("cat", "CategoryId", "cat", "ParentCategoryId", "zeroToOne", "zeroToMany", "exitX=0;exitY=0.5;entryX=0;entryY=0.5;",
       points=[(C1 - 30, 81), (C1 - 30, 103)])
rel_cf("cat", "CategoryId", "lst", "CategoryId", "mandOne", "zeroToMany")
rel_cf("city", "CityId", "lst", "CityId", "mandOne", "zeroToMany")
rel_cf("city", "CityId", "usr", "CityId", "mandOne", "zeroToMany")
rel_cf("usr", "UserId", "lst", "UserId", "mandOne", "zeroToMany", "exitX=1;exitY=0.5;entryX=1;entryY=0.5;",
       points=[(C2 + 320 + 18, 601), (C2 + 320 + 18, 103)])
rel_cf("lst", "ListingId", "img", "ListingId", "mandOne", "zeroToMany")
rel_cf("lst", "ListingId", "hist", "ListingId", "mandOne", "zeroToMany")
rel_cf("lst", "ListingId", "promo", "ListingId", "mandOne", "zeroToMany")
rel_cf("pkg", "PackageId", "promo", "PackageId", "mandOne", "zeroToMany")
rel_cf("usr", "UserId", "fav", "UserId", "mandOne", "zeroToMany")
rel_cf("lst", "ListingId", "fav", "ListingId", "mandOne", "zeroToMany")
rel_cf("lst", "ListingId", "conv", "ListingId", "mandOne", "zeroToMany")
rel_cf("usr", "UserId", "conv", "BuyerId", "mandOne", "zeroToMany")
rel_cf("conv", "ConversationId", "msg", "ConversationId", "mandOne", "oneToMany", "exitX=1;exitY=0.5;entryX=1;entryY=0.5;",
       points=[(C3 + 320 + 30, 681), (C3 + 320 + 30, 883)])
rel_cf("usr", "UserId", "msg", "SenderId", "mandOne", "zeroToMany")
rel_cf("lst", "ListingId", "ord", "ListingId", "mandOne", "zeroToOne")
rel_cf("usr", "UserId", "ord", "BuyerId", "mandOne", "zeroToMany")
rel_cf("cour", "CourierId", "ord", "CourierId", "mandOne", "zeroToMany")
rel_cf("ord", "OrderId", "rev", "OrderId", "mandOne", "zeroToOne", "exitX=0;exitY=0.5;entryX=0;entryY=0.5;",
       points=[(C1 - 22, 621), (C1 - 22, 1013)])
rel_cf("usr", "UserId", "rev", "ReviewerId", "mandOne", "zeroToMany")
rel_cf("usr", "UserId", "rev", "SellerId", "mandOne", "zeroToMany")

lg.vertex("<b>Връзки много към много</b><br>Users &gt;-&lt; Listings чрез <b>Favorites</b><br>"
          "Listings &gt;-&lt; PromotionPackages чрез <b>ListingPromotions</b><br><br>"
          "14 таблици, 93 атрибута<br>/TotalAmount - изчислима колона",
          C3, 1020, 380, 120,
          "text;html=1;align=left;verticalAlign=top;whiteSpace=wrap;fontSize=12;strokeColor=#999999;fillColor=#f5f5f5;spacing=8;")

lg.save(OUT / "olx_logical_crowsfoot.drawio")


# =====================================================================================
# 3) DATA WAREHOUSE - UML DATABASE NOTATION
# =====================================================================================
UML = ("swimlane;fontStyle=1;childLayout=stackLayout;horizontal=1;startSize=44;horizontalStack=0;resizeParent=1;"
       "resizeParentMax=0;resizeLast=0;collapsible=0;marginBottom=0;html=1;fontSize=13;"
       "fillColor={fill};strokeColor={stroke};swimlaneFillColor=#ffffff;")
UROW = ("text;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;spacingLeft=6;spacingRight=4;"
        "overflow=hidden;rotatable=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;html=1;fontSize=11;")
ASSOC = "endArrow=none;html=1;rounded=0;strokeColor=#555555;edgeStyle=orthogonalEdgeStyle;"

dw = Diagram("Data Warehouse (UML)")
D = {}
UROW_H = 20
UER = "edgeStyle=entityRelationEdgeStyle;endArrow=none;startArrow=none;html=1;rounded=0;strokeColor=#555555;"


def uml(key, stereotype, name, cols, x, y, w=330, fact=False):
    fill, stroke = ("#f8cecc", "#b85450") if fact else ("#dae8fc", "#6c8ebf")
    h = 44 + UROW_H * len(cols)
    t = dw.vertex(f"&lt;&lt;{stereotype}&gt;&gt;<br>{name}", x, y, w, h, UML.format(fill=fill, stroke=stroke))
    rows = {}
    for i, col in enumerate(cols):
        rows[col.split(":")[0]] = dw.vertex(col, 0, 44 + i * UROW_H, w, UROW_H, UROW, parent=t)
    D[key] = rows


PKS = "&lt;&lt;PK&gt;&gt; &lt;&lt;Surrogate&gt;&gt;"
FK = "&lt;&lt;FK&gt;&gt;"
AK = "&lt;&lt;AK&gt;&gt;"

XL, XC, XR, XFR = 40, 560, 1060, 1580   # факти вляво | измерения в средата | факти вдясно | пакети

# ---- измерения (централна колона - споделени от всички факти)
uml("date", "Dimension", "DimDate", [
    "DateKey: INT &lt;&lt;PK&gt;&gt;", "FullDate: DATE", "Day: TINYINT", "Month: TINYINT", "MonthName: NVARCHAR(20)",
    "Quarter: TINYINT", "Year: SMALLINT", "YearMonth: CHAR(7)", "DayOfWeek: TINYINT", "DayName: NVARCHAR(20)",
    "IsWeekend: BIT"], XC, 40, w=320)
uml("user", "Dimension", "DimUser", [
    f"UserKey: INT {PKS}", f"UserId: INT {AK}", "FullName: NVARCHAR(110)", "UserType: NVARCHAR(20)",
    "City: NVARCHAR(100)", "Region: NVARCHAR(100)", "RegisteredYear: SMALLINT", "AvgRating: DECIMAL(3,2)",
    "IsActive: BIT"], XC, 350, w=320)
uml("cat", "Dimension", "DimCategory", [
    f"CategoryKey: INT {PKS}", f"CategoryId: INT {AK}", "CategoryName: NVARCHAR(100)",
    "ParentCategoryName: NVARCHAR(100)", "CategoryPath: NVARCHAR(400)"], XC, 620, w=320)
uml("loc", "Dimension", "DimLocation", [
    f"LocationKey: INT {PKS}", f"CityId: INT {AK}", "City: NVARCHAR(100)", "Region: NVARCHAR(100)",
    "PostalCode: VARCHAR(10)", "Country: NVARCHAR(50)"], XC, 810, w=320)
uml("listing", "Dimension", "DimListing", [
    f"ListingKey: INT {PKS}", f"ListingId: INT {AK}", "Title: NVARCHAR(150)", "ItemCondition: NVARCHAR(20)",
    "IsNegotiable: BIT", "DeliveryAvailable: BIT", "CurrentStatus: VARCHAR(10)", "PriceBand: NVARCHAR(20)"],
    XC, 1020, w=320)
uml("courier", "Dimension", "DimCourier", [
    f"CourierKey: INT {PKS}", f"CourierId: INT {AK}", "CourierName: NVARCHAR(50)", "BasePrice: DECIMAL(10,2)"],
    XC, 1270, w=320)
uml("pkg", "Dimension", "DimPromotionPackage", [
    f"PackageKey: INT {PKS}", f"PackageId: INT {AK}", "PackageCode: VARCHAR(10)", "PackageName: NVARCHAR(50)",
    "DurationDays: SMALLINT", "ListPrice: DECIMAL(10,2)"], XFR, 300, w=320)

# ---- факти
uml("sales", "Fact", "FactSales", [
    f"SalesKey: INT {PKS}", "OrderId: INT", f"OrderDateKey: INT {FK}", f"DeliveredDateKey: INT {FK} &lt;&lt;Null&gt;&gt;",
    f"ListingKey: INT {FK}", f"SellerKey: INT {FK}", f"BuyerKey: INT {FK}", f"CategoryKey: INT {FK}",
    f"LocationKey: INT {FK}", f"CourierKey: INT {FK}", "PaymentMethod: VARCHAR(20)", "OrderStatus: VARCHAR(12)",
    "ItemPrice: DECIMAL(10,2)", "DeliveryFee: DECIMAL(10,2)", "TotalAmount: DECIMAL(10,2)", "DeliveryDays: INT",
    "IsCompleted: INT"], XL, 100, w=360, fact=True)
uml("listings", "Fact", "FactListings", [
    f"ListingFactKey: INT {PKS}", f"ListingKey: INT {FK}", f"CreatedDateKey: INT {FK}", f"SellerKey: INT {FK}",
    f"CategoryKey: INT {FK}", f"LocationKey: INT {FK}", "Price: DECIMAL(10,2)", "InitialPrice: DECIMAL(10,2)",
    "ViewsCount: INT", "FavoritesCount: INT", "ImagesCount: INT", "ConversationsCount: INT", "MessagesCount: INT",
    "PriceChangesCount: INT", "PromotionsCount: INT", "IsSold: INT", "ListingCount: INT"], XL, 620, w=360, fact=True)
uml("promo", "Fact", "FactPromotions", [
    f"PromotionFactKey: INT {PKS}", "PromotionId: INT", f"StartDateKey: INT {FK}", f"ListingKey: INT {FK}",
    f"SellerKey: INT {FK}", f"CategoryKey: INT {FK}", f"LocationKey: INT {FK}", f"PackageKey: INT {FK}",
    "PaidAmount: DECIMAL(10,2)", "DurationDays: SMALLINT", "LedToSale: INT"], XR, 160, w=360, fact=True)
uml("reviews", "Fact", "FactReviews", [
    f"ReviewFactKey: INT {PKS}", "ReviewId: INT", f"ReviewDateKey: INT {FK}", f"SellerKey: INT {FK}",
    f"BuyerKey: INT {FK}", f"CategoryKey: INT {FK}", f"CourierKey: INT {FK}", "Rating: TINYINT",
    "IsPositive: INT", "HasComment: INT"], XR, 760, w=360, fact=True)


def assoc(fact, fcol, dim, dcol):
    e = dw.edge(D[fact][fcol], D[dim][dcol], UER)
    dw.edge_label(e, "0..*", -0.8, -9)
    dw.edge_label(e, "1", 0.85, -9)


assoc("sales", "OrderDateKey", "date", "DateKey")
assoc("sales", "DeliveredDateKey", "date", "DateKey")
assoc("sales", "ListingKey", "listing", "ListingKey")
assoc("sales", "SellerKey", "user", "UserKey")
assoc("sales", "BuyerKey", "user", "UserKey")
assoc("sales", "CategoryKey", "cat", "CategoryKey")
assoc("sales", "LocationKey", "loc", "LocationKey")
assoc("sales", "CourierKey", "courier", "CourierKey")

assoc("listings", "CreatedDateKey", "date", "DateKey")
assoc("listings", "ListingKey", "listing", "ListingKey")
assoc("listings", "SellerKey", "user", "UserKey")
assoc("listings", "CategoryKey", "cat", "CategoryKey")
assoc("listings", "LocationKey", "loc", "LocationKey")

assoc("promo", "StartDateKey", "date", "DateKey")
assoc("promo", "ListingKey", "listing", "ListingKey")
assoc("promo", "SellerKey", "user", "UserKey")
assoc("promo", "CategoryKey", "cat", "CategoryKey")
assoc("promo", "LocationKey", "loc", "LocationKey")
assoc("promo", "PackageKey", "pkg", "PackageKey")

assoc("reviews", "ReviewDateKey", "date", "DateKey")
assoc("reviews", "SellerKey", "user", "UserKey")
assoc("reviews", "BuyerKey", "user", "UserKey")
assoc("reviews", "CategoryKey", "cat", "CategoryKey")
assoc("reviews", "CourierKey", "courier", "CourierKey")

dw.vertex("<b>Fact constellation (galaxy schema)</b><br>4 таблици факти (червени) споделят 7 таблици измерения (сини).<br>"
          "DimUser е role-playing измерение - свързва се и като продавач (SellerKey), и като купувач (BuyerKey).<br>"
          "DimDate се ползва за дата на поръчка, доставка, публикуване, промоция и оценка.<br>"
          "OrderId / PromotionId / ReviewId - degenerate dimension.",
          XL, 1100, 420, 150,
          "text;html=1;align=left;verticalAlign=top;whiteSpace=wrap;fontSize=12;strokeColor=#999999;fillColor=#f5f5f5;spacing=8;")

dw.save(OUT / "olx_datawarehouse_uml.drawio")
print("diagrams ->", OUT)
