/*
    Скрипт 3: съхранени процедури
*/
USE OlxDB
GO

------------ SP: публикуване на нова обява ------------
CREATE OR ALTER PROCEDURE [Listings].[USP_CreateListing]
(
    @iUserId INT,
    @iCategoryId INT,
    @iTitle NVARCHAR(150),
    @iDescription NVARCHAR(2000) = NULL,
    @iPrice DECIMAL(10, 2),
    @iItemCondition VARCHAR(10) = 'Used',
    @iIsNegotiable BIT = 0,
    @iDeliveryAvailable BIT = 1,
    @iCityId INT = NULL, -- ако не е подаден, се взима градът на потребителя
    @oListingId INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [Users].[Users] WHERE UserId = @iUserId AND [State] = 1)
        THROW 50001, N'Потребителят не съществува или е блокиран.', 1;

    IF NOT EXISTS (SELECT 1 FROM [Catalog].[Categories] WHERE CategoryId = @iCategoryId)
        THROW 50002, N'Категорията не съществува.', 1;

    -- в OLX се публикува само в крайна подкатегория (без деца)
    IF EXISTS (SELECT 1 FROM [Catalog].[Categories] WHERE ParentCategoryId = @iCategoryId)
        THROW 50003, N'Обява може да се публикува само в крайна подкатегория.', 1;

    IF @iCityId IS NULL
        SELECT @iCityId = CityId FROM [Users].[Users] WHERE UserId = @iUserId;

    INSERT INTO [Listings].[Listings]
        (UserId, CategoryId, CityId, Title, [Description], Price, ItemCondition,
         IsNegotiable, DeliveryAvailable, [Status], CreatedOn, ExpiresOn)
    VALUES
        (@iUserId, @iCategoryId, @iCityId, @iTitle, @iDescription, @iPrice, @iItemCondition,
         @iIsNegotiable, @iDeliveryAvailable, 'Active', SYSDATETIME(), DATEADD(DAY, 30, SYSDATETIME()));

    SET @oListingId = SCOPE_IDENTITY();
END
GO
------------ SP: публикуване на нова обява ------------

------------ SP: поръчка през OLX доставка ------------
CREATE OR ALTER PROCEDURE [Orders].[USP_PlaceOrder]
(
    @iListingId INT,
    @iBuyerId INT,
    @iCourierId INT,
    @iPaymentMethod VARCHAR(20),
    @iDeliveryAddress NVARCHAR(250),
    @oOrderId INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @sellerId INT;
    DECLARE @price DECIMAL(10, 2);
    DECLARE @status VARCHAR(10);
    DECLARE @deliveryAvailable BIT;
    DECLARE @fee DECIMAL(10, 2);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- заключваме реда, за да не се купи една обява два пъти едновременно
        SELECT @sellerId = l.UserId,
               @price = l.Price,
               @status = l.[Status],
               @deliveryAvailable = l.DeliveryAvailable
        FROM [Listings].[Listings] AS l WITH (UPDLOCK, ROWLOCK)
        WHERE l.ListingId = @iListingId;

        IF @sellerId IS NULL
            THROW 50010, N'Обявата не съществува.', 1;

        IF @status <> 'Active'
            THROW 50011, N'Обявата не е активна.', 1;

        IF @deliveryAvailable = 0
            THROW 50012, N'Продавачът не предлага OLX доставка за тази обява.', 1;

        IF @sellerId = @iBuyerId
            THROW 50013, N'Не може да купите собствената си обява.', 1;

        SET @fee = [Orders].[F_CalculateDeliveryFee](@iCourierId, @price, @iPaymentMethod);

        IF @fee IS NULL
            THROW 50014, N'Невалиден куриер.', 1;

        INSERT INTO [Orders].[Orders]
            (ListingId, BuyerId, CourierId, ItemPrice, DeliveryFee, PaymentMethod, [Status], DeliveryAddress, OrderedOn)
        VALUES
            (@iListingId, @iBuyerId, @iCourierId, @price, @fee, @iPaymentMethod, 'Pending', @iDeliveryAddress, SYSDATETIME());

        SET @oOrderId = SCOPE_IDENTITY();

        -- статусът на обявата става 'Sold' от тригера TR_Orders_UpdateListingStatus

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
------------ SP: поръчка през OLX доставка ------------

------------ SP: промотиране на обява ------------
CREATE OR ALTER PROCEDURE [Promotions].[USP_PromoteListing]
(
    @iListingId INT,
    @iPackageId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @days SMALLINT;
    DECLARE @price DECIMAL(10, 2);
    DECLARE @start DATETIME2(0);

    IF NOT EXISTS (SELECT 1 FROM [Listings].[Listings] WHERE ListingId = @iListingId AND [Status] = 'Active')
        THROW 50020, N'Може да се промотира само активна обява.', 1;

    SELECT @days = DurationDays, @price = Price
    FROM [Promotions].[PromotionPackages]
    WHERE PackageId = @iPackageId;

    IF @days IS NULL
        THROW 50021, N'Невалиден промо пакет.', 1;

    -- ако обявата вече е промотирана, новият пакет започва след края на текущия
    SELECT @start = MAX(EndDate)
    FROM [Promotions].[ListingPromotions]
    WHERE ListingId = @iListingId AND EndDate > SYSDATETIME();

    IF @start IS NULL
        SET @start = SYSDATETIME();

    INSERT INTO [Promotions].[ListingPromotions]
        (ListingId, PackageId, StartDate, EndDate, PaidAmount)
    VALUES
        (@iListingId, @iPackageId, @start, DATEADD(DAY, @days, @start), @price);

    SELECT lp.PromotionId, lp.ListingId, pp.[Name] AS Package, lp.StartDate, lp.EndDate, lp.PaidAmount
    FROM [Promotions].[ListingPromotions] AS lp
        INNER JOIN [Promotions].[PromotionPackages] AS pp ON pp.PackageId = lp.PackageId
    WHERE lp.PromotionId = SCOPE_IDENTITY();
END
GO
------------ SP: промотиране на обява ------------

------------ SP: статистика за продавач ------------
CREATE OR ALTER PROCEDURE [Users].[USP_GetSellerStatistics]
(
    @iUserId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.UserId,
        u.FirstName + N' ' + u.LastName AS Seller,
        ci.[Name] AS City,
        u.AvgRating,
        (SELECT COUNT(*) FROM [Listings].[Listings] l WHERE l.UserId = u.UserId) AS TotalListings,
        (SELECT COUNT(*) FROM [Listings].[Listings] l WHERE l.UserId = u.UserId AND l.[Status] = 'Active') AS ActiveListings,
        (SELECT COUNT(*) FROM [Listings].[Listings] l WHERE l.UserId = u.UserId AND l.[Status] = 'Sold') AS SoldListings,
        (SELECT ISNULL(SUM(l.ViewsCount), 0) FROM [Listings].[Listings] l WHERE l.UserId = u.UserId) AS TotalViews,
        (SELECT COUNT(*)
            FROM [Listings].[Favorites] f
                INNER JOIN [Listings].[Listings] l ON l.ListingId = f.ListingId
            WHERE l.UserId = u.UserId) AS TimesAddedToFavorites,
        (SELECT ISNULL(SUM(o.ItemPrice), 0)
            FROM [Orders].[Orders] o
                INNER JOIN [Listings].[Listings] l ON l.ListingId = o.ListingId
            WHERE l.UserId = u.UserId AND o.[Status] = 'Delivered') AS Revenue,
        (SELECT COUNT(*) FROM [Orders].[Reviews] r WHERE r.SellerId = u.UserId) AS ReviewsCount
    FROM [Users].[Users] AS u
        INNER JOIN [Locations].[Cities] AS ci ON ci.CityId = u.CityId
    WHERE u.UserId = @iUserId;
END
GO
------------ SP: статистика за продавач ------------

------------ SP: маркиране на изтекли обяви (пуска се веднъж на ден, напр. от SQL Agent) ------------
CREATE OR ALTER PROCEDURE [Listings].[USP_ExpireOldListings]
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [Listings].[Listings]
    SET [Status] = 'Expired',
        UpdatedOn = SYSDATETIME()
    WHERE [Status] = 'Active'
      AND ExpiresOn < SYSDATETIME();

    SELECT @@ROWCOUNT AS ExpiredListings;
END
GO
------------ SP: маркиране на изтекли обяви ------------
