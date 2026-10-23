/*
    Скрипт 2: функции
*/
USE OlxDB
GO

----------------- Function: пълен път на категория -----------------
-- Пример: Електроника > Телефони
CREATE OR ALTER FUNCTION [Catalog].[F_GetCategoryPath]
(
    @iCategoryId INT
)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @oPath NVARCHAR(400) = N'';
    DECLARE @currentId INT = @iCategoryId;
    DECLARE @name NVARCHAR(100);
    DECLARE @parentId INT;
    DECLARE @guard TINYINT = 0; -- защита от безкраен цикъл при грешни данни

    WHILE @currentId IS NOT NULL AND @guard < 10
    BEGIN
        SET @name = NULL;
        SET @parentId = NULL;

        SELECT @name = c.[Name], @parentId = c.ParentCategoryId
        FROM [Catalog].[Categories] AS c
        WHERE c.CategoryId = @currentId;

        IF @name IS NULL BREAK;

        SET @oPath = CASE WHEN @oPath = N'' THEN @name ELSE @name + N' > ' + @oPath END;
        SET @currentId = @parentId;
        SET @guard = @guard + 1;
    END

    RETURN @oPath;
END
GO
----------------- Function: пълен път на категория -----------------

----------------- Function: такса за доставка -----------------
-- Базова цена на куриера + такса за наложен платеж (1.5% от цената, минимум 0.50 EUR)
CREATE OR ALTER FUNCTION [Orders].[F_CalculateDeliveryFee]
(
    @iCourierId INT,
    @iItemPrice DECIMAL(10, 2),
    @iPaymentMethod VARCHAR(20) = 'Card'
)
RETURNS DECIMAL(10, 2)
AS
BEGIN
    DECLARE @oFee DECIMAL(10, 2);

    SELECT @oFee = c.BasePrice
    FROM [Orders].[Couriers] AS c
    WHERE c.CourierId = @iCourierId;

    IF @oFee IS NULL
        RETURN NULL;

    IF @iPaymentMethod = 'CashOnDelivery'
        SET @oFee = @oFee + CASE
                                WHEN ROUND(@iItemPrice * 0.015, 2) < 0.50 THEN 0.50
                                ELSE ROUND(@iItemPrice * 0.015, 2)
                            END;

    RETURN @oFee;
END
GO
----------------- Function: такса за доставка -----------------

----------------- Function (table-valued): активни обяви в категория и подкатегориите ѝ -----------------
CREATE OR ALTER FUNCTION [Listings].[F_GetActiveListingsInCategory]
(
    @iCategoryId INT
)
RETURNS TABLE
AS
RETURN
(
    WITH CategoryTree AS
    (
        SELECT c.CategoryId
        FROM [Catalog].[Categories] AS c
        WHERE c.CategoryId = @iCategoryId

        UNION ALL

        SELECT child.CategoryId
        FROM [Catalog].[Categories] AS child
            INNER JOIN CategoryTree AS ct ON child.ParentCategoryId = ct.CategoryId
    )
    SELECT
        l.ListingId,
        l.Title,
        l.Price,
        l.Currency,
        l.ItemCondition,
        cat.[Name] AS Category,
        ci.[Name] AS City,
        l.CreatedOn
    FROM [Listings].[Listings] AS l
        INNER JOIN CategoryTree AS t ON t.CategoryId = l.CategoryId
        INNER JOIN [Catalog].[Categories] AS cat ON cat.CategoryId = l.CategoryId
        INNER JOIN [Locations].[Cities] AS ci ON ci.CityId = l.CityId
    WHERE l.[Status] = 'Active'
);
GO
----------------- Function (table-valued) -----------------
