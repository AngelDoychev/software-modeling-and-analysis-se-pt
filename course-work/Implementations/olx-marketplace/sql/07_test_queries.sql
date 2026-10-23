/*
    Скрипт 7: примери за използване на функциите, процедурите и тригерите
    (пуска се ред по ред, за да се види резултата)
*/
USE OlxDB
GO

----------------- Функции -----------------
SELECT [Catalog].[F_GetCategoryPath](9) AS CategoryPath; -- Електроника > Компютри и лаптопи

SELECT [Orders].[F_CalculateDeliveryFee](1, 120.00, 'CashOnDelivery') AS FeeSpeedyCOD,
       [Orders].[F_CalculateDeliveryFee](3, 120.00, 'Card') AS FeeBoxNowCard;

-- всички активни обяви в "Електроника" (вкл. подкатегориите)
SELECT * FROM [Listings].[F_GetActiveListingsInCategory](1) ORDER BY CreatedOn DESC;
GO

----------------- USP_CreateListing -----------------
DECLARE @newId INT;
EXEC [Listings].[USP_CreateListing]
    @iUserId = 5,
    @iCategoryId = 8,               -- Телефони
    @iTitle = N'iPhone 12 64GB черен',
    @iDescription = N'Батерия 86%, без драскотини. Изпращам с OLX доставка.',
    @iPrice = 260,
    @iIsNegotiable = 1,
    @oListingId = @newId OUTPUT;
SELECT * FROM [Listings].[Listings] WHERE ListingId = @newId;

-- грешка: категорията "Електроника" има подкатегории
DECLARE @tmp INT;
EXEC [Listings].[USP_CreateListing] @iUserId = 5, @iCategoryId = 1, @iTitle = N'Тест', @iPrice = 10, @oListingId = @tmp OUTPUT;
GO

----------------- TR_Listings_PriceHistory -----------------
DECLARE @lastListing INT = (SELECT MAX(ListingId) FROM [Listings].[Listings]);
UPDATE [Listings].[Listings] SET Price = 240 WHERE ListingId = @lastListing;
SELECT * FROM [Listings].[ListingPriceHistory] WHERE ListingId = @lastListing;
GO

----------------- USP_PromoteListing -----------------
DECLARE @lastListing INT = (SELECT MAX(ListingId) FROM [Listings].[Listings]);
EXEC [Promotions].[USP_PromoteListing] @iListingId = @lastListing, @iPackageId = 1;
EXEC [Promotions].[USP_PromoteListing] @iListingId = @lastListing, @iPackageId = 3; -- започва след края на първия
GO

----------------- USP_PlaceOrder + TR_Orders_UpdateListingStatus -----------------
DECLARE @lastListing INT = (SELECT MAX(ListingId) FROM [Listings].[Listings]);
DECLARE @orderId INT;
EXEC [Orders].[USP_PlaceOrder]
    @iListingId = @lastListing,
    @iBuyerId = 12,
    @iCourierId = 2,
    @iPaymentMethod = 'CashOnDelivery',
    @iDeliveryAddress = N'Пловдив, ул. „Капитан Райчо“ 15',
    @oOrderId = @orderId OUTPUT;

SELECT * FROM [Orders].[VW_OrderDetails] WHERE OrderId = @orderId;
SELECT ListingId, [Status] FROM [Listings].[Listings] WHERE ListingId = @lastListing; -- Sold

-- втори опит за същата обява -> грешка "Обявата не е активна."
DECLARE @orderId2 INT;
BEGIN TRY
    EXEC [Orders].[USP_PlaceOrder] @lastListing, 20, 1, 'Card', N'София', @orderId2 OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS ErrMsg;
END CATCH

-- отказ на поръчката -> обявата отново е активна
UPDATE [Orders].[Orders] SET [Status] = 'Cancelled' WHERE OrderId = @orderId;
SELECT ListingId, [Status] FROM [Listings].[Listings] WHERE ListingId = @lastListing; -- Active
GO

----------------- TR_Reviews_RecalculateRating -----------------
-- опит за оценка на поръчка, която не е доставена -> грешка
DECLARE @pendingOrder INT = (SELECT TOP 1 OrderId FROM [Orders].[Orders] WHERE [Status] = 'Pending');
BEGIN TRY
    INSERT INTO [Orders].[Reviews] (OrderId, ReviewerId, SellerId, Rating)
    SELECT o.OrderId, o.BuyerId, l.UserId, 5
    FROM [Orders].[Orders] o INNER JOIN [Listings].[Listings] l ON l.ListingId = o.ListingId
    WHERE o.OrderId = @pendingOrder;
END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS ErrMsg;
END CATCH
GO

-- топ продавачи по рейтинг (AvgRating се поддържа от тригера)
SELECT TOP 10 UserId, FirstName, LastName, AvgRating
FROM [Users].[Users]
WHERE AvgRating IS NOT NULL
ORDER BY AvgRating DESC, UserId;
GO

----------------- TR_Favorites_PreventOwnListing -----------------
DECLARE @ownListing INT, @owner INT;
SELECT TOP 1 @ownListing = ListingId, @owner = UserId FROM [Listings].[Listings] WHERE [Status] = 'Active';
INSERT INTO [Listings].[Favorites] (UserId, ListingId) VALUES (@owner, @ownListing); -- грешка
GO

----------------- USP_GetSellerStatistics -----------------
EXEC [Users].[USP_GetSellerStatistics] @iUserId = 11; -- бизнес профил
GO

----------------- Изгледи -----------------
SELECT TOP 20 * FROM [Listings].[VW_ActiveListings] ORDER BY IsPromoted DESC, CreatedOn DESC;
GO
