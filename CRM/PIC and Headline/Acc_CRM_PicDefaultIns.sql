/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicDefaultIns]
	@HeadlineID		INT,
	@DefaultPicIDs	NVARCHAR(200) ,
	@UserID			INT,
	@LoginIP        VARCHAR(20) =''
AS
/*
Created: 20200717@Malcolm
Task :  Get default PICs of a headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200717@Malcolm: Get default PICs of a headline [Redmine: #137144]
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON

	DELETE dbo.crmPICDefault
	WHERE HeadlineID = @HeadlineID

	INSERT INTO dbo.crmPICDefault (HeadlineID, PicID)
	SELECT DISTINCT @HeadlineID, s.val AS PicID
	FROM bodb02.dbo.strSplit(@DefaultPicIDs,',') s

END
GO
