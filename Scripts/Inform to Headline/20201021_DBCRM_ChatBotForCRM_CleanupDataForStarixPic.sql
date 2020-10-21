/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
	Created: 20201021@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Chatbot for CRM - Clean up data of Starix_pic PIC
*/

use bodb_CRM
go

DECLARE @TmpHeadlineId TABLE (ID INT)

DECLARE @PicID INT

SELECT @PicID = PicID
FROM crmPIC WITH(NOLOCK)
WHERE Username = 'starix_PIC2'

INSERT INTO @TmpHeadlineId (ID)
SELECT custid
FROM bodb02.dbo.Customer c WITH(NOLOCK)
WHERE c.username IN 
('1158RM','222','302RM','305RM','659RMB','801H','8K01','8U01','92RM','999SD','AC1','AHM','BA03RM','C1','CHTB'
,'D-77RM','DS1','ET789HL','ET889HL','HGG','HPO','JR','KKM','LHH','M25RM','MK1','PKK','RG1','S222H','S359M','S56RM','S6EU'
,'S99M','SI','SMORM','Staff-7y','TS1','WE339','WINA','WT','ZU01')

DELETE m
FROM dbo.crmPicManagement m WITH(ROWLOCK, UPDLOCK)
WHERE m.PicID = @PicID
	AND EXISTS(SELECT 1 FROM @TmpHeadlineId h WHERE h.ID = m.HeadlineID)