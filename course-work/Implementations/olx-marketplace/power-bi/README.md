# Power BI отчет - OLX Анализ

Отчетът се прави в **Power BI Desktop** (безплатен, само за Windows) върху базата **OlxDW**.
Готовият файл се записва като `power-bi/OLX_Report.pbix`.

## 1. Свързване към данните

1. `Home` → `Get data` → `SQL Server`
2. Server: `localhost` (или `.\SQLEXPRESS`), Database: `OlxDW`, режим **Import**
3. Избират се таблиците:
   - `FactSales`, `FactListings`, `FactPromotions`, `FactReviews`
   - `DimDate`, `DimCategory`, `DimLocation`, `DimListing`, `DimCourier`, `DimPromotionPackage`
   - изгледите `VW_DimSeller` и `VW_DimBuyer` (вместо `DimUser` - така едно и също измерение се ползва и като продавач, и като купувач)
4. `Load`

## 2. Модел (Model view)

Power BI сам открива част от връзките. Проверете да изглеждат така (всички са **1 : много**, посока на филтъра **Single**):

| Измерение | Колона | Факт таблица | Колона |
|---|---|---|---|
| DimDate | DateKey | FactSales | OrderDateKey |
| DimDate | DateKey | FactSales | DeliveredDateKey (**неактивна**) |
| DimDate | DateKey | FactListings | CreatedDateKey |
| DimDate | DateKey | FactPromotions | StartDateKey |
| DimDate | DateKey | FactReviews | ReviewDateKey |
| VW_DimSeller | SellerKey | FactSales, FactListings, FactPromotions, FactReviews | SellerKey |
| VW_DimBuyer | BuyerKey | FactSales, FactReviews | BuyerKey |
| DimCategory | CategoryKey | всичките 4 факта | CategoryKey |
| DimLocation | LocationKey | FactSales, FactListings, FactPromotions | LocationKey |
| DimListing | ListingKey | FactSales, FactListings, FactPromotions | ListingKey |
| DimCourier | CourierKey | FactSales, FactReviews | CourierKey |
| DimPromotionPackage | PackageKey | FactPromotions | PackageKey |

След това:
- `DimDate` → десен бутон → **Mark as date table** → колона `FullDate`
- `DimDate[MonthName]` → *Sort by column* → `Month`
- `DimDate[DayName]` → *Sort by column* → `DayOfWeek`
- скриват се ключовите колони (`...Key`), за да не се объркват в списъка с полета

## 3. Мерки

Всички мерки са във файла [`measures.dax`](measures.dax). Създават се с `Home` → `New measure`.

## 4. Визуализации

**Страница 1 - Продажби**

| # | Визуализация | Полета |
|---|---|---|
| 1 | Card (×4) | `Оборот`, `Доставени поръчки`, `Среден чек`, `Среден рейтинг` |
| 2 | Line chart | X: `DimDate[YearMonth]`, Y: `Оборот`, `Брой поръчки` (на вторична ос) |
| 3 | Clustered bar chart | Y: `DimCategory[ParentCategoryName]`, X: `Оборот` (drill down към `CategoryName`) |
| 4 | Donut chart | Legend: `DimCourier[CourierName]`, Values: `Брой поръчки` |
| 5 | Stacked column chart | X: `FactSales[PaymentMethod]`, Y: `Брой поръчки`, Legend: `FactSales[OrderStatus]` |
| 6 | Slicer-и | `DimDate[Year]`, `DimLocation[Region]`, `VW_DimSeller[SellerType]` |

**Страница 2 - Обяви и промоции**

| # | Визуализация | Полета |
|---|---|---|
| 7 | Filled map / Bar chart | `DimLocation[Region]` (Data category: *State or Province*), `Брой обяви` |
| 8 | Table | `VW_DimSeller[Seller]`, `Брой обяви`, `Продадени обяви`, `Оборот`, `VW_DimSeller[SellerRating]` - Top N 10 по `Оборот` |
| 9 | Clustered column chart | X: `DimPromotionPackage[PackageName]`, Y: `Приходи от промоции`, `% промоции довели до продажба` (line and column chart) |
| 10 | Scatter chart | X: `Средно прегледи на обява`, Y: `% продадени`, Details: `DimCategory[CategoryName]` |
| 11 | Matrix | Rows: `DimListing[PriceBand]`, Columns: `DimListing[ItemCondition]`, Values: `Брой обяви` |

По условие са нужни минимум 4 визуализации - тук са 11, разпределени на 2 страници.

## 5. Обновяване на данните

При промяна в `OlxDB`:
```sql
USE OlxDW;
EXEC dbo.USP_LoadWarehouse;
```
и след това `Refresh` в Power BI.
