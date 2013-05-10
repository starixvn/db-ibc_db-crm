ALTER PROCEDURE [dbo].[Acc_CRM_CustomerUpdUserSearch]	
	@UserID int,
	@CustID int,
	@UserName varchar(50)
AS
/*
Created: 20120403@Elodie
Task : Update to increate number of hits of 'search' term by userid.
DB: DBCRM/bodb_CRM
Original:

Revisions:
	- 20120423@Elodie: not update crmCustSearch table if @CustID < 0
	- 20130121@Johnson: change linked server DB06 to DBACC
Param's Explanation:
	• @UserID: User who are logging in.	
*/
BEGIN
	SET NOCOUNT ON
	IF @CustID > 0
	BEGIN
		IF EXISTS (SELECT 1 FROM DBACC.bodb02.dbo.Customer WITH (NOLOCK) WHERE Username2 = @UserName)
			RETURN
		ELSE
		BEGIN
			IF not exists (SELECT 1 from crmCustSearch with (NOLOCK) WHERE UserID = @UserID AND CustID = @CustID)
			BEGIN
				IF EXISTS (SELECT 1 FROM DBACC.bodb02.dbo.Custinfo with (NOLOCK) WHERE custid = @UserID)		
					INSERT INTO crmCustSearch(UserID, CustID, UserName, SearchCount)
					VALUES (@UserID, @CustID, @UserName, 0)	
			END
			ELSE
			BEGIN
				UPDATE crmCustSearch WITH (ROWLOCK)
				SET SearchCount = SearchCount + 1
				WHERE UserID = @UserID AND CustID = @CustID
			END
		END
	END
END




