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
	
	Param's Explanation:	
*/
BEGIN
	DECLARE @HeadlineData TABLE(HeadlineID INT, InformHeadlineStatusID INT, Remark NVARCHAR(4000), Extension INT, ProductStatus INT)
	DECLARE @HeadlineDataOld TABLE(HeadlineID INT, InformHeadlineStatusID INT, Remark NVARCHAR(4000), Extension INT, ProductStatus INT)

	INSERT INTO @HeadlineData
	SELECT	xmlData.Col.value('@HeadlineID','INT') HeadlineID,
			xmlData.Col.value('@StatusID','INT') InformHeadlineStatusID,
			dbo.[f_EncodeXMLValue](xmlData.Col.value('@Remark','NVARCHAR(4000)')) Remark,
			ISNULL(xmlData.Col.value('@Extension','INT'),0) Extension,
			ISNULL(xmlData.Col.value('@ProductStatus','INT'),0) ProductStatus
	FROM @Content.nodes('//content/headline') xmlData(Col)

	INSERT INTO @HeadlineDataOld
	SELECT ih.HeadlineID, ih.InformHeadlineStatusID, ih.Remark, ih.Extension, ih.ProductStatus
	FROM @HeadlineData hl
		INNER JOIN crmInformHeadline ih WITH (NOLOCK) ON hl.HeadlineID = ih.HeadlineID

	UPDATE ih
	SET InformHeadlineStatusID = h.InformHeadlineStatusID,		
		UpdatedTime = GETDATE(),
		Remark = h.Remark,
		Handler = @UserID,
		Extension = h.Extension,
		ProductStatus = h.ProductStatus
	FROM @HeadlineData h 
		INNER JOIN crmInformHeadline ih WITH(NOLOCK) ON ih.HeadlineID = h.HeadlineID AND ih.TitleID = @TitleID

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
					'</Acc_CRM_InformHeadlineUpd>' 
		FROM @HeadlineDataOld
		WHERE HeadlineID = @HeadlineID

		SELECT @NewValues = 				
					'<Acc_CRM_InformHeadlineUpd>'			+ --SP Name
						'<StatusID>'					+ CAST(InformHeadlineStatusID AS VARCHAR(30))		+ '</StatusID>' +
						'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](Remark),'')		+ '</Remark>' +
						'<Extension>'					+ ISNULL(CAST(Extension AS VARCHAR(30)),'')			+ '</Extension>'+													
						'<ProductStatus>'				+ ISNULL(CAST(ProductStatus AS VARCHAR(30)),'')		+'</ProductStatus>'	+
					'</Acc_CRM_InformHeadlineUpd>' 
		FROM @HeadlineData
		WHERE HeadlineID = @HeadlineID

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
GRANT EXECUTE ON [dbo].Acc_CRM_InformHeadlineUpd TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].Acc_CRM_InformHeadlineUpd TO [vnteam]