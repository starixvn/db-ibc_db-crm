/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewLeftPanel_GetHeadlineStaffInfo @HeadlineID INT
AS

/*
	Created: Ned.Le
	Date:    20231212
	Task:    Get list of Pic Staff (with communication info) of Headline
	DB:      DBCRM.bodb_CRM

	Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

	Param's Explanation:
        @HeadlineID: HeadlineID (also be CustID) that be used to get data

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_NewLeftPanel_GetHeadlineStaffInfo @HeadlineID=3341773
*/

BEGIN

	SET NOCOUNT ON


    --------------
    -- Get data --

    -- Create temp table
    CREATE TABLE #tmpHeadlineStaff (
        HeadlineID        INT,
        PicID             INT,
        PicName           NVARCHAR(200),
        PicTypeID         INT,
        PicTypeName       NVARCHAR(200),
        PicRoleID         INT,
        PicRoleName       NVARCHAR(200),
        PicCountryID      INT,
        PicCountryName    NVARCHAR(200),
        PicListLanguageID VARCHAR(2000)
    )

    -- Gen data to temp table
    INSERT INTO #tmpHeadlineStaff (
        HeadlineID,
        PicID,
        PicName,
        PicTypeID,
        PicTypeName,
        PicRoleID,
        PicRoleName,
        PicCountryID,
        PicCountryName,
        PicListLanguageID
    )
    SELECT DISTINCT
           pm.HeadlineID              HeadlineID,
           pm.PicID                   PicID,
           p.Username                 PicName,
           p.PicType                  PicTypeID,
           st.SettingValue            PicTypeName,
           p.Role                     PicRoleID,
           sr.SettingValue            PicRoleName,
           p.Country                  PicCountryID,
           ISNULL(sc.CountryName, '') PicCountryName,
           p.Language                 PicListLanguageID
    FROM bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmPIC p WITH (NOLOCK) ON pm.PicID = p.PicID
         LEFT JOIN bodb_CRM.dbo.crmSetting st WITH (NOLOCK) ON st.SettingName = 'PICType' AND p.PicType = st.SettingID
         LEFT JOIN bodb_CRM.dbo.crmSetting sr WITH (NOLOCK) ON sr.SettingName = 'PICRole' AND p.Role = sr.SettingID
         LEFT JOIN bodb_CRM.dbo.crmCountry sc WITH (NOLOCK) ON p.Country = sc.CountryID
    WHERE pm.HeadlineID = @HeadlineID
    OPTION (RECOMPILE)


    -----------------
    -- Return data --

    -- Return Headline with PIC Info
    SELECT HeadlineID,
           PicID,
           PicName,
           PicTypeID,
           PicTypeName,
           PicRoleID,
           PicRoleName,
           PicCountryID,
           PicCountryName
    FROM #tmpHeadlineStaff
    ORDER BY CASE WHEN PicRoleName = 'Boss' THEN 1 ELSE 2 END,
             CASE WHEN PicRoleName = 'Boss' THEN PicName END,
             PicRoleName,
             PicName

    -- Return PIC Language Info
    SELECT tmp.HeadlineID              HeadlineID,
           tmp.PicID                   PicID,
           l.PicLanguageID             PicLanguageID,
           ISNULL(sl.SettingValue, '') PicLanguageName
    FROM #tmpHeadlineStaff tmp
         CROSS APPLY (SELECT CAST(TRIM(value) AS INT) PicLanguageID FROM STRING_SPLIT(tmp.PicListLanguageID, ',')) l
         LEFT JOIN bodb_CRM.dbo.crmSetting sl WITH (NOLOCK) ON sl.SettingName = 'Language' AND l.PicLanguageID = sl.SettingID
    ORDER BY ISNULL(sl.SettingValue, '')

    -- Return PIC Communication Info
    SELECT tmp.HeadlineID        HeadlineID,
           tmp.PicID             PicID,
           pc.CommunicationID    PicCommunicationID,
           sc.SettingValue       PicCommunicationName,
           pc.CommunicationValue PicCommunicationValue
    FROM #tmpHeadlineStaff tmp
         LEFT JOIN bodb_CRM.dbo.crmPICCommunication pc WITH (NOLOCK) ON tmp.PicID = pc.PicID
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND pc.CommunicationID = sc.SettingID
    WHERE sc.IsActive = 1
    ORDER BY sc.SettingValue


    ---------------
    -- Drop data --

    DROP TABLE #tmpHeadlineStaff

END
GO