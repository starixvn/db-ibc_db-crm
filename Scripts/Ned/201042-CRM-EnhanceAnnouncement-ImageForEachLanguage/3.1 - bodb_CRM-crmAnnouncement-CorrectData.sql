/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20240509@Ned.Le
DB: DBCRM.bodb_CRM
Task: Correct data for column UploadFiletype in table crmAnnouncement
*/


USE bodb_CRM
GO

;WITH
CTE_BaseData AS (
    SELECT a.AnnouncementId, ac.LanguageId, ac.FileName
    FROM dbo.crmAnnouncement a WITH (NOLOCK)
         LEFT JOIN crmAnnouncementContent ac WITH (NOLOCK) ON a.AnnouncementId = ac.AnnouncementId
),
CTE_ResultData AS (
    SELECT t1.AnnouncementId
    FROM CTE_BaseData t1
         INNER JOIN CTE_BaseData t2 ON t1.AnnouncementId = t2.AnnouncementId
                                       AND t1.FileName <> t2.FileName
    GROUP BY t1.AnnouncementId
)
UPDATE a
SET a.UploadFileType = 'Single'
FROM dbo.crmAnnouncement a WITH (UPDLOCK, TABLOCK)
WHERE a.AnnouncementId IN (SELECT AnnouncementId FROM CTE_ResultData)
GO