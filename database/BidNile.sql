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
    CONSTRAINT UQ_Warehouse_ManagerMemberId UNIQUE (ManagerMemberId),
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
