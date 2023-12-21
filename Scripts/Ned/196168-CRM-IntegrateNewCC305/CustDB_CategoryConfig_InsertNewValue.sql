/*<info serverAlias="DBCUST-CustDB"></info>*/

/*
Created: 20231213@Ned.Le
DB:      DBCUST.CustDB
Task:    Insert new value on table CategoryConfig
*/

USE CustDB
GO

INSERT INTO dbo.CategoryConfig (CategoryID, CategoryName, OfferDeposit, CategoryNameCS, CustomerClass, HiddenSite) VALUES
(64,  'System Detect Unauthorized Login',          1, N'系统侦测軟件登入',      305,  0),
(104, 'System Detect Unauthorized Login (Losing)', 1, N'系统侦测軟件登入（输钱)', 3005, 1)
GO