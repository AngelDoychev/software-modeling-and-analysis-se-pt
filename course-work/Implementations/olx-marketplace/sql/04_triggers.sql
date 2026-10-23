/*
    Скрипт 4: тригери
*/
USE OlxDB
GO

------------ Trigger: статус на обявата при поръчка ------------
-- Нова поръчка -> обявата става 'Sold'.
-- Поръчката е отказана/върната -> обявата отново е активна (или изтекла, ако срокът ѝ е минал).
CREATE OR ALTER TRIGGER [Orders].[TR_Orders_UpdateListingStatus]
ON [Orders].[Orders]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM INSERTED)
        RETURN;

    UPDATE l
    SET l.[Status] = 'Sold',
        l.UpdatedOn = SYSDATETIME()
    FROM [Listings].[Listings] AS l
        INNER JOIN INSERTED AS i ON i.ListingId = l.ListingId
    WHERE i.[Status] NOT IN ('Cancelled', 'Returned')
      AND l.[Status] <> 'Sold';

    -- само при UPDATE: статусът на поръчката е сменен на Cancelled/Returned
    UPDATE l
    SET l.[Status] = CASE WHEN l.ExpiresOn > SYSDATETIME() THEN 'Active' ELSE 'Expired' END,
        l.UpdatedOn = SYSDATETIME()
    FROM [Listings].[Listings] AS l
        INNER JOIN INSERTED AS i ON i.ListingId = l.ListingId
        INNER JOIN DELETED AS d ON d.OrderId = i.OrderId
    WHERE i.[Status] IN ('Cancelled', 'Returned')
      AND d.[Status] NOT IN ('Cancelled', 'Returned')
      AND l.[Status] = 'Sold'
      AND NOT EXISTS (SELECT 1
                      FROM [Orders].[Orders] AS o
                      WHERE o.ListingId = l.ListingId
                        AND o.[Status] NOT IN ('Cancelled', 'Returned'));
END
GO
------------ Trigger: статус на обявата при поръчка ------------

------------ Trigger: валидиране на оценка + преизчисляване на рейтинга на продавача ------------
CREATE OR ALTER TRIGGER [Orders].[TR_Reviews_RecalculateRating]
ON [Orders].[Reviews]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- оценка може да остави само купувачът, след като поръчката е доставена,
    -- и тя трябва да е за продавача на обявата
    IF EXISTS (
        SELECT 1
        FROM INSERTED AS i
            INNER JOIN [Orders].[Orders] AS o ON o.OrderId = i.OrderId
            INNER JOIN [Listings].[Listings] AS l ON l.ListingId = o.ListingId
        WHERE o.[Status] <> 'Delivered'
           OR o.BuyerId <> i.ReviewerId
           OR l.UserId <> i.SellerId
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50030, N'Оценка може да се остави само от купувача, след като поръчката е доставена.', 1;
    END

    -- денормализираното поле Users.AvgRating се преизчислява за засегнатите продавачи
    UPDATE u
    SET u.AvgRating = (
        SELECT CAST(AVG(CAST(r.Rating AS DECIMAL(5, 2))) AS DECIMAL(3, 2))
        FROM [Orders].[Reviews] AS r
        WHERE r.SellerId = u.UserId
    )
    FROM [Users].[Users] AS u
    WHERE u.UserId IN (SELECT SellerId FROM INSERTED
                       UNION
                       SELECT SellerId FROM DELETED);
END
GO
------------ Trigger: рейтинг ------------

------------ Trigger: история на цената ------------
CREATE OR ALTER TRIGGER [Listings].[TR_Listings_PriceHistory]
ON [Listings].[Listings]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Price)
        RETURN;

    INSERT INTO [Listings].[ListingPriceHistory]
        (ListingId, OldPrice, NewPrice, ChangedOn)
    SELECT i.ListingId, d.Price, i.Price, SYSDATETIME()
    FROM INSERTED AS i
        INNER JOIN DELETED AS d ON d.ListingId = i.ListingId
    WHERE i.Price <> d.Price;
END
GO
------------ Trigger: история на цената ------------

------------ Trigger: потребител не може да добави собствена обява в любими ------------
CREATE OR ALTER TRIGGER [Listings].[TR_Favorites_PreventOwnListing]
ON [Listings].[Favorites]
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM INSERTED AS i
            INNER JOIN [Listings].[Listings] AS l ON l.ListingId = i.ListingId
        WHERE l.UserId = i.UserId
    )
    BEGIN
        RAISERROR(N'Не може да добавите собствената си обява в любими.', 16, 1);
        RETURN;
    END

    INSERT INTO [Listings].[Favorites] (UserId, ListingId, AddedOn)
    SELECT i.UserId, i.ListingId, ISNULL(i.AddedOn, SYSDATETIME())
    FROM INSERTED AS i;
END
GO
------------ Trigger: любими ------------
