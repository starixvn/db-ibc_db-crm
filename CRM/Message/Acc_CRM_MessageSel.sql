/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_MessageSel]
	@UserName	VARCHAR(MAX)='',
	@FromDate	DATETIME=NULL,
	@ToDate		DATETIME=NULL,
	@IsTest		BIT = 0
AS
/*
	Created: 20230308@Tacy
    Task: CRM - Sending Personal Message to SMA in Alpha site
    DB: DBMSG-bodb_Message

	Revisions:
		- 20230308@Tacy: Create SP

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF @IsTest=0	
	BEGIN
		SELECT m.MessageId, m.CreateTime, m.CreatorName, m.Remark Title
			, m.Content_en
			, ISNULL(m.Content_ch, m.Content_en) Content_ch
			, ISNULL(m.Content_cs, m.Content_en) Content_cs
			, ISNULL(m.Content_th, m.Content_en) Content_th
			, ISNULL(m.Content_vn, m.Content_en) Content_vn
			, STUFF ((SELECT ', ' + TargetName
					  FROM MsgTarget t
					  WHERE t.MessageId=m.MessageId
						AND (@UserName='' 
						  OR TargetName IN (SELECT RTRIM(LTRIM(value)) FROM string_split(@UserName,',')))
					  FOR XML PATH('')),1,1,'') AS TargetName
		FROM Msg m WITH (NOLOCK)
		WHERE m.IsTest=@IsTest
		  AND MsgContentsType=100
		GROUP BY m.MessageId, m.CreateTime, m.CreatorName, m.Remark
				, m.Content_en
				, ISNULL(m.Content_ch, m.Content_en) 
				, ISNULL(m.Content_cs, m.Content_en) 
				, ISNULL(m.Content_th, m.Content_en) 
				, ISNULL(m.Content_vn, m.Content_en) 
		ORDER BY M.MessageId
	END
	ELSE 
	BEGIN
		SELECT m.MessageId, m.CreateTime, m.CreatorName, m.Remark Title
			, m.Content_en
			, ISNULL(m.Content_ch, m.Content_en) Content_ch
			, ISNULL(m.Content_cs, m.Content_en) Content_cs
			, ISNULL(m.Content_th, m.Content_en) Content_th
			, ISNULL(m.Content_vn, m.Content_en) Content_vn
			, STUFF ((SELECT ', ' + TargetName
					  FROM MsgTarget t
					  WHERE t.MessageId=m.MessageId
						AND (@UserName='' 
						  OR TargetName IN (SELECT RTRIM(LTRIM(value)) FROM string_split(@UserName,',')))
					  FOR XML PATH('')),1,1,'') AS TargetName
		FROM Msg m WITH (NOLOCK)
		WHERE MsgContentsType=100
		GROUP BY m.MessageId, m.CreateTime, m.CreatorName, m.Remark
				, m.Content_en
				, ISNULL(m.Content_ch, m.Content_en) 
				, ISNULL(m.Content_cs, m.Content_en) 
				, ISNULL(m.Content_th, m.Content_en) 
				, ISNULL(m.Content_vn, m.Content_en) 
		ORDER BY M.MessageId
	END
END
GO