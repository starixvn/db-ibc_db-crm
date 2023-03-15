/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PersonalMessageSel]
	@UserName	VARCHAR(MAX)='',
	@FromDate	DATETIME=NULL,
	@ToDate		DATETIME=NULL,
	@IsTest		BIT = 0,
	@PageSize	INT	=	50,
	@PageIndex	INT	=	0,
	@TotalRows 	INT	=	0 OUTPUT
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

	CREATE TABLE #MsgTmp (
		  RowID			INT IDENTITY (1,1)
		, MessageId		INT
		, Content_en	NVARCHAR(4000)
		, Content_cs	NVARCHAR(4000)
		, Content_ch	NVARCHAR(4000)
		, Content_th	NVARCHAR(4000)
		, Content_vn	NVARCHAR(4000)
		, CreateTime	DATETIME
		, CreatorName	VARCHAR(50)
		, Title			VARCHAR(300)
		, TargetNames	NVARCHAR(4000)	
	)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1, 
			@RowEnd = @RowStart + @PageSize - 1 	

	IF @IsTest=0	
	BEGIN
		INSERT INTO #MsgTmp (MessageId, CreateTime, CreatorName, Title, Content_en, Content_ch, Content_cs, Content_th, Content_vn, TargetNames)
		SELECT m.MessageId, m.CreateTime, m.CreatorName, m.Remark Title
			, m.Content_en
			, ISNULL(m.Content_ch, m.Content_en) Content_ch
			, ISNULL(m.Content_cs, m.Content_en) Content_cs
			, ISNULL(m.Content_th, m.Content_en) Content_th
			, ISNULL(m.Content_vn, m.Content_en) Content_vn
			, STUFF ((SELECT ', ' + TargetName
					  FROM MsgTarget mt
					  WHERE mt.MessageId=m.MessageId AND mt.isDeleted=0
						AND (@UserName='' 
						  OR TargetName IN (SELECT RTRIM(LTRIM(value)) FROM string_split(@UserName,',')))
					  FOR XML PATH('')),1,1,'') AS TargetName
		FROM Msg m WITH (NOLOCK)
		WHERE m.IsTest=@IsTest
		  AND MsgContentsType=100
		  AND m.isDeleted=0
		GROUP BY m.MessageId, m.CreateTime, m.CreatorName, m.Remark
				, m.Content_en
				, ISNULL(m.Content_ch, m.Content_en) 
				, ISNULL(m.Content_cs, m.Content_en) 
				, ISNULL(m.Content_th, m.Content_en) 
				, ISNULL(m.Content_vn, m.Content_en) 
	END
	ELSE 
	BEGIN
		INSERT INTO #MsgTmp (MessageId, CreateTime, CreatorName, Title, Content_en, Content_ch, Content_cs, Content_th, Content_vn, TargetNames)
		SELECT m.MessageId, m.CreateTime, m.CreatorName, m.Remark Title
			, m.Content_en
			, ISNULL(m.Content_ch, m.Content_en) Content_ch
			, ISNULL(m.Content_cs, m.Content_en) Content_cs
			, ISNULL(m.Content_th, m.Content_en) Content_th
			, ISNULL(m.Content_vn, m.Content_en) Content_vn
			, STUFF ((SELECT ', ' + TargetName
					  FROM MsgTarget mt
					  WHERE mt.MessageId=m.MessageId AND mt.isDeleted=0
						AND (@UserName='' 
						  OR TargetName IN (SELECT RTRIM(LTRIM(value)) FROM string_split(@UserName,',')))
					  FOR XML PATH('')),1,1,'') AS TargetName
		FROM Msg m WITH (NOLOCK)
		WHERE MsgContentsType=100
		  AND isDeleted=0
		GROUP BY m.MessageId, m.CreateTime, m.CreatorName, m.Remark
				, m.Content_en
				, ISNULL(m.Content_ch, m.Content_en) 
				, ISNULL(m.Content_cs, m.Content_en) 
				, ISNULL(m.Content_th, m.Content_en) 
				, ISNULL(m.Content_vn, m.Content_en) 
	END

	SELECT MessageId, CreateTime, CreatorName, Title, Content_en, Content_ch, Content_cs, Content_th, Content_vn, TargetNames
	FROM #MsgTmp
	ORDER BY MessageId DESC

	SELECT @TotalRows = COUNT(1) FROM #MsgTmp
END
GO