/*
    Скрипт 5: изгледи (допълнение - не е задължително по условие)
*/
USE OlxDB
GO

----------------- View: активни обяви с цялата информация за показване -----------------
CREATE OR ALTER VIEW [Listings].[VW_ActiveListings] AS
SELECT
    l.ListingId,
    l.Title,
    l.Price,
    l.Currency,
    l.ItemCondition,
    l.IsNegotiable,
    l.DeliveryAvailable,
    [Catalog].[F_GetCategoryPath](l.CategoryId) AS CategoryPath,
    ci.[Name] AS City,
    ci.Region,
    u.FirstName + N' ' + u.LastName AS Seller,
    u.AvgRating AS SellerRating,
    l.ViewsCount,
    (SELECT COUNT(*) FROM [Listings].[Favorites] f WHERE f.ListingId = l.ListingId) AS FavoritesCount,
    (SELECT TOP 1 img.ImageUrl FROM [Listings].[ListingImages] img
        WHERE img.ListingId = l.ListingId ORDER BY img.SortOrder) AS MainImage,
    CASE WHEN EXISTS (SELECT 1 FROM [Promotions].[ListingPromotions] lp
                      WHERE lp.ListingId = l.ListingId
                        AND SYSDATETIME() BETWEEN lp.StartDate AND lp.EndDate)
         THEN 1 ELSE 0 END AS IsPromoted,
    l.CreatedOn,
    l.ExpiresOn
FROM [Listings].[Listings] AS l
    INNER JOIN [Locations].[Cities] AS ci ON ci.CityId = l.CityId
    INNER JOIN [Users].[Users] AS u ON u.UserId = l.UserId
WHERE l.[Status] = 'Active' AND u.[State] = 1;
GO
----------------- View: активни обяви -----------------

----------------- View: поръчки с купувач, продавач и куриер -----------------
CREATE OR ALTER VIEW [Orders].[VW_OrderDetails] AS
SELECT
    o.OrderId,
    o.OrderedOn,
    o.[Status],
    l.Title AS Listing,
    seller.FirstName + N' ' + seller.LastName AS Seller,
    buyer.FirstName + N' ' + buyer.LastName AS Buyer,
    c.[Name] AS Courier,
    o.PaymentMethod,
    o.ItemPrice,
    o.DeliveryFee,
    o.TotalAmount,
    o.DeliveredOn,
    DATEDIFF(DAY, o.OrderedOn, o.DeliveredOn) AS DeliveryDays,
    r.Rating
FROM [Orders].[Orders] AS o
    INNER JOIN [Listings].[Listings] AS l ON l.ListingId = o.ListingId
    INNER JOIN [Users].[Users] AS seller ON seller.UserId = l.UserId
    INNER JOIN [Users].[Users] AS buyer ON buyer.UserId = o.BuyerId
    INNER JOIN [Orders].[Couriers] AS c ON c.CourierId = o.CourierId
    LEFT JOIN [Orders].[Reviews] AS r ON r.OrderId = o.OrderId;
GO
----------------- View: поръчки -----------------
