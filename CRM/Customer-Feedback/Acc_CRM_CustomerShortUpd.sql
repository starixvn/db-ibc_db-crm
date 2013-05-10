ALTER PROCEDURE [dbo].[Acc_CRM_CustomerShortUpd]
(
	@UserID			INT,
	@CustID			INT,
	@FirstName		NVARCHAR(50),
	@LastName		NVARCHAR(50),
	@TitleID		INT,
	@Phone			NVARCHAR(50),
	@MobilePhone	NVARCHAR(50),
	@Fax			NVARCHAR(50),
	@Email			NVARCHAR(254),	
	@Skype			NVARCHAR(100),
	@MSN			NVARCHAR(100),
	@IP				VARCHAR(15),
	@Pic1			NVARCHAR(100)	= NULL,
	@Pic2			NVARCHAR(100)	= NULL,
	@Pic3			NVARCHAR(100)	= NULL,
	@ErrCode		INT OUTPUT,
	@ErrMsg			NVARCHAR(4000) OUTPUT
)
AS
/*
Created: Lukas
Date: 20101023
Task : update feedback info
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20110725@Lukas: add skype, msn info
	- 20120307@Elodie: add 3 params @Pic1, @Pic3, @Pic3
	- 20120319@Elodie: change DB06 to DB052
	- 20120327@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(500)
	- 20120404@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
Param's Explanation:
	
*/
BEGIN

	SET NOCOUNT ON

	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET	FirstName	= @FirstName,
		LastName	= @LastName,
		TitleID		= @TitleID,
		Phone		= @Phone,
		MobilePhone	= @MobilePhone,
		Fax			= @Fax,
		Email		= @Email,
		Skype		= @Skype,
		MSN			= @MSN,
		Pic1		= @Pic1,
		Pic2		= @Pic2,
		Pic3		= @Pic3	
	WHERE CustID = @CustID
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerShortUpd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerShortUpd] TO [vnteam]  