
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CustomerRemarkUpd    Script Date: 3/26/2014 6:06:05 PM ******/
CREATE PROCEDURE Acc_CRM_CustomerRemarkUpd
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

	DECLARE @remark_old nvarchar(max)=''

	SELECT @remark_old = @remark_old+'<Remark>' + CAST(Remark AS nvarchar(MAX)) +  '</Remark>'
	FROM crmCustomerRemark(NOLOCK) where CustID = @CustID and IsSpecial=0

	SELECT @remark_old = @remark_old+'<SpecialRemark>' + CAST(Remark AS nvarchar(MAX)) +  '</SpecialRemark>'
	FROM crmCustomerRemark(NOLOCK) where CustID = @CustID and IsSpecial=1

	DELETE crmCustomerRemark WHERE CustID = @CustID

	INSERT INTO crmCustomerRemark
	SELECT 
	@CustID CustID,
	 xmlData.Col.value('@Content','NVARCHAR(max)') Content
	,xmlData.Col.value('@IsSpecial','BIT') IsSpecial
	FROM @Remarks.nodes('//Remarks/Remark') xmlData(Col);

	-- write log
	DECLARE @NewValues XML,@OldValues XML, @xmlnew nvarchar(max) =''
	
	SELECT @xmlnew = @xmlnew + '<Remark>'+xmlData.Col.value('@Content','nvarchar(max)')+'</Remark>'+char(13)
	FROM @Remarks.nodes('//Remarks/Remark') xmlData(Col)
	where xmlData.Col.value('@IsSpecial','bit')=0

	SELECT @xmlnew = @xmlnew + '<SpecialRemark>'+xmlData.Col.value('@Content','nvarchar(max)')+'</SpecialRemark>'+char(13)
	FROM @Remarks.nodes('//Remarks/Remark') xmlData(Col)
	where xmlData.Col.value('@IsSpecial','bit')=1

	SELECT @OldValues = 				
					'<Acc_CRM_CustomerRemarkUpd>'			+ --SP Name
						@remark_old+
					'</Acc_CRM_CustomerRemarkUpd>' 

	SELECT @NewValues = 				
					'<Acc_CRM_CustomerRemarkUpd>'			+ --SP Name
						@xmlnew+
					'</Acc_CRM_CustomerRemarkUpd>' 
	
	select @NewValues,@OldValues

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
