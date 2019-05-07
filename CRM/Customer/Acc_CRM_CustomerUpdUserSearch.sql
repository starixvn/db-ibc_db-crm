/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerUpdUserSearch]	
	@UserID		int,
	@CustID		int,
	@UserName	nvarchar(50),
	@UserRole   TINYINT
AS
/*
Created: 20120403@Elodie
Task : Update to increate number of hits of 'search' term by userid.
DB: DBCRM/bodb_CRM
Original:

Revisions:
	- 20120423@Elodie: not update crmCustSearch table if @CustID < 0
	- 20130121@Johnson: change linked server DB06 to DBACC
	- 20140811@Dom: [Feature #18632] Customize Auto-suggestion for Phone number and add more Communication Types to Customer info
	- 20181003@Winnie: Search Thai[RedmineID: #99982]
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
Param's Explanation:
	• @UserID: User who are logging in.	
*/

BEGIN
	SET NOCOUNT ON
	--IF @CustID > 0
	--BEGIN
	
	IF(NOT EXISTS (SELECT TOP 1 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID
																		AND ((@UserRole=2 AND SiteID<>33002) 
																			OR (@UserRole=1 AND SiteID=33002) 
																			OR @UserRole=0)))
		RETURN;

	DECLARE @PhoneNumber1 NVARCHAR(200) = '',
			@PhoneNumber2 NVARCHAR(200) = '',
			@PhoneNumber3 NVARCHAR(200) = '',
			@MobilePhone NVARCHAR(200) = '',
			@IsGuest BIT

	SELECT @PhoneNumber1 = ISNULL(PhoneCountryCode,'') + ISNULL(PhoneAreaCode,'') + ISNULL(Phone,'')
			,@PhoneNumber2 = ISNULL(Phone2CountryCode,'') + ISNULL(Phone2AreaCode,'') + ISNULL(Phone2,'')
			,@PhoneNumber3 = ISNULL(Phone3CountryCode,'') + ISNULL(Phone3AreaCode,'') + ISNULL(Phone3,'')
			,@MobilePhone = ISNULL(MobilePhoneCountryCode,'') + ISNULL(MobilePhoneAreaCode,'') + ISNULL(MobilePhone,'')
	FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID

	SELECT @UserID  = CASE WHEN @CustID > 0 THEN @UserID ELSE -1 END
	IF EXISTS (SELECT 1 FROM DBACC.bodb02.dbo.Customer WITH (NOLOCK) WHERE Username2 = @UserName)
		RETURN
	ELSE
	BEGIN
		IF NOT EXISTS (SELECT 1 from crmCustomerSearch with (NOLOCK) WHERE CustID = @CustID)
		BEGIN
			INSERT INTO crmCustomerSearch(CustID, UserName, SearchCount,PhoneNumber1,PhoneNumber2,PhoneNumber3,MobilePhone)
			VALUES (@CustID, @UserName,0,@PhoneNumber1,@PhoneNumber2,@PhoneNumber3,@MobilePhone)	
		END
		ELSE
		BEGIN
			print 'update search'
			UPDATE crmCustomerSearch WITH (ROWLOCK)
			SET SearchCount = SearchCount + 1,
				PhoneNumber1 = 	@PhoneNumber1,
				PhoneNumber2 = 	@PhoneNumber2,
				PhoneNumber3 = 	@PhoneNumber3,
				MobilePhone = @MobilePhone
			WHERE CustID = @CustID 
		END
	END
	--END
END
GO

