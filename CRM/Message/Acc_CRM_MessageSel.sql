/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_MessageSel]
	@UserName VARCHAR(MAX)='',
	@IsTest bit = 0
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

	IF @UserName<>'' AND
		EXISTS (SELECT 1 
				FROM string_split(@UserName,',') t
				WHERE NOT EXISTS (SELECT 1 FROM DBCUST.Custdb.dbo.Customer c WITH (NOLOCK)
								  WHERE c.username=RTRIM(LTRIM(t.value)))
				)
		RETURN
	
	IF @IsTest=0	
	BEGIN
		SELECT m.MessageId, m.CreateTime, m.CreatorName, m.Remark Title, mt.TargetName
			, m.Content_en
			, ISNULL(m.Content_ch, m.Content_en) Content_ch
			, ISNULL(m.Content_cs, m.Content_en) Content_cs
			, ISNULL(m.Content_th, m.Content_en) Content_th
			, ISNULL(m.Content_vn, m.Content_en) Content_vn
		FROM Msg m WITH (NOLOCK)
		INNER JOIN MsgTarget mt WITH (NOLOCK) ON mt.MessageId=m.MessageId
		WHERE (@UserName='' 
		  OR mt.TargetName IN (SELECT RTRIM(LTRIM(value)) FROM string_split(@UserName,',')))
		  AND m.IsTest=@IsTest
		  AND MsgContentsType=100
	END
	ELSE 
	BEGIN
		SELECT m.MessageId, m.CreateTime, m.CreatorName, m.Remark Title, mt.TargetName
			, m.Content_en
			, ISNULL(m.Content_ch, m.Content_en) Content_ch
			, ISNULL(m.Content_cs, m.Content_en) Content_cs
			, ISNULL(m.Content_th, m.Content_en) Content_th
			, ISNULL(m.Content_vn, m.Content_en) Content_vn
		FROM Msg m WITH (NOLOCK)
		INNER JOIN MsgTarget mt WITH (NOLOCK) ON mt.MessageId=m.MessageId
		WHERE (@UserName='' 
		  OR mt.TargetName IN (SELECT RTRIM(LTRIM(value)) FROM string_split(@UserName,',')))
		  AND MsgContentsType=100
	END
END
GO