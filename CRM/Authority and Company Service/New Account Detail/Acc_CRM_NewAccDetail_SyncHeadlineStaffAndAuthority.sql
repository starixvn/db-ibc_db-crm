/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewAccDetail_SyncHeadlineStaffAndAuthority @HeadlineID INT,
                                                                       @UserID     INT,
                                                                       @IP         VARCHAR(45)    = '',
                                                                       @ErrCode    INT            = 0  OUTPUT,
                                                                       @ErrMsg     NVARCHAR(4000) = '' OUTPUT
AS

/*
    Created: Ned.Le
    Date:    20231212
    Task:    Sync data from group tables crmPicManagement|crmPIC|crmPICCommuniation to table crmCustomerHeadlineStaffAndAuthority
    DB:      DBCRM.bodb_CRM

    Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

    Param's Explanation:

    Example:
        DECLARE @ErrCode_out INT = 0
        DECLARE @ErrMsg_out NVARCHAR(4000) = ''
        EXEC bodb_CRM.dbo.Acc_CRM_NewAccDetail_SyncHeadlineStaffAndAuthority @HeadlineID = 1211024,
                                                                             @UserID     = 8,
                                                                             @IP         = '10.0.0.4',
                                                                             @ErrCode    = @ErrCode_out OUTPUT,
                                                                             @ErrMsg     = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out ErrCode, @ErrMsg_out ErrMsg
*/

BEGIN

    SET NOCOUNT ON


    ---------------------
    -- Get source data --

    CREATE TABLE #tmpSourceData (
        HeadlineID            INT,
        PicID                 INT,
        PicName               NVARCHAR(200),
        PicRoleID             INT,
        PicCommunicationID    INT,
        PicCommunicationValue NVARCHAR(200),
    )

    INSERT INTO #tmpSourceData (
        HeadlineID,
        PicID,
        PicName,
        PicRoleID,
        PicCommunicationID,
        PicCommunicationValue
    )
    SELECT DISTINCT
           pm.HeadlineID         HeadlineID,
           pm.PicID              PicID,
           p.Username            PicName,
           p.Role                PicRoleID,
           pc.CommunicationID    PicCommunicationID,
           pc.CommunicationValue PicCommunicationValue
    FROM bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmPIC p WITH (NOLOCK) ON pm.PicID = p.PicID
         LEFT JOIN bodb_CRM.dbo.crmPICCommunication pc WITH (NOLOCK) ON p.PicID = pc.PicID
    WHERE pm.HeadlineID = @HeadlineID
    OPTION (RECOMPILE)


    ------------------------------------------
    -- Get old value of Staff and Authority --

    CREATE TABLE #tmpStaffAndAuthorityOldValue (
        RowID                 INT,
        HeadlineID            INT,
        PicName               NVARCHAR(200),
        PicRoleName           NVARCHAR(200),
        PicCommunicationName  NVARCHAR(200),
        PicCommunicationValue NVARCHAR(200),
        Authority             NVARCHAR(MAX),
        Remark                NVARCHAR(4000),
    )

    INSERT INTO #tmpStaffAndAuthorityOldValue (
        RowID,
        HeadlineID,
        PicName,
        PicRoleName,
        PicCommunicationName,
        PicCommunicationValue,
        Authority,
        Remark
    )
    SELECT cha.RowID                                               RowID,
           cha.HeadlineID                                          HeadlineID,
           cha.PicName                                             PicName,
           sr.SettingValue                                         PicRoleName,
           sc.SettingValue                                         PicCommunicationName,
           cha.PicCommunicationValue                               PicCommunicationValue,
           STRING_AGG(CAST(sa.SettingValue AS NVARCHAR(MAX)), '|') Authority,
           cha.Remark                                              Remark
    FROM bodb_CRM.dbo.crmCustomerHeadlineStaffAndAuthority cha WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmSetting sr WITH (NOLOCK) ON sr.SettingName = 'PICRole' AND cha.PicRoleID = sr.SettingID
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cha.PicCommunicationID = sc.SettingID
         OUTER APPLY (SELECT TRIM(value) AuthorityID FROM STRING_SPLIT(cha.AuthorityID, ',')) au
         LEFT JOIN bodb_CRM.dbo.crmSetting sa WITH (NOLOCK) ON sa.SettingName = 'StaffAndAuthority' AND au.AuthorityID = sa.SettingID
    WHERE cha.isSyncFromPicTable = 1
          AND cha.HeadlineID = @HeadlineID
    GROUP BY cha.RowID,
             cha.HeadlineID,
             cha.PicName,
             sr.SettingValue,
             sc.SettingValue,
             cha.PicCommunicationValue,
             cha.Remark
    ORDER BY cha.HeadlineID,
             CASE WHEN sr.SettingValue = 'Boss' THEN 1 ELSE 2 END,
             CASE WHEN sr.SettingValue = 'Boss' THEN cha.PicName END,
             sr.SettingValue,
             cha.PicName
    OPTION (RECOMPILE)


    -----------------------------
    -- Sync data to main table --

    BEGIN TRY    
        MERGE bodb_CRM.dbo.crmCustomerHeadlineStaffAndAuthority AS TARGET
        USING #tmpSourceData AS SOURCE
        ON TARGET.isSyncFromPicTable = 1 AND
           TARGET.HeadlineID         = SOURCE.HeadlineID AND
           TARGET.PicID              = SOURCE.PicID AND
           TARGET.PicCommunicationID = SOURCE.PicCommunicationID
        WHEN MATCHED THEN
            UPDATE SET TARGET.PicName               = SOURCE.PicName,
                       TARGET.PicRoleID             = SOURCE.PicRoleID,
                       TARGET.PicCommunicationValue = SOURCE.PicCommunicationValue
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                HeadlineID,
                PicID,
                PicName,
                PicRoleID,
                PicCommunicationID,
                PicCommunicationValue,
                isSyncFromPicTable,
                CreatedDate
            )
            VALUES (
                SOURCE.HeadlineID,
                SOURCE.PicID,
                SOURCE.PicName,
                SOURCE.PicRoleID,
                SOURCE.PicCommunicationID,
                SOURCE.PicCommunicationValue,
                1,
                GETDATE()
            )
        WHEN NOT MATCHED BY SOURCE AND TARGET.isSyncFromPicTable = 1
                                   AND TARGET.HeadlineID = @HeadlineID
            THEN DELETE;
    END TRY
    BEGIN CATCH
        SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
        RETURN
    END CATCH


    ------------------------------------------
    -- Get new value of Staff and Authority --

    CREATE TABLE #tmpStaffAndAuthorityNewValue (
        RowID                 INT,
        HeadlineID            INT,
        PicName               NVARCHAR(200),
        PicRoleName           NVARCHAR(200),
        PicCommunicationName  NVARCHAR(200),
        PicCommunicationValue NVARCHAR(200),
        Authority             NVARCHAR(MAX),
        Remark                NVARCHAR(4000),
    )

    INSERT INTO #tmpStaffAndAuthorityNewValue (
        RowID,
        HeadlineID,
        PicName,
        PicRoleName,
        PicCommunicationName,
        PicCommunicationValue,
        Authority,
        Remark
    )
    SELECT cha.RowID                                               RowID,
           cha.HeadlineID                                          HeadlineID,
           cha.PicName                                             PicName,
           sr.SettingValue                                         PicRoleName,
           sc.SettingValue                                         PicCommunicationName,
           cha.PicCommunicationValue                               PicCommunicationValue,
           STRING_AGG(CAST(sa.SettingValue AS NVARCHAR(MAX)), '|') Authority,
           cha.Remark                                              Remark
    FROM bodb_CRM.dbo.crmCustomerHeadlineStaffAndAuthority cha WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmSetting sr WITH (NOLOCK) ON sr.SettingName = 'PICRole' AND cha.PicRoleID = sr.SettingID
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cha.PicCommunicationID = sc.SettingID
         OUTER APPLY (SELECT TRIM(value) AuthorityID FROM STRING_SPLIT(cha.AuthorityID, ',')) au
         LEFT JOIN bodb_CRM.dbo.crmSetting sa WITH (NOLOCK) ON sa.SettingName = 'StaffAndAuthority' AND au.AuthorityID = sa.SettingID
    WHERE cha.isSyncFromPicTable = 1
          AND cha.HeadlineID = @HeadlineID
    GROUP BY cha.RowID,
             cha.HeadlineID,
             cha.PicName,
             sr.SettingValue,
             sc.SettingValue,
             cha.PicCommunicationValue,
             cha.Remark
    ORDER BY cha.HeadlineID,
             CASE WHEN sr.SettingValue = 'Boss' THEN 1 ELSE 2 END,
             CASE WHEN sr.SettingValue = 'Boss' THEN cha.PicName END,
             sr.SettingValue,
             cha.PicName
    OPTION (RECOMPILE)


    ---------------
    -- Write log --

    -- Prepare data
    -- + Variables
    DECLARE @CountRow                  INT
    DECLARE @getRowID                  INT
    DECLARE @getHeadlineID             INT
    DECLARE @StaffAndAuthorityOldValue XML
    DECLARE @StaffAndAuthorityNewValue XML
    -- + Temp table
    -- + --> Create temp table
    CREATE TABLE #tmpDataToLoop (
        RowID       INT,
        HeadlineID  INT,
        OldValue    NVARCHAR(MAX),
        NewValue    NVARCHAR(MAX),
        isProcessed BIT DEFAULT(0)
    )
    -- + --> Gen data to temp table
    ;WITH
    CTE_OldValue AS (
        SELECT RowID,
               HeadlineID,
               STRING_AGG(CAST(ISNULL('[Name] '               + dbo.f_EncodeXMLValue(PicName)                                             + '<br/>' +
                                      '[Role] '               + dbo.f_EncodeXMLValue(PicRoleName)                                         + '<br/>' +
                                      '[Communication Tool] ' + dbo.f_EncodeXMLValue(PicCommunicationName + ': ' + PicCommunicationValue) + '<br/>' +
                                      '[Authority] '          + ISNULL(dbo.f_EncodeXMLValue(Authority), '')                               + '<br/>' +
                                      '[Remark] '             + ISNULL(dbo.f_EncodeXMLValue(Remark), ''), '') AS NVARCHAR(MAX)), '<br/><br/>') OldValue
        FROM #tmpStaffAndAuthorityOldValue
        GROUP BY RowID,
                 HeadlineID
    ),
    CTE_NewValue AS (
        SELECT RowID,
               HeadlineID,
               STRING_AGG(CAST(ISNULL('[Name] '               + dbo.f_EncodeXMLValue(PicName)                                             + '<br/>' +
                                      '[Role] '               + dbo.f_EncodeXMLValue(PicRoleName)                                         + '<br/>' +
                                      '[Communication Tool] ' + dbo.f_EncodeXMLValue(PicCommunicationName + ': ' + PicCommunicationValue) + '<br/>' +
                                      '[Authority] '          + ISNULL(dbo.f_EncodeXMLValue(Authority), '')                               + '<br/>' +
                                      '[Remark] '             + ISNULL(dbo.f_EncodeXMLValue(Remark), ''), '') AS NVARCHAR(MAX)), '<br/><br/>') NewValue
        FROM #tmpStaffAndAuthorityNewValue
        GROUP BY RowID,
                 HeadlineID
    )
    INSERT INTO #tmpDataToLoop (
        RowID,
        HeadlineID,
        OldValue,
        NewValue
    )
    SELECT ISNULL(old.RowID, new.RowID)           RowID,
           ISNULL(old.HeadlineID, new.HeadlineID) HeadlineID,
           old.OldValue                           OldValue,
           new.NewValue                           NewValue
    FROM CTE_OldValue old
         FULL OUTER JOIN CTE_NewValue new ON old.RowID = new.RowID AND old.HeadlineID = new.HeadlineID

    -- Process data
    WHILE (1=1)
    BEGIN
        -- + Check to break the loop
        SELECT @CountRow = COUNT(1) FROM #tmpDataToLoop WHERE isProcessed = 0
        IF (@CountRow = 0) BREAK

        -- + Get RowID|HeadlineID
        SELECT TOP(1) @getRowID      = RowID,
                      @getHeadlineID = HeadlineID
        FROM #tmpDataToLoop
        WHERE isProcessed = 0
        ORDER BY RowID, HeadlineID

        -- + Get value to @StaffAndAuthorityOldValue
        SELECT @StaffAndAuthorityOldValue = '<Acc_CRM_NewAccDetail_SyncHeadlineStaffAndAuthority>' +
                                            '<StaffAndAuthority>' +
                                            ISNULL(OldValue, '') +
                                            '</StaffAndAuthority>' +
                                            '</Acc_CRM_NewAccDetail_SyncHeadlineStaffAndAuthority>'
        FROM #tmpDataToLoop
        WHERE RowID = @getRowID AND HeadlineID = @getHeadlineID

        -- + Get value to @StaffAndAuthorityNewValue
        SELECT @StaffAndAuthorityNewValue = '<Acc_CRM_NewAccDetail_SyncHeadlineStaffAndAuthority>' +
                                            '<StaffAndAuthority>' +
                                            ISNULL(NewValue, '') +
                                            '</StaffAndAuthority>' +
                                            '</Acc_CRM_NewAccDetail_SyncHeadlineStaffAndAuthority>'
        FROM #tmpDataToLoop
        WHERE RowID = @getRowID AND HeadlineID = @getHeadlineID

        -- + Write log
        IF (ISNULL(CAST(@StaffAndAuthorityOldValue AS NVARCHAR(MAX)), '') <> ISNULL(CAST(@StaffAndAuthorityNewValue AS NVARCHAR(MAX)), ''))
        BEGIN
            EXEC bodb_CRM.dbo.WriteLog_UserLog_crmLogCustomer @CustID    = @getHeadlineID,
                                                              @UserID    = @UserID,
                                                              @ActionID  = 111,
                                                              @IP        = @IP,
                                                              @NewValues = @StaffAndAuthorityNewValue,
                                                              @OldValues = @StaffAndAuthorityOldValue
        END

        -- + Update to continue the loop
        UPDATE tmp
        SET tmp.isProcessed = 1
        FROM #tmpDataToLoop tmp
        WHERE tmp.isProcessed = 0
              AND tmp.RowID = @getRowID
              AND tmp.HeadlineID = @getHeadlineID
    END


    --------------------
    -- Drop temp data --

    DROP TABLE #tmpSourceData
    DROP TABLE #tmpStaffAndAuthorityOldValue
    DROP TABLE #tmpStaffAndAuthorityNewValue
    DROP TABLE #tmpDataToLoop

END
GO