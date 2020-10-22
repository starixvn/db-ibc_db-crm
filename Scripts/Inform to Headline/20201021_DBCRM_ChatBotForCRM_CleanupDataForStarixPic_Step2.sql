/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
	Created: 20201021@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Chatbot for CRM - Clean up data of Starix_pic PIC
*/

use bodb_CRM
go

DECLARE @PicID INT

SELECT @PicID = PicID
FROM crmPIC WITH(NOLOCK)
WHERE Username = 'starix_PIC2'

DELETE m
FROM dbo.crmPicManagement m WITH(ROWLOCK, UPDLOCK)
WHERE m.PicID = @PicID 

DELETE h
FROM dbo.crmPICHeadline h WITH(ROWLOCK, UPDLOCK)
WHERE h.PicID = @PicID 