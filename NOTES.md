# NOTES

## 1. The 4 schemas

| Schema | Tables | Why |
|---|---|---|
| `Location` | City | Geography shared by members and warehouses. |
| `Identity` | Member, Wallet | Who the user is and the money they hold. A wallet only exists with its account. |
| `Inventory` | Warehouse, Employee, Category, Item, ItemPhoto | Physical goods, where they are stored and the staff who handle them. |
| `Sales` | Auction, Bid, AuctionFollower | Selling: auctions and everything members do on them. |

In 3.12 `AuctionFollower` moved to a fifth schema, `Marketing`, because marketing now owns engagement data.

## 2. Relationship types

| Type | Where | How it is mapped |
|---|---|---|
| 1:1 | Member and Wallet | `Wallet.Id` is the PK **and** the FK to `Member.Id`, so a member cannot have two wallets. The same pattern makes `Employee` a member subtype (`Employee.Id` → `Member.Id`). |
| 1:N | City → Member, City → Warehouse, Category → Item, Warehouse → Item, Item → Auction, Auction → Bid | FK column on the "many" side, e.g. `Member.CityId`. An item can be re-auctioned, so `Auction.ItemId` is not unique. |
| M:N | Members bid on auctions; members follow auctions | `Bid` links Member and Auction and has its own `Id`, because one member can bid many times on one auction. `AuctionFollower` has a composite PK `(MemberId, AuctionId)`, so nobody follows the same auction twice. |
| Recursive | Member invites Member; Category under Category | `Member.InvitedByMemberId` → `Member.Id` (nullable, a single column, so one inviter at most). `Category.ParentCategoryId` → `Category.Id` (NULL for top-level categories). |
| Circular | Employee works in Warehouse; Warehouse managed by Employee | `Employee.WarehouseId` → `Warehouse.Id` and `Warehouse.ManagerMemberId` → `Employee.Id`. The manager column has a unique index filtered on `IS NOT NULL`, so a person manages one warehouse at most while several warehouses can still be waiting for a manager. |
| Weak entity | ItemPhoto | Identified by `(ItemId, Position)`. `FK_ItemPhoto_Item` is `ON DELETE CASCADE`, so photos disappear with their item. |

The seller and inspector of an item are both members (`SellerMemberId` → Member, `InspectorMemberId` → Employee). `CK_Item_InspectorMemberId` makes sure they are never the same person.

## 3. Data type choices

- **GUID for members:** the mobile app creates the ID on the phone before the server sees it. Only a globally unique value is safe there, and a running number would need the server. `DEFAULT NEWID()` covers sign-ups that arrive without an ID.
- **BIGINT for bids:** `INT` stops at 2,147,483,647, and the business expects to pass 2.1 billion bids within a few years.
- **FLOAT for GPS:** the map provider gives approximate measurements with many decimals. We never need exact equality on a coordinate.
- **DECIMAL for money:** money must be exact. `FLOAT` would give rounding errors. `DECIMAL(12,2)` holds up to 9,999,999,999.99.
- **DATETIMEOFFSET for auctions:** members are in +02:00, +03:00 and +04:00. The offset is stored with the value, so "18:30 +04:00" stays a Dubai time and auctions in different zones still compare correctly.

## 4. Why the circular relationship cannot go inside CREATE TABLE

A foreign key can only reference a table that already exists. Whichever of Warehouse or Employee is created first would reference a table that is not there yet. So both tables are created with plain columns and the two FKs are added afterwards with `ALTER TABLE` (3.1). The same problem appears with data: a warehouse is saved first with no manager, then its employees, and only then is the manager set.

## 5. The order I filled the tables in

1. `City` and the top-level categories (100, 200, 300). They reference nothing.
2. The members who joined without an invitation, and the child categories (110, 210, 220), whose parents now exist.
3. The invited members (their inviters now exist) and the warehouses, with no manager yet.
4. Wallets (need members) and employees (need members and warehouses).
5. The warehouse managers, set in Edit Top 200 Rows now that the employees exist.
6. Items (need seller, inspector, category and warehouse).
7. Item photos and auctions (need items).
8. Bids and followers (need auctions and members).

The FKs were already on, so a table could only be filled after every table it points to.

## 6. Errors in 3.6 and 3.11

- **3.6:** `ALTER COLUMN MaxItems SMALLINT` failed: *"The object 'CK_Warehouse_MaxItems' is dependent on column 'MaxItems'"*. A column cannot change type while a CHECK depends on it. Fix: drop the CHECK, change the type, then add it back as `MaxItems > 0 AND MaxItems <= 30000`. `SMALLINT` (max 32,767) is the smallest type that fits 30,000. The same dependency also blocked the rename in 3.4: `sp_rename` refuses a column a CHECK depends on, so there the CHECK is dropped, the column renamed, and the CHECK re-added under the new name.
- **3.11:** `DROP COLUMN IsVerified` failed: *"The object 'DF_Member_IsVerified' is dependent on column 'IsVerified'"*. The DEFAULT constraint is attached to the column. Fix: drop `DF_Member_IsVerified` first, then drop the column.

## 7. Hand trace for Task 5: `[1, 2, 3, 4]`

`prefix[i]` = product of everything **before** i, `suffix[i]` = product of everything **after** i.

| i | nums[i] | prefix[i] | suffix[i] | result = prefix × suffix |
|---|---|---|---|---|
| 0 | 1 | 1 | 2·3·4 = 24 | 24 |
| 1 | 2 | 1 | 3·4 = 12 | 12 |
| 2 | 3 | 1·2 = 2 | 4 | 8 |
| 3 | 4 | 1·2·3 = 6 | 1 | 6 |

The O(1) version gives the same numbers. The first pass writes the prefixes into `result` → `[1, 1, 2, 6]`. The second pass goes right to left with one running `suffix` (1 → 4 → 12 → 24) and multiplies it in → `[24, 12, 8, 6]`.
