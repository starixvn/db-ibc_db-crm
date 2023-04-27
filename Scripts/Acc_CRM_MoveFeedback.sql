--Created: 20130813@Lukas
--Task : Request to move feedback from Guest to Customer
--DB: DBCRM/bodb_CRM
--Original:

DECLARE @username VARCHAR(20)
SET @username = 'B6TSS00092'

DECLARE @fromUser INT
DECLARE @toUser   INT

-- get guestID
SELECT @fromUser = custID 
FROM crmCustomer WITH(NOLOCK) 
WHERE username = @username AND custID < 0

-- get real customer ID
SELECT @toUser = custID 
FROM crmCustomer WITH(NOLOCK) 
WHERE username = @username AND custID > 0

SELECT FeedbackID INTO #fb
FROM crmFeedback WITH(NOLOCK)
WHERE CustID = @fromUser

UPDATE crmFeedback WITH(ROWLOCK, UPDLOCK)
SET custID   = @toUser
WHERE FeedbackID in (select * from #fb)

UPDATE crmFeedbackCustomer WITH(ROWLOCK, UPDLOCK)
SET custID   = @toUser
WHERE FeedbackID in (select * from #fb)
 AND CustID = @fromUser