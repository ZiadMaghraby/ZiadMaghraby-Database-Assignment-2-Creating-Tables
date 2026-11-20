SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE DATABASE BidNile;
GO
USE BidNile;
GO
CREATE SCHEMA Location;
GO
CREATE SCHEMA [Identity];
GO
CREATE SCHEMA Inventory;
GO
CREATE SCHEMA Sales;
GO

CREATE TABLE Location.City
(
    Id INT IDENTITY(1,1) CONSTRAINT PK_City PRIMARY KEY,
    Name NVARCHAR(60) NOT NULL,
    CountryCode CHAR(2) NOT NULL
        CONSTRAINT CK_City_CountryCode CHECK (CountryCode IN ('EG', 'SA', 'AE')),
    CONSTRAINT UQ_City_Name_CountryCode UNIQUE (Name, CountryCode)
);
GO

CREATE TABLE [Identity].Member
(
    Id UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT DF_Member_Id DEFAULT NEWID(),
    FullName NVARCHAR(100) NOT NULL,
    Email VARCHAR(254) NOT NULL,
    Mobile VARCHAR(16) NOT NULL,
    NationalId VARCHAR(20) NOT NULL,
    BirthDate DATE NOT NULL
        CONSTRAINT CK_Member_BirthDate CHECK
        (BirthDate <= DATEADD(YEAR, -18, CONVERT(DATE, SYSDATETIME()))),
    IsVerified BIT NOT NULL CONSTRAINT DF_Member_IsVerified DEFAULT 0,
    RegisteredAt DATETIME2(3) NOT NULL
        CONSTRAINT DF_Member_RegisteredAt DEFAULT SYSUTCDATETIME(),
    CityId INT NOT NULL,
    InvitedByMemberId UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_Member PRIMARY KEY (Id),
    CONSTRAINT UQ_Member_Email UNIQUE (Email),
    CONSTRAINT UQ_Member_NationalId UNIQUE (NationalId),
    CONSTRAINT CK_Member_NationalId CHECK
        (LEN(NationalId) > 0 AND NationalId COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Za-z0-9]%'),
    CONSTRAINT CK_Member_Mobile CHECK
        (LEN(Mobile) BETWEEN 2 AND 16 AND LEFT(Mobile, 1) = '+'
         AND SUBSTRING(Mobile, 2, 15) COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Member_InvitedByMemberId CHECK (InvitedByMemberId <> Id)
);
GO

CREATE TABLE [Identity].Wallet
(
    Id UNIQUEIDENTIFIER NOT NULL,
    Balance DECIMAL(12,2) NOT NULL CONSTRAINT DF_Wallet_Balance DEFAULT 0,
    HeldAmount DECIMAL(12,2) NOT NULL CONSTRAINT DF_Wallet_HeldAmount DEFAULT 0,
    Currency CHAR(3) NOT NULL CONSTRAINT DF_Wallet_Currency DEFAULT 'EGP',
    UpdatedAt DATETIME2(3) NOT NULL
        CONSTRAINT DF_Wallet_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Wallet PRIMARY KEY (Id),
    CONSTRAINT CK_Wallet_Balance CHECK (Balance >= 0),
    CONSTRAINT CK_Wallet_HeldAmount CHECK (HeldAmount >= 0 AND HeldAmount <= Balance)
);
GO

CREATE TABLE Inventory.Warehouse
(
    Id INT IDENTITY(1,1) CONSTRAINT PK_Warehouse PRIMARY KEY,
    Name NVARCHAR(80) NOT NULL,
    Capacity INT NOT NULL CONSTRAINT CK_Warehouse_Capacity CHECK (Capacity > 0),
    Latitude FLOAT NOT NULL CONSTRAINT CK_Warehouse_Latitude CHECK (Latitude BETWEEN -90 AND 90),
    Longitude FLOAT NOT NULL CONSTRAINT CK_Warehouse_Longitude CHECK (Longitude BETWEEN -180 AND 180),
    CityId INT NOT NULL,
    ManagerMemberId UNIQUEIDENTIFIER NULL,
    ManagerStartedOn DATE NULL,
    CONSTRAINT UQ_Warehouse_Name UNIQUE (Name),
    -- Filtered so several warehouses can wait for a manager (NULL) at the same time;
    -- a plain UNIQUE constraint allows only one NULL.
    INDEX UQ_Warehouse_ManagerMemberId UNIQUE NONCLUSTERED (ManagerMemberId)
        WHERE ManagerMemberId IS NOT NULL,
    CONSTRAINT CK_Warehouse_ManagerStartedOn CHECK
        ((ManagerMemberId IS NULL AND ManagerStartedOn IS NULL)
         OR (ManagerMemberId IS NOT NULL AND ManagerStartedOn IS NOT NULL))
);
GO

CREATE TABLE Inventory.Employee
(
    Id UNIQUEIDENTIFIER NOT NULL,
    WarehouseId INT NOT NULL,
    CONSTRAINT PK_Employee PRIMARY KEY (Id)
);
GO

CREATE TABLE Inventory.Category
(
    Id INT NOT NULL,
    NameEn VARCHAR(50) NOT NULL,
    NameAr NVARCHAR(50) NULL,
    CommissionRate DECIMAL(4,2) NOT NULL,
    ParentCategoryId INT NULL,
    CONSTRAINT PK_Category PRIMARY KEY (Id),
    CONSTRAINT UQ_Category_NameEn UNIQUE (NameEn),
    CONSTRAINT CK_Category_CommissionRate CHECK (CommissionRate BETWEEN 0 AND 30),
    CONSTRAINT CK_Category_ParentCategoryId CHECK (ParentCategoryId <> Id)
);
GO

CREATE TABLE Inventory.Item
(
    Id INT IDENTITY(1,1) CONSTRAINT PK_Item PRIMARY KEY,
    Title NVARCHAR(150) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    ConditionScore TINYINT NOT NULL
        CONSTRAINT CK_Item_ConditionScore CHECK (ConditionScore BETWEEN 1 AND 10),
    -- JSON document storage compatible with SQL Server 2019.
    Specifications NVARCHAR(MAX) NOT NULL
        CONSTRAINT CK_Item_Specifications CHECK (ISJSON(Specifications) = 1),
    SellerMemberId UNIQUEIDENTIFIER NOT NULL,
    InspectorMemberId UNIQUEIDENTIFIER NULL,
    CategoryId INT NOT NULL,
    WarehouseId INT NULL,
    ListedAt DATETIME2(3) NOT NULL
        CONSTRAINT DF_Item_ListedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_Item_InspectorMemberId CHECK (InspectorMemberId <> SellerMemberId)
);
GO

CREATE TABLE Inventory.ItemPhoto
(
    ItemId INT NOT NULL,
    Position TINYINT NOT NULL
        CONSTRAINT CK_ItemPhoto_Position CHECK (Position BETWEEN 1 AND 20),
    Url VARCHAR(500) NOT NULL,
    IsMain BIT NOT NULL CONSTRAINT DF_ItemPhoto_IsMain DEFAULT 0,
    CONSTRAINT PK_ItemPhoto PRIMARY KEY (ItemId, Position)
);
GO

CREATE TABLE Sales.Auction
(
    Id INT IDENTITY(1,1) CONSTRAINT PK_Auction PRIMARY KEY,
    ItemId INT NOT NULL,
    StartingPrice DECIMAL(12,2) NOT NULL
        CONSTRAINT CK_Auction_StartingPrice CHECK (StartingPrice > 0),
    ReservePrice DECIMAL(12,2) NULL,
    BidIncrement DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Auction_BidIncrement DEFAULT 50.00,
    StartsAt DATETIMEOFFSET(3) NOT NULL,
    EndsAt DATETIMEOFFSET(3) NOT NULL,
    Status VARCHAR(20) NOT NULL CONSTRAINT DF_Auction_Status DEFAULT 'Draft',
    CONSTRAINT CK_Auction_ReservePrice CHECK (ReservePrice >= StartingPrice),
    CONSTRAINT CK_Auction_BidIncrement CHECK (BidIncrement > 0),
    CONSTRAINT CK_Auction_EndsAt CHECK (EndsAt > StartsAt),
    CONSTRAINT CK_Auction_Status CHECK (Status IN ('Draft', 'Live', 'Ended', 'Cancelled'))
);
GO

CREATE TABLE Sales.Bid
(
    Id BIGINT IDENTITY(1,1) CONSTRAINT PK_Bid PRIMARY KEY,
    AuctionId INT NOT NULL,
    MemberId UNIQUEIDENTIFIER NOT NULL,
    Amount DECIMAL(12,2) NOT NULL CONSTRAINT CK_Bid_Amount CHECK (Amount > 0),
    PlacedAt DATETIME2(3) NOT NULL
        CONSTRAINT DF_Bid_PlacedAt DEFAULT SYSUTCDATETIME(),
    IpAddress VARCHAR(45) NOT NULL,
    CONSTRAINT UQ_Bid_AuctionId_Amount UNIQUE (AuctionId, Amount)
);
GO

CREATE TABLE Sales.AuctionFollower
(
    MemberId UNIQUEIDENTIFIER NOT NULL,
    AuctionId INT NOT NULL,
    FollowedAt DATETIME2(3) NOT NULL
        CONSTRAINT DF_AuctionFollower_FollowedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_AuctionFollower PRIMARY KEY (MemberId, AuctionId)
);
GO

USE BidNile;
GO
-- 3.1
ALTER TABLE [Identity].Member ADD CONSTRAINT FK_Member_City FOREIGN KEY (CityId) REFERENCES Location.City (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE [Identity].Member ADD CONSTRAINT FK_Member_Inviter FOREIGN KEY (InvitedByMemberId) REFERENCES [Identity].Member (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE [Identity].Wallet ADD CONSTRAINT FK_Wallet_Member FOREIGN KEY (Id) REFERENCES [Identity].Member (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.Warehouse ADD CONSTRAINT FK_Warehouse_City FOREIGN KEY (CityId) REFERENCES Location.City (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.Warehouse ADD CONSTRAINT FK_Warehouse_Employee FOREIGN KEY (ManagerMemberId) REFERENCES Inventory.Employee (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.Employee ADD CONSTRAINT FK_Employee_Member FOREIGN KEY (Id) REFERENCES [Identity].Member (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.Employee ADD CONSTRAINT FK_Employee_Warehouse FOREIGN KEY (WarehouseId) REFERENCES Inventory.Warehouse (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.Category ADD CONSTRAINT FK_Category_Category FOREIGN KEY (ParentCategoryId) REFERENCES Inventory.Category (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.Item ADD CONSTRAINT FK_Item_Member FOREIGN KEY (SellerMemberId) REFERENCES [Identity].Member (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.Item ADD CONSTRAINT FK_Item_Employee FOREIGN KEY (InspectorMemberId) REFERENCES Inventory.Employee (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.Item ADD CONSTRAINT FK_Item_Category FOREIGN KEY (CategoryId) REFERENCES Inventory.Category (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.Item ADD CONSTRAINT FK_Item_Warehouse FOREIGN KEY (WarehouseId) REFERENCES Inventory.Warehouse (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Inventory.ItemPhoto ADD CONSTRAINT FK_ItemPhoto_Item FOREIGN KEY (ItemId) REFERENCES Inventory.Item (Id) ON DELETE CASCADE;
GO
-- 3.1
ALTER TABLE Sales.Auction ADD CONSTRAINT FK_Auction_Item FOREIGN KEY (ItemId) REFERENCES Inventory.Item (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Sales.Bid ADD CONSTRAINT FK_Bid_Auction FOREIGN KEY (AuctionId) REFERENCES Sales.Auction (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Sales.Bid ADD CONSTRAINT FK_Bid_Member FOREIGN KEY (MemberId) REFERENCES [Identity].Member (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Sales.AuctionFollower ADD CONSTRAINT FK_AuctionFollower_Member FOREIGN KEY (MemberId) REFERENCES [Identity].Member (Id) ON DELETE NO ACTION;
GO
-- 3.1
ALTER TABLE Sales.AuctionFollower ADD CONSTRAINT FK_AuctionFollower_Auction FOREIGN KEY (AuctionId) REFERENCES Sales.Auction (Id) ON DELETE NO ACTION;
GO
-- 3.2
ALTER TABLE [Identity].Member ADD AppLanguage CHAR(2) NOT NULL CONSTRAINT DF_Member_AppLanguage DEFAULT 'ar' CONSTRAINT CK_Member_AppLanguage CHECK (AppLanguage IN ('ar','en'));
GO
-- 3.3
ALTER TABLE Inventory.Item ADD IsFeatured BIT NOT NULL CONSTRAINT DF_Item_IsFeatured DEFAULT 0;
GO
-- 3.4
EXEC sys.sp_rename N'Sales.Bid.IpAddress', N'DeviceIp', N'COLUMN';
GO
-- 3.4: sp_rename refuses a column that a CHECK depends on, so the CHECK is
-- dropped, the column renamed, and the CHECK added back under the new name.
ALTER TABLE Inventory.Warehouse DROP CONSTRAINT CK_Warehouse_Capacity;
GO
-- 3.4
EXEC sys.sp_rename N'Inventory.Warehouse.Capacity', N'MaxItems', N'COLUMN';
GO
-- 3.4
ALTER TABLE Inventory.Warehouse ADD CONSTRAINT CK_Warehouse_MaxItems CHECK (MaxItems > 0);
GO
-- 3.5
ALTER TABLE [Identity].Member ALTER COLUMN FullName NVARCHAR(150) NOT NULL;
GO
-- 3.6: ALTER COLUMN failed because CK_Warehouse_MaxItems depends on the column,
-- so the CHECK is dropped first and added back after the type change.
ALTER TABLE Inventory.Warehouse DROP CONSTRAINT CK_Warehouse_MaxItems;
GO
-- 3.6
ALTER TABLE Inventory.Warehouse ALTER COLUMN MaxItems SMALLINT NOT NULL;
GO
-- 3.6
ALTER TABLE Inventory.Warehouse ADD CONSTRAINT CK_Warehouse_MaxItems CHECK (MaxItems > 0 AND MaxItems <= 30000);
GO
-- 3.7: existing commission values must satisfy the new limit.
ALTER TABLE Inventory.Category DROP CONSTRAINT CK_Category_CommissionRate;
GO
-- 3.7
ALTER TABLE Inventory.Category ADD CONSTRAINT CK_Category_CommissionRate CHECK (CommissionRate BETWEEN 0 AND 25);
GO
-- 3.8
ALTER TABLE Sales.Auction DROP CONSTRAINT CK_Auction_Status, DF_Auction_Status;
GO
-- 3.8
ALTER TABLE Sales.Auction ADD CONSTRAINT CK_Auction_Status CHECK (Status IN ('Draft','Live','Ended','Cancelled','PendingReview')), CONSTRAINT DF_Auction_Status DEFAULT 'PendingReview' FOR Status;
GO
-- 3.9
ALTER TABLE Sales.Auction ADD BuyNowPrice DECIMAL(12,2) NULL;
GO
-- 3.9: WITH CHECK validates existing rows and keeps the constraint trusted.
-- Existing NULL prices pass; a supplied price must exceed StartingPrice.
ALTER TABLE Sales.Auction WITH CHECK ADD CONSTRAINT CK_Auction_BuyNowPrice CHECK (BuyNowPrice > StartingPrice);
GO
-- 3.10: resolve any existing duplicate mobiles before adding this constraint.
ALTER TABLE [Identity].Member ADD CONSTRAINT UQ_Member_Mobile UNIQUE (Mobile);
GO
-- 3.11
ALTER TABLE [Identity].Member ADD VerifiedAt DATETIME2(3) NULL;
GO
-- 3.11: DROP COLUMN failed because DF_Member_IsVerified is attached to it,
-- so the DEFAULT is dropped first.
ALTER TABLE [Identity].Member DROP CONSTRAINT DF_Member_IsVerified;
GO
-- 3.11
ALTER TABLE [Identity].Member DROP COLUMN IsVerified;
GO
-- 3.12
CREATE SCHEMA Marketing;
GO
-- 3.12
ALTER SCHEMA Marketing TRANSFER Sales.AuctionFollower;
GO


