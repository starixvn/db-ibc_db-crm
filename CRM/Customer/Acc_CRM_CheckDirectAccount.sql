/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CheckDirectAccount]
(	
	@CustID						INT
)
AS
/*
Created: 20190827@Winnie
Task : Check direct acc
DB: DBCRM.bodb_CRM
Original:

Revisions:
	- 20190827@Winnie: Check direct acc
Param's Explanation:
	
*/
BEGIN	
DECLARE @IsDirectAcc BIT = 0

IF EXISTS (
		SELECT TOP 1 1
		FROM bodb02.dbo.CustDirectAccount WITH (NOLOCK)
		WHERE Custid = @CustID
		)
BEGIN
	SELECT @IsDirectAcc = 1
END

SELECT @IsDirectAcc

END