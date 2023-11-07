/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_ProvinceUpd]	
@CountryID		INT,
@ProvinceName	NVARCHAR(150),
@IsActive		BIT,
@DisplayOrder	TINYINT         = 0,
@ProvinceID		INT,
@ErrCode		INT				= 0 OUTPUT,
@ErrMsg			NVARCHAR(4000)	= '' OUTPUT
AS

/*
	Created: 20190521@Winnie
	Task :  Get all currency
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		20190521@Winnie: Update Province
        20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

	Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON
	
	UPDATE crmProvince WITH(ROWLOCK,UPDLOCK)
	SET CountryID		=@CountryID,
		ProvinceName	=@ProvinceName,
		IsActive		=@IsActive,
		DisplayOrder	=@DisplayOrder
	WHERE ProvinceID=@ProvinceID
	IF @@ERROR<>0
	BEGIN
		SELECT @ErrCode=101,@ErrMsg='Update Province unsuccessfuly.'
	END

END