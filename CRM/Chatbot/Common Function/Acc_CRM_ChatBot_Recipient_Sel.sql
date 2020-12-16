/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_Recipient_Sel]
	@RecipientType	TINYINT = NULL
	,@RecipientName NVARCHAR(200) = ''
	,@RecipientIds  VARCHAR(MAX) = ''
	,@Limit			INT = NULL	
AS
/*
Created: 20200810@Malcolm
Task :  Get recipients
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
		- 20201126@Malcolm: Change bodb02.dbo.f_StringSplit to dbo.f_CRM_strSplit [Redmine: #144265]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT @RecipientName = ISNULL(@RecipientName,'')

	DECLARE @SettingLetStalk INT
	DECLARE @Tmp TABLE
	(
		RecipientId		INT
		,RecipientName	NVARCHAR(200)
		,LetsTalkIds		NVARCHAR(200)
		,RowNum			INT
	)
	
	SELECT  @SettingLetStalk = SettingId FROM dbo.crmSetting WITH (NOLOCK)
	WHERE	SettingName = 'PICCommunicationTool' AND SettingValue = 'LetsTalk' AND IsActive = 1

	INSERT INTO @Tmp
	(
		RecipientId
		,RecipientName
		,LetsTalkIds 
		,RowNum
	)
	SELECT 
		r.RecipientId
		,p.Username AS RecipientName
		,c.CommunicationValue
		,ROW_NUMBER() OVER(ORDER BY p.Username)
	FROM dbo.crmRecipient r WITH(NOLOCK)
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId AND p.IsActive = 1
		LEFT JOIN dbo.crmPICCommunication c WITH(NOLOCK) ON c.PicID = p.PicID AND c.CommunicationID = @SettingLetStalk
	WHERE (r.RecipientTypeId = @RecipientType OR @RecipientType IS NULL)
		AND (p.Username LIKE '%' + @RecipientName + '%' OR @RecipientName IS NULL)	
		AND (EXISTS(SELECT 1 
					FROM dbo.f_CRM_strSplit(@RecipientIds, ',') f 
					WHERE f.val = r.RecipientId
			) OR @RecipientIds = '')
		AND r.DataSource = 'bodb_CRM.dbo.crmPIC'

	SELECT 
		RecipientId
		,RecipientName
		,LetsTalkIds
	FROM @Tmp
	WHERE (RowNum <= @Limit OR @Limit IS NULL)

END
GO