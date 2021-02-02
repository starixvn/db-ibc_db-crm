/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineUpd]
	@Content	XML,
	@TitleID	INT,
	@UserID		INT,
	@IP			VARCHAR(15),
	@ErrCode	INT				= 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000)	= '' OUTPUT	
AS

/*
	Created: Elodie
	Date: 20150403
	Task : Update inform headline
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:	
		- 20210201@Johnson: change datatype for Remark to nvarchar(max) [redmine:#149364]
	Param's Explanation:	
*/
BEGIN
	DECLARE @HeadlineData TABLE(HeadlineID INT, InformHeadlineStatusID INT, Remark NVARCHAR(MAX), Extension INT, ProductStatus INT)
	DECLARE @HeadlineDataOld TABLE(HeadlineID INT, InformHeadlineStatusID INT, Remark NVARCHAR(MAX), Extension INT, ProductStatus INT, UpdatedTime DATETIME, Handler INT)

	INSERT INTO @HeadlineData
	SELECT	xmlData.Col.value('@HeadlineID','INT') HeadlineID,
			xmlData.Col.value('@StatusID','INT') InformHeadlineStatusID,
			dbo.[f_EncodeXMLValue](xmlData.Col.value('@Remark','NVARCHAR(MAX)')) Remark,
			ISNULL(xmlData.Col.value('@Extension','INT'),0) Extension,
			ISNULL(xmlData.Col.value('@ProductStatus','INT'),0) ProductStatus
	FROM @Content.nodes('//Content/Headline') xmlData(Col)

	INSERT INTO @HeadlineDataOld
	SELECT ih.HeadlineID, ih.InformHeadlineStatusID, ih.Remark, ih.Extension, ih.ProductStatus, ih.UpdatedTime, ih.Handler
	FROM @HeadlineData hl
		INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON hl.HeadlineID = ih.HeadlineID
	WHERE ih.TitleID = @TitleID

	UPDATE ih
	SET InformHeadlineStatusID = h.InformHeadlineStatusID,		
		UpdatedTime = GETDATE(),
		Remark = h.Remark,
		Handler = @UserID,
		Extension = ISNULL(h.Extension,0),
		ProductStatus = ISNULL(h.ProductStatus,0)
	FROM @HeadlineData h 
		INNER JOIN crmInformHeadline_New ih WITH(NOLOCK) ON ih.HeadlineID = h.HeadlineID AND ih.TitleID = @TitleID

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Update Inform Headlines unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @OldValues XML, @NewValues XML

	DECLARE @HeadlineID INT
	DECLARE HeadlineID_cursor CURSOR FOR
	SELECT HeadlineID FROM @HeadlineData

	OPEN HeadlineID_cursor
	FETCH NEXT FROM HeadlineID_cursor INTO @HeadlineID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @OldValues = 				
					'<Acc_CRM_InformHeadlineUpd>'			+ --SP Name
						'<StatusID>'					+ CAST(InformHeadlineStatusID AS VARCHAR(30))		+ '</StatusID>' +
						'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](Remark),'')		+ '</Remark>' +
						'<Extension>'					+ ISNULL(CAST(Extension AS VARCHAR(30)),'')			+ '</Extension>'+													
						'<ProductStatus>'				+ ISNULL(CAST(ProductStatus AS VARCHAR(30)),'')		+'</ProductStatus>'	+
						'<UpdatedTime>'					+ ISNULL(CAST(UpdatedTime AS VARCHAR(30)),'')		+ '</UpdatedTime>'+													
						'<Handler>'						+ ISNULL(CAST(Handler AS VARCHAR(30)),'')			+ '</Handler>'+	
					'</Acc_CRM_InformHeadlineUpd>' 
		FROM @HeadlineDataOld
		WHERE HeadlineID = @HeadlineID

		SELECT @NewValues = 				
					'<Acc_CRM_InformHeadlineUpd>'			+ --SP Name
						'<StatusID>'					+ CAST(hl.InformHeadlineStatusID AS VARCHAR(30))		+ '</StatusID>' +
						'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](hl.Remark),'')		+ '</Remark>' +
						'<Extension>'					+ ISNULL(CAST(hl.Extension AS VARCHAR(30)),'')			+ '</Extension>'+													
						'<ProductStatus>'				+ ISNULL(CAST(hl.ProductStatus AS VARCHAR(30)),'')		+ '</ProductStatus>'+
						'<UpdatedTime>'					+ ISNULL(CAST(ih.UpdatedTime AS VARCHAR(30)),'')		+ '</UpdatedTime>'+													
						'<Handler>'						+ ISNULL(CAST(@UserID AS VARCHAR(30)),'')				+ '</Handler>'+	
					'</Acc_CRM_InformHeadlineUpd>' 
		FROM @HeadlineData hl
			INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON hl.HeadlineID = ih.HeadlineID
		WHERE hl.HeadlineID = @HeadlineID AND ih.TitleID = @TitleID

		--SELECT CAST(InformHeadlineStatusID AS VARCHAR(30))	
		--	   ,ISNULL([dbo].[f_EncodeXMLValue](Remark),'')	
		--	   ,ISNULL(CAST(Extension AS VARCHAR(30)),'')		
		--	   ,ISNULL(CAST(ProductStatus AS VARCHAR(30)),'')	
		--	   ,CAST(UpdatedTime AS VARCHAR(30))				
		--	   ,ISNULL(CAST(Handler AS VARCHAR(30)),'')		
		--FROM @HeadlineDataOld
		--WHERE HeadlineID = @HeadlineID

		--SELECT CAST(hl.InformHeadlineStatusID AS VARCHAR(30))	
		--	   ,ISNULL([dbo].[f_EncodeXMLValue](hl.Remark),'')	
		--	   ,ISNULL(CAST(hl.Extension AS VARCHAR(30)),'')		
		--	   ,ISNULL(CAST(hl.ProductStatus AS VARCHAR(30)),'')	
		--	   ,CAST(ih.UpdatedTime AS VARCHAR(30))				
		--	   ,ISNULL(CAST(@UserID AS VARCHAR(30)),'')			
		--FROM @HeadlineData hl
		--	INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON hl.HeadlineID = ih.HeadlineID
		--WHERE hl.HeadlineID = @HeadlineID AND ih.TitleID = @TitleID

		EXEC [dbo].[WriteLog_UserLog_crmLogInformHeadline]
			@CustID = @HeadlineID, 
			@TitleID = @TitleID,
			@UserID = @UserID,  
			@ActionID = 701, 
			@IP = @IP, 				
			@NewValues = @NewValues,	
			@OldValues = @OldValues
		FETCH NEXT FROM HeadlineID_cursor INTO @HeadlineID
	END
	CLOSE HeadlineID_cursor
	DEALLOCATE HeadlineID_cursor		
END

GO 