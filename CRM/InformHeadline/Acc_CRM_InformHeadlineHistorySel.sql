/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE [bodb_CRM]
GO
CREATE PROCEDURE [dbo].[Acc_CRM_InformHeadlineHistorySel]
	@LogID			INT,
	@PageIndex		INT = 1, 
	@ItemsPerPage	INT = 100,	
	@ErrCode		INT	= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT	
AS	
/*
	Created: Winnie
	Date: 2019-07-31
	Task: Select inform headline log
	DB: DBCRM/bodb_CRM
		
	Revisions:
		- 20190711@Winnie: CRM - Enhance Inform Headline RedmineID:##109775
	Parameter's Explanation:				

*/
BEGIN
	SELECT	ID, HeadlineID, DirectAcc, Handler,Remark,UpdatedTime,Status,ProductStatus,Extension		
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY HeadLineID DESC) AS ID,
						hi.HeadlineID,
						h.username	AS DirectAcc,
						ha.username AS Handler,
						hi.Remark,
						hi.UpdatedTime,
						hs.SettingName AS Status,
						ps.SettingName AS ProductStatus,
						e.SettingName AS Extension
				FROM [dbo].[crmInformHeadline_History] hi WITH(NOLOCK)
					INNER JOIN bodb02.dbo.Customer h WITH(NOLOCK) ON hi.[HeadlineID]=h.custid
					INNER JOIN crmSetting hs WITH(NOLOCK) ON hi.InformHeadlineStatusID=hs.SettingID
					INNER JOIN crmSetting ps WITH(NOLOCK) ON hi.ProductStatus=ps.SettingID
					INNER JOIN crmSetting e WITH(NOLOCK) ON hi.ProductStatus=e.SettingID
					INNER JOIN bodb02.dbo.Customer ha WITH(NOLOCK) ON hi.[HeadlineID]=ha.custid
				WHERE hi.LogID=@LogID
				GROUP BY hi.LogID
				)tmp
		WHERE ID BETWEEN @PageIndex*@ItemsPerPage-@ItemsPerPage+1 AND @PageIndex*@ItemsPerPage
END