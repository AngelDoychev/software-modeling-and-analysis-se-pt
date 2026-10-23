/*
    ETL: зареждане на OlxDW от OlxDB (двете бази са на един и същ сървър).
    Процедурата изтрива всичко и зарежда наново (full reload) - за обема на проекта е напълно достатъчно.
    Пускане:  EXEC dbo.USP_LoadWarehouse;
*/
USE OlxDW
GO

CREATE OR ALTER PROCEDURE dbo.USP_LoadWarehouse
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    ------------ изчистване (първо фактите, после измеренията) ------------
    -- фактите не се реферират от други таблици, затова TRUNCATE (нулира и IDENTITY)
    TRUNCATE TABLE dbo.FactReviews;
    TRUNCATE TABLE dbo.FactPromotions;
    TRUNCATE TABLE dbo.FactListings;
    TRUNCATE TABLE dbo.FactSales;

    -- измеренията имат FK към тях -> DELETE + RESEED
    DELETE FROM dbo.DimPromotionPackage;
    DELETE FROM dbo.DimCourier;
    DELETE FROM dbo.DimListing;
    DELETE FROM dbo.DimLocation;
    DELETE FROM dbo.DimCategory;
    DELETE FROM dbo.DimUser;
    DELETE FROM dbo.DimDate;

    -- RESEED само ако в таблицата вече е имало редове (иначе първият ключ става 0)
    DECLARE @tbl SYSNAME;
    DECLARE dims CURSOR LOCAL FAST_FORWARD FOR
        SELECT 'dbo.' + t.[name]
        FROM sys.identity_columns ic
            INNER JOIN sys.tables t ON t.object_id = ic.object_id
        WHERE t.[name] LIKE 'Dim%' AND ic.last_value IS NOT NULL;
    OPEN dims;
    FETCH NEXT FROM dims INTO @tbl;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC (N'DBCC CHECKIDENT (''' + @tbl + N''', RESEED, 0) WITH NO_INFOMSGS;');
        FETCH NEXT FROM dims INTO @tbl;
    END
    CLOSE dims;
    DEALLOCATE dims;

    ------------ DimDate: 2024-01-01 .. 2027-12-31 ------------
    WITH Dates AS
    (
        SELECT CAST('2024-01-01' AS DATE) AS d
        UNION ALL
        SELECT DATEADD(DAY, 1, d) FROM Dates WHERE d < '2027-12-31'
    )
    INSERT INTO dbo.DimDate
        (DateKey, FullDate, [Day], [Month], [MonthName], [Quarter], [Year], YearMonth, DayOfWeek, [DayName], IsWeekend)
    SELECT
        YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d),
        d,
        DAY(d),
        MONTH(d),
        CHOOSE(MONTH(d), N'Януари', N'Февруари', N'Март', N'Април', N'Май', N'Юни',
                         N'Юли', N'Август', N'Септември', N'Октомври', N'Ноември', N'Декември'),
        DATEPART(QUARTER, d),
        YEAR(d),
        CONVERT(CHAR(7), d, 126),
        x.dow,
        CHOOSE(x.dow, N'Понеделник', N'Вторник', N'Сряда', N'Четвъртък', N'Петък', N'Събота', N'Неделя'),
        CASE WHEN x.dow IN (6, 7) THEN 1 ELSE 0 END
    FROM Dates
        CROSS APPLY (SELECT DATEDIFF(DAY, '19000101', d) % 7 + 1 AS dow) AS x -- 01.01.1900 е понеделник
    OPTION (MAXRECURSION 0);

    ------------ DimLocation ------------
    INSERT INTO dbo.DimLocation (CityId, City, Region, PostalCode)
    SELECT CityId, [Name], Region, PostalCode
    FROM OlxDB.Locations.Cities;

    ------------ DimUser ------------
    INSERT INTO dbo.DimUser (UserId, FullName, UserType, City, Region, RegisteredYear, AvgRating, IsActive)
    SELECT u.UserId,
           u.FirstName + N' ' + u.LastName,
           CASE WHEN u.IsBusiness = 1 THEN N'Бизнес' ELSE N'Частно лице' END,
           c.[Name],
           c.Region,
           YEAR(u.RegisteredOn),
           u.AvgRating,
           CASE WHEN u.[State] = 1 THEN 1 ELSE 0 END
    FROM OlxDB.Users.Users AS u
        INNER JOIN OlxDB.Locations.Cities AS c ON c.CityId = u.CityId;

    ------------ DimCategory (само крайните подкатегории - само в тях има обяви) ------------
    INSERT INTO dbo.DimCategory (CategoryId, CategoryName, ParentCategoryName, CategoryPath)
    SELECT c.CategoryId,
           c.[Name],
           ISNULL(p.[Name], c.[Name]),
           OlxDB.[Catalog].F_GetCategoryPath(c.CategoryId)
    FROM OlxDB.[Catalog].Categories AS c
        LEFT JOIN OlxDB.[Catalog].Categories AS p ON p.CategoryId = c.ParentCategoryId
    WHERE NOT EXISTS (SELECT 1 FROM OlxDB.[Catalog].Categories ch WHERE ch.ParentCategoryId = c.CategoryId);

    ------------ DimListing ------------
    INSERT INTO dbo.DimListing (ListingId, Title, ItemCondition, IsNegotiable, DeliveryAvailable, CurrentStatus, PriceBand)
    SELECT l.ListingId,
           l.Title,
           CASE l.ItemCondition WHEN 'New' THEN N'Ново' ELSE N'Използвано' END,
           l.IsNegotiable,
           l.DeliveryAvailable,
           l.[Status],
           CASE
               WHEN l.Price < 20 THEN N'до 20 €'
               WHEN l.Price < 100 THEN N'20 - 100 €'
               WHEN l.Price < 500 THEN N'100 - 500 €'
               WHEN l.Price < 2000 THEN N'500 - 2000 €'
               ELSE N'над 2000 €'
           END
    FROM OlxDB.Listings.Listings AS l;

    ------------ DimCourier ------------
    INSERT INTO dbo.DimCourier (CourierId, CourierName, BasePrice)
    SELECT CourierId, [Name], BasePrice
    FROM OlxDB.Orders.Couriers;

    ------------ DimPromotionPackage ------------
    INSERT INTO dbo.DimPromotionPackage (PackageId, PackageCode, PackageName, DurationDays, ListPrice)
    SELECT PackageId, Code, [Name], DurationDays, Price
    FROM OlxDB.Promotions.PromotionPackages;

    ------------ FactSales ------------
    INSERT INTO dbo.FactSales
        (OrderId, OrderDateKey, DeliveredDateKey, ListingKey, SellerKey, BuyerKey, CategoryKey, LocationKey, CourierKey,
         PaymentMethod, OrderStatus, ItemPrice, DeliveryFee, TotalAmount, DeliveryDays, IsCompleted)
    SELECT o.OrderId,
           YEAR(o.OrderedOn) * 10000 + MONTH(o.OrderedOn) * 100 + DAY(o.OrderedOn),
           CASE WHEN o.DeliveredOn IS NULL THEN NULL
                ELSE YEAR(o.DeliveredOn) * 10000 + MONTH(o.DeliveredOn) * 100 + DAY(o.DeliveredOn) END,
           dl.ListingKey,
           ds.UserKey,
           db.UserKey,
           dc.CategoryKey,
           dloc.LocationKey,
           dcr.CourierKey,
           o.PaymentMethod,
           o.[Status],
           o.ItemPrice,
           o.DeliveryFee,
           o.TotalAmount,
           DATEDIFF(DAY, o.OrderedOn, o.DeliveredOn),
           CASE WHEN o.[Status] = 'Delivered' THEN 1 ELSE 0 END
    FROM OlxDB.Orders.Orders AS o
        INNER JOIN OlxDB.Listings.Listings AS l ON l.ListingId = o.ListingId
        INNER JOIN dbo.DimListing AS dl ON dl.ListingId = l.ListingId
        INNER JOIN dbo.DimUser AS ds ON ds.UserId = l.UserId
        INNER JOIN dbo.DimUser AS db ON db.UserId = o.BuyerId
        INNER JOIN dbo.DimCategory AS dc ON dc.CategoryId = l.CategoryId
        INNER JOIN dbo.DimLocation AS dloc ON dloc.CityId = l.CityId
        INNER JOIN dbo.DimCourier AS dcr ON dcr.CourierId = o.CourierId;

    ------------ FactListings ------------
    INSERT INTO dbo.FactListings
        (ListingKey, CreatedDateKey, SellerKey, CategoryKey, LocationKey, Price, InitialPrice, ViewsCount,
         FavoritesCount, ImagesCount, ConversationsCount, MessagesCount, PriceChangesCount, PromotionsCount, IsSold)
    SELECT dl.ListingKey,
           YEAR(l.CreatedOn) * 10000 + MONTH(l.CreatedOn) * 100 + DAY(l.CreatedOn),
           ds.UserKey,
           dc.CategoryKey,
           dloc.LocationKey,
           l.Price,
           ISNULL((SELECT TOP 1 h.OldPrice FROM OlxDB.Listings.ListingPriceHistory h
                   WHERE h.ListingId = l.ListingId ORDER BY h.ChangedOn), l.Price),
           l.ViewsCount,
           (SELECT COUNT(*) FROM OlxDB.Listings.Favorites f WHERE f.ListingId = l.ListingId),
           (SELECT COUNT(*) FROM OlxDB.Listings.ListingImages i WHERE i.ListingId = l.ListingId),
           (SELECT COUNT(*) FROM OlxDB.Messaging.Conversations c WHERE c.ListingId = l.ListingId),
           (SELECT COUNT(*) FROM OlxDB.Messaging.Messages m
                INNER JOIN OlxDB.Messaging.Conversations c ON c.ConversationId = m.ConversationId
            WHERE c.ListingId = l.ListingId),
           (SELECT COUNT(*) FROM OlxDB.Listings.ListingPriceHistory h WHERE h.ListingId = l.ListingId),
           (SELECT COUNT(*) FROM OlxDB.Promotions.ListingPromotions p WHERE p.ListingId = l.ListingId),
           CASE WHEN l.[Status] = 'Sold' THEN 1 ELSE 0 END
    FROM OlxDB.Listings.Listings AS l
        INNER JOIN dbo.DimListing AS dl ON dl.ListingId = l.ListingId
        INNER JOIN dbo.DimUser AS ds ON ds.UserId = l.UserId
        INNER JOIN dbo.DimCategory AS dc ON dc.CategoryId = l.CategoryId
        INNER JOIN dbo.DimLocation AS dloc ON dloc.CityId = l.CityId;

    ------------ FactPromotions ------------
    INSERT INTO dbo.FactPromotions
        (PromotionId, StartDateKey, ListingKey, SellerKey, CategoryKey, LocationKey, PackageKey, PaidAmount, DurationDays, LedToSale)
    SELECT p.PromotionId,
           YEAR(p.StartDate) * 10000 + MONTH(p.StartDate) * 100 + DAY(p.StartDate),
           dl.ListingKey,
           ds.UserKey,
           dc.CategoryKey,
           dloc.LocationKey,
           dp.PackageKey,
           p.PaidAmount,
           dp.DurationDays,
           CASE WHEN EXISTS (SELECT 1 FROM OlxDB.Orders.Orders o
                             WHERE o.ListingId = p.ListingId
                               AND o.OrderedOn >= p.StartDate
                               AND o.[Status] NOT IN ('Cancelled', 'Returned'))
                THEN 1 ELSE 0 END
    FROM OlxDB.Promotions.ListingPromotions AS p
        INNER JOIN OlxDB.Listings.Listings AS l ON l.ListingId = p.ListingId
        INNER JOIN dbo.DimListing AS dl ON dl.ListingId = l.ListingId
        INNER JOIN dbo.DimUser AS ds ON ds.UserId = l.UserId
        INNER JOIN dbo.DimCategory AS dc ON dc.CategoryId = l.CategoryId
        INNER JOIN dbo.DimLocation AS dloc ON dloc.CityId = l.CityId
        INNER JOIN dbo.DimPromotionPackage AS dp ON dp.PackageId = p.PackageId;

    ------------ FactReviews ------------
    INSERT INTO dbo.FactReviews
        (ReviewId, ReviewDateKey, SellerKey, BuyerKey, CategoryKey, CourierKey, Rating, IsPositive, HasComment)
    SELECT r.ReviewId,
           YEAR(r.CreatedOn) * 10000 + MONTH(r.CreatedOn) * 100 + DAY(r.CreatedOn),
           ds.UserKey,
           db.UserKey,
           dc.CategoryKey,
           dcr.CourierKey,
           r.Rating,
           CASE WHEN r.Rating >= 4 THEN 1 ELSE 0 END,
           CASE WHEN r.Comment IS NULL THEN 0 ELSE 1 END
    FROM OlxDB.Orders.Reviews AS r
        INNER JOIN OlxDB.Orders.Orders AS o ON o.OrderId = r.OrderId
        INNER JOIN OlxDB.Listings.Listings AS l ON l.ListingId = o.ListingId
        INNER JOIN dbo.DimUser AS ds ON ds.UserId = r.SellerId
        INNER JOIN dbo.DimUser AS db ON db.UserId = r.ReviewerId
        INNER JOIN dbo.DimCategory AS dc ON dc.CategoryId = l.CategoryId
        INNER JOIN dbo.DimCourier AS dcr ON dcr.CourierId = o.CourierId;

    COMMIT TRANSACTION;

    SELECT 'DimDate' AS [Table], COUNT(*) AS [Rows] FROM dbo.DimDate
    UNION ALL SELECT 'DimUser', COUNT(*) FROM dbo.DimUser
    UNION ALL SELECT 'DimCategory', COUNT(*) FROM dbo.DimCategory
    UNION ALL SELECT 'DimLocation', COUNT(*) FROM dbo.DimLocation
    UNION ALL SELECT 'DimListing', COUNT(*) FROM dbo.DimListing
    UNION ALL SELECT 'DimCourier', COUNT(*) FROM dbo.DimCourier
    UNION ALL SELECT 'DimPromotionPackage', COUNT(*) FROM dbo.DimPromotionPackage
    UNION ALL SELECT 'FactSales', COUNT(*) FROM dbo.FactSales
    UNION ALL SELECT 'FactListings', COUNT(*) FROM dbo.FactListings
    UNION ALL SELECT 'FactPromotions', COUNT(*) FROM dbo.FactPromotions
    UNION ALL SELECT 'FactReviews', COUNT(*) FROM dbo.FactReviews;
END
GO

EXEC dbo.USP_LoadWarehouse;
GO
