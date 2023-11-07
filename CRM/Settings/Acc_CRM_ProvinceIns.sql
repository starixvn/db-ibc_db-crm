/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_ProvinceIns]	
@CountryID		INT,
@ProvinceName	NVARCHAR(150),
@IsActive		BIT,
@DisplayOrder	TINYINT         = 0,
@ErrCode		INT				= 0 OUTPUT,
@ErrMsg			NVARCHAR(4000)	= '' OUTPUT
AS

/*
	Created: 20190521@Winnie
	Task :  Get all currency
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
			20190521@Winnie: Add Province
            20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

	Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON
	IF EXISTS(SELECT TOP 1 1 FROM crmProvince WITH(NOLOCK) WHERE ProvinceName=@ProvinceName )
	BEGIN
		SELECT @ErrCode=100,@ErrMsg='Existed ProvinceName'
	END
	ELSE
	BEGIN
		INSERT INTO crmProvince(ProvinceName,CountryID,DisplayOrder,IsActive)
		VALUES( @ProvinceName,@CountryID,@DisplayOrder,@IsActive)	
		IF @@ERROR<>0
		BEGIN
			SELECT @ErrCode=101,@ErrMsg='Insert Province unsuccessfuly.'
		END
	END
END