/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER  FUNCTION [dbo].[f_GetDescriptionByFeedbackID]   
( 
	@FeedbackID INT
)  
RETURNS @tbFeedbackSetting TABLE (AutoField NVARCHAR(MAX),Remark NVARCHAR(MAX))
AS
/*
Created: 
Task : Get description
DB: DBCRM.bodb_CRM

Revisions:
	- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
	Param's Explanation:
*/
BEGIN
	DECLARE   @AutoField       NVARCHAR(MAX)
			, @Remark		   NVARCHAR(MAX)
			, @xmlDoc		   XML
	DECLARE @iDoc AS INT
	SELECT @xmlDoc=CAST(Description AS XML)
	FROM crmfeedback WITH(NOLOCK) WHERE FeedbackID = @FeedbackID

	EXECUTE	sp_xml_preparedocument @iDoc OUTPUT, @xmlDoc;

	SELECT	@AutoField=ox.AutoField,@Remark=ox.Remark
	FROM OPENXML (@iDoc, '/ROOT/row', 1) 
	WITH (
		AutoField		NVARCHAR(MAX)
	,	Remark			NVARCHAR(MAX)	
	) AS ox;
	
	INSERT INTO @tbFeedbackSetting(AutoField,Remark)
	SELECT @AutoField,@Remark	
	RETURN
END
GO