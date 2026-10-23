/*
    Курсова работа - Моделиране и анализ на софтуер
    Тема: OLX.bg (платформа за обяви)
    Скрипт 1: създаване на базата, схемите и таблиците
*/

USE master
GO

IF DB_ID('OlxDB') IS NOT NULL
BEGIN
    ALTER DATABASE OlxDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE OlxDB;
END
GO

CREATE DATABASE OlxDB COLLATE Cyrillic_General_CI_AS
GO

USE OlxDB
GO

CREATE SCHEMA Locations
GO

CREATE SCHEMA Users
GO

CREATE SCHEMA [Catalog]
GO

CREATE SCHEMA Listings
GO

CREATE SCHEMA Promotions
GO

CREATE SCHEMA Messaging
GO

CREATE SCHEMA Orders
GO

------------ Locations.Cities ------------
CREATE TABLE [Locations].[Cities]
(
    CityId INT IDENTITY(1, 1) NOT NULL,
    [Name] NVARCHAR(100) NOT NULL,
    Region NVARCHAR(100) NOT NULL,
    PostalCode VARCHAR(10) NULL,
    CONSTRAINT PK_Cities_CityId PRIMARY KEY(CityId),
    CONSTRAINT UQ_Cities_Name_Region UNIQUE([Name], Region)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Градове и области, в които се публикуват обяви.',
    @level0type=N'SCHEMA', @level0name=N'Locations',
    @level1type=N'TABLE', @level1name=N'Cities';
------------ Locations.Cities ------------

------------ Users.Users ------------
CREATE TABLE [Users].[Users]
(
    UserId INT IDENTITY(1, 1) NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(150) NOT NULL,
    Phone VARCHAR(20) NULL,
    PasswordHash CHAR(64) NOT NULL,
    CityId INT NOT NULL,
    IsBusiness BIT NOT NULL CONSTRAINT DF_Users_IsBusiness DEFAULT 0,
    AvgRating DECIMAL(3, 2) NULL, -- денормализирано поле, поддържа се от TR_Reviews_RecalculateRating
    RegisteredOn DATETIME2(0) NOT NULL CONSTRAINT DF_Users_RegisteredOn DEFAULT SYSDATETIME(),
    [State] TINYINT NOT NULL CONSTRAINT DF_Users_State DEFAULT 1, -- 1 активен, 0 блокиран
    CONSTRAINT PK_Users_UserId PRIMARY KEY(UserId),
    CONSTRAINT UQ_Users_Email UNIQUE(Email),
    CONSTRAINT FK_Users_Cities_CityId FOREIGN KEY(CityId) REFERENCES Locations.Cities(CityId),
    CONSTRAINT CK_Users_AvgRating CHECK (AvgRating BETWEEN 1 AND 5)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Регистрирани потребители - частни лица и бизнес профили.',
    @level0type=N'SCHEMA', @level0name=N'Users',
    @level1type=N'TABLE', @level1name=N'Users';
------------ Users.Users ------------

------------ Catalog.Categories ------------
CREATE TABLE [Catalog].[Categories]
(
    CategoryId INT IDENTITY(1, 1) NOT NULL,
    ParentCategoryId INT NULL,
    [Name] NVARCHAR(100) NOT NULL,
    Slug VARCHAR(100) NOT NULL,
    CONSTRAINT PK_Categories_CategoryId PRIMARY KEY(CategoryId),
    CONSTRAINT UQ_Categories_Slug UNIQUE(Slug),
    CONSTRAINT FK_Categories_Categories_ParentCategoryId FOREIGN KEY(ParentCategoryId) REFERENCES [Catalog].Categories(CategoryId)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Дърво от категории (рекурсивна връзка към родителската категория).',
    @level0type=N'SCHEMA', @level0name=N'Catalog',
    @level1type=N'TABLE', @level1name=N'Categories';
------------ Catalog.Categories ------------

------------ Listings.Listings ------------
CREATE TABLE [Listings].[Listings]
(
    ListingId INT IDENTITY(1, 1) NOT NULL,
    UserId INT NOT NULL,
    CategoryId INT NOT NULL,
    CityId INT NOT NULL,
    Title NVARCHAR(150) NOT NULL,
    [Description] NVARCHAR(2000) NULL,
    Price DECIMAL(10, 2) NOT NULL,
    Currency CHAR(3) NOT NULL CONSTRAINT DF_Listings_Currency DEFAULT 'EUR',
    ItemCondition VARCHAR(10) NOT NULL CONSTRAINT DF_Listings_ItemCondition DEFAULT 'Used',
    IsNegotiable BIT NOT NULL CONSTRAINT DF_Listings_IsNegotiable DEFAULT 0,
    DeliveryAvailable BIT NOT NULL CONSTRAINT DF_Listings_DeliveryAvailable DEFAULT 1,
    [Status] VARCHAR(10) NOT NULL CONSTRAINT DF_Listings_Status DEFAULT 'Active',
    ViewsCount INT NOT NULL CONSTRAINT DF_Listings_ViewsCount DEFAULT 0,
    CreatedOn DATETIME2(0) NOT NULL CONSTRAINT DF_Listings_CreatedOn DEFAULT SYSDATETIME(),
    ExpiresOn DATETIME2(0) NOT NULL,
    UpdatedOn DATETIME2(0) NULL,
    CONSTRAINT PK_Listings_ListingId PRIMARY KEY(ListingId),
    CONSTRAINT FK_Listings_Users_UserId FOREIGN KEY(UserId) REFERENCES Users.Users(UserId),
    CONSTRAINT FK_Listings_Categories_CategoryId FOREIGN KEY(CategoryId) REFERENCES [Catalog].Categories(CategoryId),
    CONSTRAINT FK_Listings_Cities_CityId FOREIGN KEY(CityId) REFERENCES Locations.Cities(CityId),
    CONSTRAINT CK_Listings_Price CHECK (Price >= 0),
    CONSTRAINT CK_Listings_ItemCondition CHECK (ItemCondition IN ('New', 'Used')),
    CONSTRAINT CK_Listings_Status CHECK ([Status] IN ('Active', 'Sold', 'Inactive', 'Expired')),
    CONSTRAINT CK_Listings_ExpiresOn CHECK (ExpiresOn > CreatedOn),
    INDEX IX_Listings_CategoryId NONCLUSTERED (CategoryId),
    INDEX IX_Listings_UserId NONCLUSTERED (UserId),
    INDEX IX_Listings_Status_CreatedOn NONCLUSTERED ([Status], CreatedOn)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Обяви, публикувани от потребителите.',
    @level0type=N'SCHEMA', @level0name=N'Listings',
    @level1type=N'TABLE', @level1name=N'Listings';
------------ Listings.Listings ------------

------------ Listings.ListingImages ------------
CREATE TABLE [Listings].[ListingImages]
(
    ImageId INT IDENTITY(1, 1) NOT NULL,
    ListingId INT NOT NULL,
    ImageUrl NVARCHAR(400) NOT NULL,
    SortOrder TINYINT NOT NULL CONSTRAINT DF_ListingImages_SortOrder DEFAULT 1,
    UploadedOn DATETIME2(0) NOT NULL CONSTRAINT DF_ListingImages_UploadedOn DEFAULT SYSDATETIME(),
    CONSTRAINT PK_ListingImages_ImageId PRIMARY KEY(ImageId),
    CONSTRAINT FK_ListingImages_Listings_ListingId FOREIGN KEY(ListingId) REFERENCES Listings.Listings(ListingId) ON DELETE CASCADE,
    CONSTRAINT UQ_ListingImages_ListingId_SortOrder UNIQUE(ListingId, SortOrder)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Снимки към обява (слаб обект - не съществува без обявата).',
    @level0type=N'SCHEMA', @level0name=N'Listings',
    @level1type=N'TABLE', @level1name=N'ListingImages';
------------ Listings.ListingImages ------------

------------ Listings.ListingPriceHistory ------------
CREATE TABLE [Listings].[ListingPriceHistory]
(
    HistoryId INT IDENTITY(1, 1) NOT NULL,
    ListingId INT NOT NULL,
    OldPrice DECIMAL(10, 2) NOT NULL,
    NewPrice DECIMAL(10, 2) NOT NULL,
    ChangedOn DATETIME2(0) NOT NULL CONSTRAINT DF_ListingPriceHistory_ChangedOn DEFAULT SYSDATETIME(),
    CONSTRAINT PK_ListingPriceHistory_HistoryId PRIMARY KEY(HistoryId),
    CONSTRAINT FK_ListingPriceHistory_Listings_ListingId FOREIGN KEY(ListingId) REFERENCES Listings.Listings(ListingId) ON DELETE CASCADE
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'История на промените в цената на обява (попълва се от TR_Listings_PriceHistory).',
    @level0type=N'SCHEMA', @level0name=N'Listings',
    @level1type=N'TABLE', @level1name=N'ListingPriceHistory';
------------ Listings.ListingPriceHistory ------------

------------ Listings.Favorites (many-to-many Users <-> Listings) ------------
CREATE TABLE [Listings].[Favorites]
(
    UserId INT NOT NULL,
    ListingId INT NOT NULL,
    AddedOn DATETIME2(0) NOT NULL CONSTRAINT DF_Favorites_AddedOn DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Favorites_UserId_ListingId PRIMARY KEY(UserId, ListingId),
    CONSTRAINT FK_Favorites_Users_UserId FOREIGN KEY(UserId) REFERENCES Users.Users(UserId),
    CONSTRAINT FK_Favorites_Listings_ListingId FOREIGN KEY(ListingId) REFERENCES Listings.Listings(ListingId) ON DELETE CASCADE
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Асоциативна таблица - любими обяви на потребителите (връзка много към много).',
    @level0type=N'SCHEMA', @level0name=N'Listings',
    @level1type=N'TABLE', @level1name=N'Favorites';
------------ Listings.Favorites ------------

------------ Promotions.PromotionPackages ------------
CREATE TABLE [Promotions].[PromotionPackages]
(
    PackageId INT IDENTITY(1, 1) NOT NULL,
    Code VARCHAR(10) NOT NULL,
    [Name] NVARCHAR(50) NOT NULL,
    DurationDays SMALLINT NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    [Description] NVARCHAR(300) NULL,
    CONSTRAINT PK_PromotionPackages_PackageId PRIMARY KEY(PackageId),
    CONSTRAINT UQ_PromotionPackages_Code UNIQUE(Code),
    CONSTRAINT CK_PromotionPackages_DurationDays CHECK (DurationDays > 0)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Платени пакети за промотиране на обяви (Топ обява, обновяване и т.н.).',
    @level0type=N'SCHEMA', @level0name=N'Promotions',
    @level1type=N'TABLE', @level1name=N'PromotionPackages';
------------ Promotions.PromotionPackages ------------

------------ Promotions.ListingPromotions (many-to-many Listings <-> PromotionPackages) ------------
CREATE TABLE [Promotions].[ListingPromotions]
(
    PromotionId INT IDENTITY(1, 1) NOT NULL,
    ListingId INT NOT NULL,
    PackageId INT NOT NULL,
    StartDate DATETIME2(0) NOT NULL,
    EndDate DATETIME2(0) NOT NULL,
    PaidAmount DECIMAL(10, 2) NOT NULL,
    CONSTRAINT PK_ListingPromotions_PromotionId PRIMARY KEY(PromotionId),
    CONSTRAINT FK_ListingPromotions_Listings_ListingId FOREIGN KEY(ListingId) REFERENCES Listings.Listings(ListingId),
    CONSTRAINT FK_ListingPromotions_PromotionPackages_PackageId FOREIGN KEY(PackageId) REFERENCES Promotions.PromotionPackages(PackageId),
    CONSTRAINT CK_ListingPromotions_Dates CHECK (EndDate > StartDate)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Закупени промоции за конкретни обяви.',
    @level0type=N'SCHEMA', @level0name=N'Promotions',
    @level1type=N'TABLE', @level1name=N'ListingPromotions';
------------ Promotions.ListingPromotions ------------

------------ Messaging.Conversations ------------
CREATE TABLE [Messaging].[Conversations]
(
    ConversationId INT IDENTITY(1, 1) NOT NULL,
    ListingId INT NOT NULL,
    BuyerId INT NOT NULL,
    StartedOn DATETIME2(0) NOT NULL CONSTRAINT DF_Conversations_StartedOn DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Conversations_ConversationId PRIMARY KEY(ConversationId),
    CONSTRAINT FK_Conversations_Listings_ListingId FOREIGN KEY(ListingId) REFERENCES Listings.Listings(ListingId),
    CONSTRAINT FK_Conversations_Users_BuyerId FOREIGN KEY(BuyerId) REFERENCES Users.Users(UserId),
    CONSTRAINT UQ_Conversations_ListingId_BuyerId UNIQUE(ListingId, BuyerId)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Разговор между купувач и продавач по конкретна обява.',
    @level0type=N'SCHEMA', @level0name=N'Messaging',
    @level1type=N'TABLE', @level1name=N'Conversations';
------------ Messaging.Conversations ------------

------------ Messaging.Messages ------------
CREATE TABLE [Messaging].[Messages]
(
    MessageId INT IDENTITY(1, 1) NOT NULL,
    ConversationId INT NOT NULL,
    SenderId INT NOT NULL,
    Body NVARCHAR(2000) NOT NULL,
    SentOn DATETIME2(0) NOT NULL CONSTRAINT DF_Messages_SentOn DEFAULT SYSDATETIME(),
    IsRead BIT NOT NULL CONSTRAINT DF_Messages_IsRead DEFAULT 0,
    CONSTRAINT PK_Messages_MessageId PRIMARY KEY(MessageId),
    CONSTRAINT FK_Messages_Conversations_ConversationId FOREIGN KEY(ConversationId) REFERENCES Messaging.Conversations(ConversationId) ON DELETE CASCADE,
    CONSTRAINT FK_Messages_Users_SenderId FOREIGN KEY(SenderId) REFERENCES Users.Users(UserId),
    INDEX IX_Messages_ConversationId NONCLUSTERED (ConversationId)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Съобщения в разговор.',
    @level0type=N'SCHEMA', @level0name=N'Messaging',
    @level1type=N'TABLE', @level1name=N'Messages';
------------ Messaging.Messages ------------

------------ Orders.Couriers ------------
CREATE TABLE [Orders].[Couriers]
(
    CourierId INT IDENTITY(1, 1) NOT NULL,
    [Name] NVARCHAR(50) NOT NULL,
    BasePrice DECIMAL(10, 2) NOT NULL,
    Website VARCHAR(100) NULL,
    CONSTRAINT PK_Couriers_CourierId PRIMARY KEY(CourierId),
    CONSTRAINT UQ_Couriers_Name UNIQUE([Name])
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Куриерски фирми, които работят с OLX доставка.',
    @level0type=N'SCHEMA', @level0name=N'Orders',
    @level1type=N'TABLE', @level1name=N'Couriers';
------------ Orders.Couriers ------------

------------ Orders.Orders ------------
CREATE TABLE [Orders].[Orders]
(
    OrderId INT IDENTITY(1, 1) NOT NULL,
    ListingId INT NOT NULL,
    BuyerId INT NOT NULL,
    CourierId INT NOT NULL,
    ItemPrice DECIMAL(10, 2) NOT NULL,
    DeliveryFee DECIMAL(10, 2) NOT NULL CONSTRAINT DF_Orders_DeliveryFee DEFAULT 0,
    TotalAmount AS (ItemPrice + DeliveryFee) PERSISTED, -- изчислима колона
    PaymentMethod VARCHAR(20) NOT NULL,
    [Status] VARCHAR(12) NOT NULL CONSTRAINT DF_Orders_Status DEFAULT 'Pending',
    DeliveryAddress NVARCHAR(250) NOT NULL,
    OrderedOn DATETIME2(0) NOT NULL CONSTRAINT DF_Orders_OrderedOn DEFAULT SYSDATETIME(),
    DeliveredOn DATETIME2(0) NULL,
    CONSTRAINT PK_Orders_OrderId PRIMARY KEY(OrderId),
    CONSTRAINT FK_Orders_Listings_ListingId FOREIGN KEY(ListingId) REFERENCES Listings.Listings(ListingId),
    CONSTRAINT FK_Orders_Users_BuyerId FOREIGN KEY(BuyerId) REFERENCES Users.Users(UserId),
    CONSTRAINT FK_Orders_Couriers_CourierId FOREIGN KEY(CourierId) REFERENCES Orders.Couriers(CourierId),
    CONSTRAINT CK_Orders_PaymentMethod CHECK (PaymentMethod IN ('Card', 'CashOnDelivery')),
    CONSTRAINT CK_Orders_Status CHECK ([Status] IN ('Pending', 'Shipped', 'Delivered', 'Cancelled', 'Returned')),
    INDEX IX_Orders_BuyerId NONCLUSTERED (BuyerId),
    INDEX IX_Orders_ListingId NONCLUSTERED (ListingId)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Поръчки през OLX доставка.',
    @level0type=N'SCHEMA', @level0name=N'Orders',
    @level1type=N'TABLE', @level1name=N'Orders';
------------ Orders.Orders ------------

------------ Orders.Reviews ------------
CREATE TABLE [Orders].[Reviews]
(
    ReviewId INT IDENTITY(1, 1) NOT NULL,
    OrderId INT NOT NULL,
    ReviewerId INT NOT NULL,
    SellerId INT NOT NULL,
    Rating TINYINT NOT NULL,
    Comment NVARCHAR(1000) NULL,
    CreatedOn DATETIME2(0) NOT NULL CONSTRAINT DF_Reviews_CreatedOn DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Reviews_ReviewId PRIMARY KEY(ReviewId),
    CONSTRAINT UQ_Reviews_OrderId UNIQUE(OrderId), -- една оценка на поръчка (1 към 0..1)
    CONSTRAINT FK_Reviews_Orders_OrderId FOREIGN KEY(OrderId) REFERENCES Orders.Orders(OrderId),
    CONSTRAINT FK_Reviews_Users_ReviewerId FOREIGN KEY(ReviewerId) REFERENCES Users.Users(UserId),
    CONSTRAINT FK_Reviews_Users_SellerId FOREIGN KEY(SellerId) REFERENCES Users.Users(UserId),
    CONSTRAINT CK_Reviews_Rating CHECK (Rating BETWEEN 1 AND 5),
    CONSTRAINT CK_Reviews_ReviewerNotSeller CHECK (ReviewerId <> SellerId)
);

EXEC sys.sp_addextendedproperty
    @name=N'TableDescription',
    @value=N'Оценки, които купувачите оставят на продавачите след доставка.',
    @level0type=N'SCHEMA', @level0name=N'Orders',
    @level1type=N'TABLE', @level1name=N'Reviews';
GO
------------ Orders.Reviews ------------
