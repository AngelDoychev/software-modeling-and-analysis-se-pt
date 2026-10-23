/*
    Data Warehouse за OLX - схема "фактически съзвездия" (fact constellation / galaxy)
    4 таблици факти, които споделят 7 таблици измерения.
    Ключовете в DW са заместители (surrogate keys), а оригиналните Id от OlxDB се пазят като бизнес ключове.
*/
USE master
GO

IF DB_ID('OlxDW') IS NOT NULL
BEGIN
    ALTER DATABASE OlxDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE OlxDW;
END
GO

CREATE DATABASE OlxDW COLLATE Cyrillic_General_CI_AS
GO

USE OlxDW
GO

/* ===================== ИЗМЕРЕНИЯ ===================== */

------------ DimDate ------------
CREATE TABLE dbo.DimDate
(
    DateKey INT NOT NULL,              -- yyyymmdd
    FullDate DATE NOT NULL,
    [Day] TINYINT NOT NULL,
    [Month] TINYINT NOT NULL,
    [MonthName] NVARCHAR(20) NOT NULL,
    [Quarter] TINYINT NOT NULL,
    [Year] SMALLINT NOT NULL,
    YearMonth CHAR(7) NOT NULL,        -- 2026-10
    DayOfWeek TINYINT NOT NULL,        -- 1 = понеделник
    [DayName] NVARCHAR(20) NOT NULL,
    IsWeekend BIT NOT NULL,
    CONSTRAINT PK_DimDate_DateKey PRIMARY KEY(DateKey)
);

------------ DimUser (ползва се и за продавач, и за купувач - role-playing dimension) ------------
CREATE TABLE dbo.DimUser
(
    UserKey INT IDENTITY(1, 1) NOT NULL,
    UserId INT NOT NULL,
    FullName NVARCHAR(110) NOT NULL,
    UserType NVARCHAR(20) NOT NULL,    -- Частно лице / Бизнес
    City NVARCHAR(100) NOT NULL,
    Region NVARCHAR(100) NOT NULL,
    RegisteredYear SMALLINT NOT NULL,
    AvgRating DECIMAL(3, 2) NULL,
    IsActive BIT NOT NULL,
    CONSTRAINT PK_DimUser_UserKey PRIMARY KEY(UserKey),
    CONSTRAINT UQ_DimUser_UserId UNIQUE(UserId)
);

------------ DimCategory ------------
CREATE TABLE dbo.DimCategory
(
    CategoryKey INT IDENTITY(1, 1) NOT NULL,
    CategoryId INT NOT NULL,
    CategoryName NVARCHAR(100) NOT NULL,
    ParentCategoryName NVARCHAR(100) NOT NULL,
    CategoryPath NVARCHAR(400) NOT NULL,
    CONSTRAINT PK_DimCategory_CategoryKey PRIMARY KEY(CategoryKey),
    CONSTRAINT UQ_DimCategory_CategoryId UNIQUE(CategoryId)
);

------------ DimLocation ------------
CREATE TABLE dbo.DimLocation
(
    LocationKey INT IDENTITY(1, 1) NOT NULL,
    CityId INT NOT NULL,
    City NVARCHAR(100) NOT NULL,
    Region NVARCHAR(100) NOT NULL,
    PostalCode VARCHAR(10) NULL,
    Country NVARCHAR(50) NOT NULL CONSTRAINT DF_DimLocation_Country DEFAULT N'България',
    CONSTRAINT PK_DimLocation_LocationKey PRIMARY KEY(LocationKey),
    CONSTRAINT UQ_DimLocation_CityId UNIQUE(CityId)
);

------------ DimListing ------------
CREATE TABLE dbo.DimListing
(
    ListingKey INT IDENTITY(1, 1) NOT NULL,
    ListingId INT NOT NULL,
    Title NVARCHAR(150) NOT NULL,
    ItemCondition NVARCHAR(20) NOT NULL,
    IsNegotiable BIT NOT NULL,
    DeliveryAvailable BIT NOT NULL,
    CurrentStatus VARCHAR(10) NOT NULL,
    PriceBand NVARCHAR(20) NOT NULL,   -- ценови диапазон за по-лесни отчети
    CONSTRAINT PK_DimListing_ListingKey PRIMARY KEY(ListingKey),
    CONSTRAINT UQ_DimListing_ListingId UNIQUE(ListingId)
);

------------ DimCourier ------------
CREATE TABLE dbo.DimCourier
(
    CourierKey INT IDENTITY(1, 1) NOT NULL,
    CourierId INT NOT NULL,
    CourierName NVARCHAR(50) NOT NULL,
    BasePrice DECIMAL(10, 2) NOT NULL,
    CONSTRAINT PK_DimCourier_CourierKey PRIMARY KEY(CourierKey),
    CONSTRAINT UQ_DimCourier_CourierId UNIQUE(CourierId)
);

------------ DimPromotionPackage ------------
CREATE TABLE dbo.DimPromotionPackage
(
    PackageKey INT IDENTITY(1, 1) NOT NULL,
    PackageId INT NOT NULL,
    PackageCode VARCHAR(10) NOT NULL,
    PackageName NVARCHAR(50) NOT NULL,
    DurationDays SMALLINT NOT NULL,
    ListPrice DECIMAL(10, 2) NOT NULL,
    CONSTRAINT PK_DimPromotionPackage_PackageKey PRIMARY KEY(PackageKey),
    CONSTRAINT UQ_DimPromotionPackage_PackageId UNIQUE(PackageId)
);
GO

/* ===================== ФАКТИ ===================== */

------------ FactSales (зърно: една поръчка) ------------
CREATE TABLE dbo.FactSales
(
    SalesKey INT IDENTITY(1, 1) NOT NULL,
    OrderId INT NOT NULL,              -- degenerate dimension
    OrderDateKey INT NOT NULL,
    DeliveredDateKey INT NULL,
    ListingKey INT NOT NULL,
    SellerKey INT NOT NULL,
    BuyerKey INT NOT NULL,
    CategoryKey INT NOT NULL,
    LocationKey INT NOT NULL,          -- местоположение на обявата
    CourierKey INT NOT NULL,
    PaymentMethod VARCHAR(20) NOT NULL,
    OrderStatus VARCHAR(12) NOT NULL,
    ItemPrice DECIMAL(10, 2) NOT NULL,
    DeliveryFee DECIMAL(10, 2) NOT NULL,
    TotalAmount DECIMAL(10, 2) NOT NULL,
    DeliveryDays INT NULL,
    IsCompleted INT NOT NULL,          -- 1 = доставена (за лесно сумиране)
    CONSTRAINT PK_FactSales_SalesKey PRIMARY KEY(SalesKey),
    CONSTRAINT FK_FactSales_DimDate_OrderDateKey FOREIGN KEY(OrderDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_FactSales_DimDate_DeliveredDateKey FOREIGN KEY(DeliveredDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_FactSales_DimListing_ListingKey FOREIGN KEY(ListingKey) REFERENCES dbo.DimListing(ListingKey),
    CONSTRAINT FK_FactSales_DimUser_SellerKey FOREIGN KEY(SellerKey) REFERENCES dbo.DimUser(UserKey),
    CONSTRAINT FK_FactSales_DimUser_BuyerKey FOREIGN KEY(BuyerKey) REFERENCES dbo.DimUser(UserKey),
    CONSTRAINT FK_FactSales_DimCategory_CategoryKey FOREIGN KEY(CategoryKey) REFERENCES dbo.DimCategory(CategoryKey),
    CONSTRAINT FK_FactSales_DimLocation_LocationKey FOREIGN KEY(LocationKey) REFERENCES dbo.DimLocation(LocationKey),
    CONSTRAINT FK_FactSales_DimCourier_CourierKey FOREIGN KEY(CourierKey) REFERENCES dbo.DimCourier(CourierKey)
);

------------ FactListings (зърно: една обява) ------------
CREATE TABLE dbo.FactListings
(
    ListingFactKey INT IDENTITY(1, 1) NOT NULL,
    ListingKey INT NOT NULL,
    CreatedDateKey INT NOT NULL,
    SellerKey INT NOT NULL,
    CategoryKey INT NOT NULL,
    LocationKey INT NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    InitialPrice DECIMAL(10, 2) NOT NULL,
    ViewsCount INT NOT NULL,
    FavoritesCount INT NOT NULL,
    ImagesCount INT NOT NULL,
    ConversationsCount INT NOT NULL,
    MessagesCount INT NOT NULL,
    PriceChangesCount INT NOT NULL,
    PromotionsCount INT NOT NULL,
    IsSold INT NOT NULL,
    ListingCount INT NOT NULL CONSTRAINT DF_FactListings_ListingCount DEFAULT 1,
    CONSTRAINT PK_FactListings_ListingFactKey PRIMARY KEY(ListingFactKey),
    CONSTRAINT FK_FactListings_DimListing_ListingKey FOREIGN KEY(ListingKey) REFERENCES dbo.DimListing(ListingKey),
    CONSTRAINT FK_FactListings_DimDate_CreatedDateKey FOREIGN KEY(CreatedDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_FactListings_DimUser_SellerKey FOREIGN KEY(SellerKey) REFERENCES dbo.DimUser(UserKey),
    CONSTRAINT FK_FactListings_DimCategory_CategoryKey FOREIGN KEY(CategoryKey) REFERENCES dbo.DimCategory(CategoryKey),
    CONSTRAINT FK_FactListings_DimLocation_LocationKey FOREIGN KEY(LocationKey) REFERENCES dbo.DimLocation(LocationKey)
);

------------ FactPromotions (зърно: една закупена промоция) ------------
CREATE TABLE dbo.FactPromotions
(
    PromotionFactKey INT IDENTITY(1, 1) NOT NULL,
    PromotionId INT NOT NULL,          -- degenerate dimension
    StartDateKey INT NOT NULL,
    ListingKey INT NOT NULL,
    SellerKey INT NOT NULL,
    CategoryKey INT NOT NULL,
    LocationKey INT NOT NULL,
    PackageKey INT NOT NULL,
    PaidAmount DECIMAL(10, 2) NOT NULL,
    DurationDays SMALLINT NOT NULL,
    LedToSale INT NOT NULL,            -- 1 = обявата е продадена след промоцията
    CONSTRAINT PK_FactPromotions_PromotionFactKey PRIMARY KEY(PromotionFactKey),
    CONSTRAINT FK_FactPromotions_DimDate_StartDateKey FOREIGN KEY(StartDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_FactPromotions_DimListing_ListingKey FOREIGN KEY(ListingKey) REFERENCES dbo.DimListing(ListingKey),
    CONSTRAINT FK_FactPromotions_DimUser_SellerKey FOREIGN KEY(SellerKey) REFERENCES dbo.DimUser(UserKey),
    CONSTRAINT FK_FactPromotions_DimCategory_CategoryKey FOREIGN KEY(CategoryKey) REFERENCES dbo.DimCategory(CategoryKey),
    CONSTRAINT FK_FactPromotions_DimLocation_LocationKey FOREIGN KEY(LocationKey) REFERENCES dbo.DimLocation(LocationKey),
    CONSTRAINT FK_FactPromotions_DimPromotionPackage_PackageKey FOREIGN KEY(PackageKey) REFERENCES dbo.DimPromotionPackage(PackageKey)
);

------------ FactReviews (зърно: една оценка) ------------
CREATE TABLE dbo.FactReviews
(
    ReviewFactKey INT IDENTITY(1, 1) NOT NULL,
    ReviewId INT NOT NULL,             -- degenerate dimension
    ReviewDateKey INT NOT NULL,
    SellerKey INT NOT NULL,
    BuyerKey INT NOT NULL,
    CategoryKey INT NOT NULL,
    CourierKey INT NOT NULL,
    Rating TINYINT NOT NULL,
    IsPositive INT NOT NULL,           -- 1 = оценка 4 или 5
    HasComment INT NOT NULL,
    CONSTRAINT PK_FactReviews_ReviewFactKey PRIMARY KEY(ReviewFactKey),
    CONSTRAINT FK_FactReviews_DimDate_ReviewDateKey FOREIGN KEY(ReviewDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_FactReviews_DimUser_SellerKey FOREIGN KEY(SellerKey) REFERENCES dbo.DimUser(UserKey),
    CONSTRAINT FK_FactReviews_DimUser_BuyerKey FOREIGN KEY(BuyerKey) REFERENCES dbo.DimUser(UserKey),
    CONSTRAINT FK_FactReviews_DimCategory_CategoryKey FOREIGN KEY(CategoryKey) REFERENCES dbo.DimCategory(CategoryKey),
    CONSTRAINT FK_FactReviews_DimCourier_CourierKey FOREIGN KEY(CourierKey) REFERENCES dbo.DimCourier(CourierKey)
);
GO

/* Изгледи за Power BI - едно и също измерение DimUser, видяно като продавач и като купувач */
CREATE VIEW dbo.VW_DimSeller AS
SELECT UserKey AS SellerKey, FullName AS Seller, UserType AS SellerType, City AS SellerCity,
       Region AS SellerRegion, AvgRating AS SellerRating
FROM dbo.DimUser;
GO

CREATE VIEW dbo.VW_DimBuyer AS
SELECT UserKey AS BuyerKey, FullName AS Buyer, UserType AS BuyerType, City AS BuyerCity, Region AS BuyerRegion
FROM dbo.DimUser;
GO
