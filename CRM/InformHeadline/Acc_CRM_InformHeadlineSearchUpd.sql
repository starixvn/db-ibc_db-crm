/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineSearchUpd]
	@TitleID		INT,
	@Title			NVARCHAR(2000) = '',
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@ExcludeIgnored	BIT=0,
	@ChangeFilter	BIT, 	
	@Content		XML = '',
	@UserID			INT,
	@IP				VARCHAR(40),
	@ErrCode		INT	= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT	
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Update inform headline
	DB: DBCRM/bodb_CRM
		
	Revisions:
		- 20150706@Elodie: Exclude NULL value to compare data (Redmine: #38953)
		- 20161005@Winnie: Include 'Checker' and 'Ignored Accounts' RedmineID: #64067
		- 20190307@Winnie: Remove vnteam, add metadata RedmineID: #109775
		- 20190729@Winnie: Change function edit inform headline RedmineID: #109775
	Parameter's Explanation:				
		- @TypeAccount =1: Headline
						2: Direct account
						3: Both
		- @ChangeFilter =0: Not change
						=1: Change filter
	Example:  EXEC Acc_CRM_InformHeadlineSearchUpd @TitleID = 1, @Currency = '20,10,2', @Level = '3,4', @Site = 'BEST-ODDS,722222,222223', @TypeAccount = 3, @ChangeFilter = 0
*/
BEGIN
	SET NOCOUNT ON
	IF @Currency = '' OR @Level = '' OR @Site = ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'At least 1 option is selected.'
		RETURN
	END	
	DECLARE @LogID INT

	DECLARE @HeadlineData TABLE(HeadlineID INT, GroupID INT, InformHeadlineStatusID INT, Remark NVARCHAR(4000), Extension INT, ProductStatus INT)
	DECLARE @HeadlineDataOld TABLE(InformHeadlineID INT,HeadlineID INT,TitleID INT, InformHeadlineStatusID INT,GroupID INT,UpdatedTime DATETIME, Remark NVARCHAR(4000), Handler INT, Extension INT, ProductStatus INT, IsInform BIT)
	DECLARE @HeadlineDataDelete TABLE(InformHeadlineID INT,HeadlineID INT,TitleID INT, InformHeadlineStatusID INT,GroupID INT,UpdatedTime DATETIME, Remark NVARCHAR(4000), Handler INT, Extension INT, ProductStatus INT, IsInform BIT)

	--Infomation which user input 
	INSERT INTO @HeadlineData(HeadlineID,GroupID,InformHeadlineStatusID,Remark,Extension,ProductStatus)
	SELECT	xmlData.Col.value('@HeadlineID','INT') HeadlineID,
			xmlData.Col.value('@GroupID','INT') GroupID,
			xmlData.Col.value('@StatusID','INT') InformHeadlineStatusID,
			dbo.[f_EncodeXMLValue](xmlData.Col.value('@Remark','NVARCHAR(4000)')) Remark,
			ISNULL(xmlData.Col.value('@Extension','INT'),0) Extension,
			ISNULL(xmlData.Col.value('@ProductStatus','INT'),0) ProductStatus		
	FROM @Content.nodes('//Content/Headline') xmlData(Col)			

	DECLARE @Filter VARCHAR(4000), @Old_Filter XML, @Old_Title NVARCHAR(2000), @Old_Site VARCHAR(4000), @Old_Currency VARCHAR(1000), @Old_Level VARCHAR(10), @Old_TypeAccount TINYINT,@Old_ExcludeIgnored BIT
	
	SELECT @Filter = '<Filters Site = ''' + @Site + ''' Position  = ''' + @Level + ''' Currency  = ''' + @Currency + ''' DirectAccount  = ''' + CONVERT(VARCHAR(1),@TypeAccount)+ ''' ExcludeIgnored  = ''' + CONVERT(VARCHAR(1),@ExcludeIgnored)  + '''></Filters>'
	SELECT @Old_Title = Title, @Old_Filter = Filter FROM crmInformTitle_New WITH (NOLOCK) WHERE TitleID = @TitleID

	SELECT	@Old_Site = xmlData.Col.value('@Site','VARCHAR(4000)'),
			@Old_Level = xmlData.Col.value('@Position','VARCHAR(10)'),
			@Old_Currency = xmlData.Col.value('@Currency','VARCHAR(1000)'),			
			@Old_TypeAccount = xmlData.Col.value('@DirectAccount','TINYINT'),
			@Old_ExcludeIgnored = xmlData.Col.value('@ExcludeIgnored','BIT')
	FROM @Old_Filter.nodes('//Filters') xmlData(Col)	
	
	IF @ChangeFilter = 1 OR @Old_Title <> @Title
	BEGIN
		UPDATE crmInformTitle_New WITH (ROWLOCK, UPDLOCK)
		SET Title = @Title, 
			Creator = @UserID,
			Filter = @Filter
		WHERE TitleID = @TitleID

		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 102
			SELECT @ErrMsg = 'Update case unsuccessfuly.'
			RETURN
		END			
	END	

	IF @ChangeFilter = 0 
		AND  @Old_Title = @Title
		AND NOT EXISTS (SELECT 1 FROM @HeadlineData) 	
	BEGIN
		RETURN		
	END	
	INSERT INTO @HeadlineDataOld(InformHeadlineID,HeadlineID,GroupID,InformHeadlineStatusID,Remark,Extension,ProductStatus)
	SELECT InformHeadlineID,HeadlineID,GroupID,InformHeadlineStatusID,Remark,Extension,ProductStatus
	FROM [dbo].[crmInformHeadline_New] WITH(NOLOCK) WHERE TitleID=@TitleID

	UPDATE h
		SET h.InformHeadlineStatusID=t.InformHeadlineStatusID,
			h.GroupID=t.GroupID,
			h.UpdatedTime=GETDATE(),
			h.Remark=t.Remark,
			h.Handler=@UserID,
			h.Extension=t.Extension,
			h.ProductStatus=t.ProductStatus,
			h.IsInform=1
	FROM [dbo].[crmInformHeadline_New] h WITH(ROWLOCK,UPDLOCK)		
		INNER JOIN @HeadlineData t ON h.[HeadlineID]=t.[HeadlineID]

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Update unsuccessfuly.'
		RETURN
	END

	DELETE h
	OUTPUT  DELETED.* INTO @HeadlineDataDelete  
	FROM [dbo].[crmInformHeadline_New] h WITH(ROWLOCK,UPDLOCK)
		LEFT JOIN @HeadlineData ot  ON h.HeadlineID=ot.HeadlineID	
	WHERE h.TitleID=@TitleID AND ot.HeadlineID IS NULL	

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Delete unsuccessfuly.'
		RETURN
	END

	INSERT INTO [crmInformHeadline_New](HeadlineID,TitleID,InformHeadlineStatusID,GroupID,UpdatedTime,Remark,Handler,Extension,ProductStatus,IsInform)
	SELECT t.HeadlineID,@TitleID,t.InformHeadlineStatusID,t.GroupID,GETDATE(),t.Remark,@UserID,t.Extension,t.ProductStatus,1
	FROM @HeadlineData t
		LEFT JOIN [crmInformHeadline_New] h WITH(NOLOCK) ON t.HeadlineID=h.HeadlineID
	WHERE h.HeadlineID IS NULL

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Insert unsuccessfuly.'
		RETURN
	END
	IF EXISTS(SELECT TOP 1 1 FROM @HeadlineDataDelete
		WHERE InformHeadlineStatusID<>45006 OR (Extension<>0 AND Extension<>2022) OR ProductStatus<>0 OR ISNULL(Remark,'')<>'')
		OR
		EXISTS(SELECT TOP 1 1 FROM @HeadlineDataDelete hd
		INNER JOIN @HeadlineData h ON hd.HeadlineID=h.HeadlineID
		WHERE h.InformHeadlineStatusID<>hd.InformHeadlineStatusID OR h.Extension<>hd.Extension OR h.ProductStatus<>hd.ProductStatus OR hd.Remark<>h.Remark)
	BEGIN
		INSERT INTO [dbo].[crmInformHeadline_Log]([LogDate],EditedBy,TitleID)
		SELECT GETDATE(),@UserID,@TitleID
		SELECT @LogID=@@IDENTITY
		INSERT INTO [dbo].[crmInformHeadline_History](LogID,HeadlineID,InformHeadlineStatusID,GroupID,UpdatedTime,Remark,Handler,Extension,ProductStatus,IsInform)
		SELECT @LogID,HeadlineID,InformHeadlineStatusID,GroupID,UpdatedTime,Remark,Handler,Extension,ProductStatus,IsInform
		FROM @HeadlineDataDelete
			WHERE InformHeadlineStatusID<>45006 OR (Extension<>0 AND Extension<>2022) OR ProductStatus<>0 OR ISNULL(Remark,'')<>''	

		INSERT INTO [dbo].[crmInformHeadline_History](LogID,HeadlineID,InformHeadlineStatusID,GroupID,UpdatedTime,Remark,Handler,Extension,ProductStatus,IsInform)
		SELECT @LogID,hd.HeadlineID,hd.InformHeadlineStatusID,hd.GroupID,hd.UpdatedTime,hd.Remark,hd.Handler,hd.Extension,hd.ProductStatus,hd.IsInform
		FROM @HeadlineDataDelete hd
		INNER JOIN @HeadlineData h ON hd.HeadlineID=h.HeadlineID
		WHERE h.InformHeadlineStatusID<>hd.InformHeadlineStatusID OR h.Extension<>hd.Extension OR h.ProductStatus<>hd.ProductStatus OR hd.Remark<>h.Remark	

		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 103
			SELECT @ErrMsg = 'Insert Log unsuccessfuly.'
			RETURN
		END
	END	
	
	-- write log
	DECLARE @OldValues XML = '', @NewValues XML = ''

	DECLARE @HeadlineID INT
	DECLARE HeadlineID_cursor CURSOR FOR
	SELECT a.HeadlineID
	FROM
		@HeadlineData a	
	
	OPEN HeadlineID_cursor
	FETCH NEXT FROM HeadlineID_cursor INTO @HeadlineID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @OldValues = 				
					'<Acc_CRM_InformHeadlineSearchUpd>'			+ --SP Name
						'<Title>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Old_Title),'')										+ '</Title>' +
						'<Currency>'					+ @Old_Currency																			+ '</Currency>' +
						'<Level>'						+ @Old_Level																			+ '</Level>' +
						'<Site>'						+ @Old_Site																				+ '</Site>' +
						'<TypeAccount>'					+ CONVERT(VARCHAR(1), @Old_TypeAccount)													+ '</TypeAccount>' +
						'<ExcludeIgnored>'				+ CONVERT(VARCHAR(1), @Old_ExcludeIgnored)												+ '</ExcludeIgnored>' +
						'<HeadlineID>'					+ CAST(ISNULL(hl.HeadlineID, '') AS VARCHAR(30))										+ '</HeadlineID>' +
						'<GroupID>'						+ CAST(ISNULL(hl.GroupID, '') AS VARCHAR(30))											+ '</GroupID>' +
						'<StatusID>'					+ CAST(ISNULL(hl.InformHeadlineStatusID, -1) AS VARCHAR(30))							+ '</StatusID>' +
						'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](Remark),'')											+ '</Remark>' +
						'<Extension>'					+ ISNULL(CAST(hl.Extension AS VARCHAR(30)),0)											+ '</Extension>'+													
						'<ProductStatus>'				+ ISNULL(CAST(hl.ProductStatus AS VARCHAR(30)),0)										+ '</ProductStatus>'+
						'<Handler>'						+ ISNULL(CAST(hl.Handler AS VARCHAR(30)),'')											+ '</Handler>'+						
						'<UpdateTime>'					+ ISNULL(CAST(hl.UpdatedTime AS VARCHAR(30)),'')										+ '</UpdateTime>'+													
						'<IsInform>'					+ ISNULL(CAST(hl.IsInform AS VARCHAR(30)),'')											+ '</IsInform>'+						
					'</Acc_CRM_InformHeadlineSearchUpd>' 
		FROM @HeadlineDataOld hl
		WHERE hl.HeadlineID = @HeadlineID

		SELECT @NewValues = 				
					'<Acc_CRM_InformHeadlineSearchUpd>'			+ --SP Name
						'<Title>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Title),'')											+ '</Title>' +
						'<Currency>'					+ @Currency																				+ '</Currency>' +
						'<Level>'						+ @Level																				+ '</Level>' +
						'<Site>'						+ @Site																					+ '</Site>' +
						'<TypeAccount>'					+ CONVERT(VARCHAR(1), @TypeAccount)														+ '</TypeAccount>' +
						'<ExcludeIgnored>'				+ CONVERT(VARCHAR(1), @ExcludeIgnored)													+ '</ExcludeIgnored>' +
						'<HeadlineID>'					+ CAST(ISNULL(hl.HeadlineID,'') AS VARCHAR(30))											+ '</HeadlineID>' +
						'<GroupID>'						+ CAST(ISNULL(hl.GroupID, '') AS VARCHAR(30))											+ '</GroupID>' +
						'<StatusID>'					+ CAST(ISNULL(hl.InformHeadlineStatusID, '') AS VARCHAR(30))							+ '</StatusID>' +
						'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](hl.Remark),'')										+ '</Remark>' +
						'<Extension>'					+ ISNULL(CAST(hl.Extension AS VARCHAR(30)),'')											+ '</Extension>'+													
						'<ProductStatus>'				+ ISNULL(CAST(hl.ProductStatus AS VARCHAR(30)),'')										+ '</ProductStatus>' +
						'<Handler>'						+ ISNULL(CAST(@UserID AS VARCHAR(30)),'')												+ '</Handler>'+							
						'<UpdateTime>'					+ ISNULL(CAST(GETDATE() AS VARCHAR(30)),'')												+ '</UpdateTime>'+													
						'<IsInform>'					+ ISNULL(CAST(1 AS VARCHAR(30)),'')														+ '</IsInform>'+						
					'</Acc_CRM_InformHeadlineSearchUpd>' 
		FROM @HeadlineData hl
		WHERE hl.HeadlineID = @HeadlineID 

		EXEC [dbo].[WriteLog_UserLog_crmLogInformHeadline]
			@CustID = @HeadlineID, 
			@TitleID = @TitleID,
			@UserID = @UserID,  
			@ActionID = 703, 
			@IP = @IP, 				
			@NewValues = @NewValues,	
			@OldValues = @OldValues
		FETCH NEXT FROM HeadlineID_cursor INTO @HeadlineID
	END
	CLOSE HeadlineID_cursor
	DEALLOCATE HeadlineID_cursor

END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSearchUpd] TO [bodbAdminNet]
