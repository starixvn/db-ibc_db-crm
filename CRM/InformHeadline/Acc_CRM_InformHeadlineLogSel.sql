/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE [bodb_CRM]
GO
CREATE PROCEDURE [dbo].[Acc_CRM_InformHeadlineLogSel]
	@TitleID		INT,
	@PageIndex		INT = 1, 
	@ItemsPerPage	INT = 100,	
	@ErrCode		INT	= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT,
	@TotalRows		INT = 0 OUTPUT
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
	IF ISNULL(@TotalRows,0)=0
	BEGIN
		SELECT	@TotalRows=COUNT(1)
		FROM crmInformHeadline_Log hl WITH(NOLOCK)
			INNER JOIN 	[dbo].[crmInformHeadline_History] hi WITH(NOLOCK) ON hl.LogID=hi.LogID		
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON hl.EditedBy=c.custid
		WHERE hl.TitleID=@TitleID
		GROUP BY hl.LogID,hl.LogDate,c.username
	END
	SELECT	ID, LogID, username, LogDate,NumAcc				
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY hl.LogID DESC) AS ID,
						hl.LogDate , 
						hl.LogID,
						c.username,
						Count(hi.HeadlineID) AS NumAcc
				FROM crmInformHeadline_Log hl WITH(NOLOCK)
					INNER JOIN 	[dbo].[crmInformHeadline_History] hi WITH(NOLOCK) ON hl.LogID=hi.LogID		
					INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON hl.EditedBy=c.custid
				WHERE hl.TitleID=@TitleID
				GROUP BY hl.LogID,hl.LogDate,c.username
				)tmp
		WHERE ID BETWEEN @PageIndex*@ItemsPerPage-@ItemsPerPage+1 AND @PageIndex*@ItemsPerPage

END