
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CustomerRemarkUpd    Script Date: 3/26/2014 6:06:05 PM ******/
ALTER PROCEDURE Acc_CRM_CustomerRemarkUpd
	@CustID		INT,
	@Remarks	XML,
    @UserID		INT,
	@IP			VARCHAR(15),
	@ErrCode	INT				= 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000)	= '' OUTPUT
AS
/*
Created: 20140210@Dom
Task : Insert new redemption log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
*/

/*
SET @Remarks = CAST('<Remarks>
    <Remark Content="Content SP" IsSpecial="1"/>
    <Remark Content="Content tét " IsSpecial="0"/>
  </Remarks>' AS XML)
*/

	
				
	IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		EXEC Acc_CRM_CopyCustomerInformation
			@CustID		= @CustID,
			@UserID		= @UserID,
			@IP			= @IP,
			@ErrCode	= @ErrCode OUTPUT,
			@ErrMsg		= @ErrMsg OUTPUT

			IF @ErrCode <> 0
				RETURN
	END

	DECLARE @Remark_old nvarchar(max)='',@SPRemark_old nvarchar(max)=''
	
	SELECT @Remark_old = @Remark_old+'<Remark>' + REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Remark AS nvarchar(MAX)),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),'''','&apos;') +  '</Remark>'
	FROM crmCustomerRemark(NOLOCK) where CustID = @CustID and IsSpecial=0
	
	IF(@Remark_old IS NULL OR @Remark_old='')
		SELECT @Remark_old = '<Remark/>'


	SELECT @SPRemark_old = @SPRemark_old+'<SpecialRemark>' + REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Remark AS nvarchar(MAX)),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),'''','&apos;') +  '</SpecialRemark>'
	FROM crmCustomerRemark(NOLOCK) where CustID = @CustID and IsSpecial=1

	IF(@SPRemark_old IS NULL OR @SPRemark_old='')
		SELECT @SPRemark_old = '<SpecialRemark/>'

	DELETE crmCustomerRemark WHERE CustID = @CustID

	INSERT INTO crmCustomerRemark
	SELECT 
	@CustID CustID,
	 xmlData.Col.value('@Content','NVARCHAR(max)') Content
	,xmlData.Col.value('@IsSpecial','BIT') IsSpecial
	FROM @Remarks.nodes('//Remarks/Remark') xmlData(Col);

	------Update Remark for Old Table
	DECLARE @Remark nvarchar(3000),@Remark2 nvarchar(3000)
	SELECT TOP 1 @Remark = xmlData.Col.value('@Content','NVARCHAR(max)')
	FROM @Remarks.nodes('//Remarks/Remark') xmlData(Col)
	WHERE xmlData.Col.value('@IsSpecial','BIT') =0

	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET Remark = @Remark
	WHERE CustID = @CustID

	SELECT TOP 1 @Remark2 = xmlData.Col.value('@Content','NVARCHAR(max)')
	FROM @Remarks.nodes('//Remarks/Remark') xmlData(Col)
	WHERE xmlData.Col.value('@IsSpecial','BIT') = 1

	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET Remark2 = @Remark2
	WHERE CustID = @CustID 

	--select * from crmLogCustomerRemark ORDER BY LogDate DESC
	-- write log
	DECLARE @NewValues XML,@OldValues XML, @xmlnewRemark nvarchar(max) ='',@xmlnewSPRemark nvarchar(max) =''
	
	SELECT @xmlnewRemark = @xmlnewRemark + '<Remark>'+REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(xmlData.Col.value('@Content','nvarchar(max)'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),'''','&apos;') +'</Remark>' +char(13)
	FROM @Remarks.nodes('//Remarks/Remark') xmlData(Col)
	where xmlData.Col.value('@IsSpecial','bit')=0
	
	IF(@xmlnewRemark IS NULL OR @xmlnewRemark = '')
	SELECT @xmlnewRemark = '<Remark/>'

	SELECT @xmlnewSPRemark = @xmlnewSPRemark + '<SpecialRemark>'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(xmlData.Col.value('@Content','nvarchar(max)'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),'''','&apos;') +'</SpecialRemark>' +char(13)
	FROM @Remarks.nodes('//Remarks/Remark') xmlData(Col)
	where xmlData.Col.value('@IsSpecial','bit')=1

	IF(@xmlnewSPRemark IS NULL OR @xmlnewSPRemark = '')
	SELECT @xmlnewSPRemark = '<SpecialRemark/>'

	--select @xmlnew = REPLACE(@xmlnew,'&','&amp;')
	--select @xmlnew = REPLACE(@xmlnew,'<','&lt;')
	--select @xmlnew = REPLACE(@xmlnew,'>','&gt;')
	--select @xmlnew = REPLACE(@xmlnew,'"','&quot;')
	--select @xmlnew = REPLACE(@xmlnew,'''','&apos;')

	--select @remark_old = REPLACE(@remark_old,'&','&amp;')
	--select @remark_old = REPLACE(@remark_old,'<','&lt;')
	--select @remark_old = REPLACE(@remark_old,'>','&gt;')
	--select @remark_old = REPLACE(@remark_old,'"','&quot;')
	--select @remark_old = REPLACE(@remark_old,'''','&apos;')

	--select @remark_old,@xmlnew
	
	SELECT @OldValues = 				
					'<Acc_CRM_CustomerRemarkUpd>'			+ --SP Name
						@remark_old + @SPRemark_old +
					'</Acc_CRM_CustomerRemarkUpd>' 

	SELECT @NewValues = 				
					'<Acc_CRM_CustomerRemarkUpd>'			+ --SP Name
						@xmlnewRemark+@xmlnewSPRemark+
					'</Acc_CRM_CustomerRemarkUpd>' 
	
	--select @NewValues,@OldValues 

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomerRemark]
				@CustID		= @CustID, 
				@UserID		= @UserID, 
				@ActionID	= 600, 
				@IP			= @IP, 
				@NewValues	= @NewValues,
				@OldValues	= @OldValues

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerRemarkUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerRemarkUpd] TO [vnteam]
GO 

