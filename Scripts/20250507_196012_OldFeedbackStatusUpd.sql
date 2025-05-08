/*<info serverAlias="DBBOT-bodb_Chatbot" ></info>*/
/*
    Created: 20250507@Virgil
	Task: CRM - Manage SMA Feedback in effective way [Redmine #196012]
	DB: DBBOT-bodb_Chatbot
	Note: Update ReviewStatus of old CustFeedback to Status Completed
*/

DECLARE @CompletedStatusID INT = 61001,
        @Batch INT = 3000;

WHILE (1 = 1)
BEGIN
    -- Update rows in batches
    UPDATE TOP (@Batch) CustFeedback WITH(ROWLOCK,UPDLOCK)
    SET ReviewStatusID = @CompletedStatusID
    WHERE CreatedDate < '2025-04-21 00:00:00'
      AND (ReviewStatusID IS NULL OR ReviewStatusID <> @CompletedStatusID); -- Avoid re-updating rows

    -- Check if there are more rows to update
    IF @@ROWCOUNT = 0
        BREAK;
END