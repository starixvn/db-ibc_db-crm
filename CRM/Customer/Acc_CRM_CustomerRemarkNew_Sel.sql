/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROC Acc_CRM_CustomerRemarkNew_Sel
	@CustID		INT,
	@UserRole   TINYINT
AS

/*
Created: Dom
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
	- 20201120@Johnson: check incase SiteID = NULL  [redmine:#145439]
	- 20220315@Winfred: Special remarks renovation  [RedmineID:#167941]   
Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
	SELECT TOP 5 a.Remark ,a.RemarkID ,a.CustID ,a.Remark ,a.RemarkTitle ,a.RelatedPICs ,
				a.HandlerID ,a.Ext ,a.Requester ,a.ApproverID ,a.AcknowledgerID ,
				a.UpdaterID ,a.LastUpdate, a.CreatorID, a.CreatedDate, b.UserName,
				c.SettingValue AS RemarkName,e.UserName AS Creator
    FROM crmCustomerRemarkNew a WITH(NOLOCK) 
		INNER JOIN crmCustomer b WITH(NOLOCK) ON a.CustID=b.CustID
		LEFT JOIN crmSetting c WITH(NOLOCK) ON a.RemarkTitle= c.SettingID AND c.SettingName = 'RemarkTitles'
		LEFT JOIN crmCustomer e WITH(NOLOCK) ON a.CreatorID= e.CustID
	WHERE a.CustID = @CustID 
		AND((@UserRole=1 AND b.SiteID=33002) OR(@UserRole=2 AND ISNULL(b.SiteID,0) <>33002))
	ORDER BY a.CreatedDate DESC, a.RemarkID 
END
GO 
