/*<info serverAlias="DBCUST-CustDB"></info>*/

/*
	Created: 20230515@Malcolm
	DB: DBCUST-CustDB
	Task: Add customer class Setting for CRM

*/
INSERT INTO dbo.CategoryConfig (CategoryID, CategoryName, OfferDeposit, CategoryNameCS, CustomerClass, HiddenSite)
VALUES 
	(165, 'Odds Crawler Robot', 1, N'机械爬虫', 3100, 0)
	,(166, 'Odds Crawler Robot (Losing)', 1, N'机械爬虫 (输钱)', 3200, 0)
