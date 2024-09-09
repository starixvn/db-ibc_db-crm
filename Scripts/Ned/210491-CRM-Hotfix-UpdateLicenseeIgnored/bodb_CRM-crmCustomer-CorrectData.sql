/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20240909@Ned.Le
DB: DBCRM.bodb_CRM
Task: Correct data for column Ignored in table crmCustomer
*/


USE bodb_CRM
GO

UPDATE cr
SET cr.Ignored = 0
FROM bodb_CRM.dbo.crmCustomer cr WITH (UPDLOCK, TABLOCK)
WHERE EXISTS (SELECT TOP 1 1
              FROM bodb02.dbo.Dep_CustSuper cs WITH (NOLOCK)
              WHERE cr.CustID = cs.CustID)
      AND cr.Ignored = 1
GO