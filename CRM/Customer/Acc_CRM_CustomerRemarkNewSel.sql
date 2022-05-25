/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROC Acc_CRM_CustomerRemarkNewSel
	@CustID		INT,
	@UserRole   TINYINT
AS

/*
Created: Winfred
Date: 20220315
Task : Special remarks renovation get log
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20220315@Winfred: Special remarks renovation  [RedmineID:#167941]   
Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
	SELECT TOP 5 a.Remark ,a.RemarkID ,a.CustID ,a.Remark ,a.RemarkTitle ,a.RelatedPICs ,
				a.HandlerID ,a.Ext ,a.Requester ,a.ApproverID ,a.AcknowledgerID ,
				a.ModifierID ,a.LastUpdate, a.CreatorID, a.CreatedDate, b.UserName,
				c.SettingValue AS RemarkName,e.UserName AS Creator, (CASE WHEN  d.custid IS NOT NULL THEN 1 ELSE 0 END) AS IsGroupHeadLine
    FROM crmCustomerRemarkNew a WITH(NOLOCK) 
		INNER JOIN crmCustomer b WITH(NOLOCK) ON a.CustID=b.CustID
		LEFT JOIN crmSetting c WITH(NOLOCK) ON a.RemarkTitle= c.SettingID AND c.SettingName = 'RemarkTitles'
		LEFT JOIN DBACC.bodb02.dbo.Custinfo e WITH(NOLOCK) ON a.CreatorID= e.CustID
		LEFT JOIN bodb02.dbo.CustAccount d WITH(NOLOCK) ON a.custid = d.custid AND d.IsGroupHeadLine = 1
	WHERE a.CustID = @CustID 
		AND((@UserRole=1 AND b.SiteID=33002) OR(@UserRole=2 AND ISNULL(b.SiteID,0) <>33002))
	ORDER BY a.CreatedDate DESC, a.RemarkID 
END
GO 
