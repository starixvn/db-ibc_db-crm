/*<info serverAlias="DBCUST-CustDB"></info>*/
/*
	Created: 20200710@Percy
	DB: DBCUST-CustDB
	Task: Correct data for dummy account
		-- Dummy agent: 339BHK - remove from CustAccount, add into Acc_CustDirect
		-- Dummy super: SA-US$789y -- add into Acc_CustDirect
*/

USE CustDB
GO

DELETE dbo.custAccount WITH (ROWLOCK, UPDLOCK)
WHERE custid = 1412 -- 339BHK (dummy agent)

INSERT INTO dbo.Acc_CustDirect (custid, roleid)
VALUES (1412, 2) -- 339BHK (dummy agent)
		,(21278849, 4) -- SA-US$789y (dummy super)
