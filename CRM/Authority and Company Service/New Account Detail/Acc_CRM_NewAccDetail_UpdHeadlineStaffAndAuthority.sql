/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewAccDetail_UpdHeadlineStaffAndAuthority @HeadlineID        INT,
                                                                      @StaffAndAuthority NVARCHAR(MAX),
                                                                      @UserID            INT,
                                                                      @IP                VARCHAR(45)    = '',
                                                                      @ErrCode           INT            = 0  OUTPUT,
                                                                      @ErrMsg            NVARCHAR(4000) = '' OUTPUT
AS

/*
    Created: Ned.Le
    Date:    20231212
    Task:    Insert/Update/Delete staff and authority of headline
    DB:      DBCRM.bodb_CRM

    Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

    Param's Explanation:
        @HeadlineID:      HeadlineID that its data be manipulated
        @StaffAndAuthority: <ROOT>
                                <StaffAndAuthority RowID="6" HeadlineID="1211024" PicID="1619" PicName="malcolm2023" PicRoleID="48001" PicCommunicationID="49000" PicCommunicationValue="22weee_test" AuthorityID="112000,112003,112005" Remark="newsaving01" IsSyncFromPicTable="1"/>
                                <StaffAndAuthority RowID="7" HeadlineID="1211024" PicID="1619" PicName="malcolm2023" PicRoleID="48001" PicCommunicationID="49010" PicCommunicationValue="malcolm1411915" AuthorityID="112001,112002,112004" Remark="newsaving02" IsSyncFromPicTable="1"/>
                                <StaffAndAuthority RowID="-1" HeadlineID="1211024" PicID="" PicName="test01,test02" PicRoleID="48001" PicCommunicationID="49000" PicCommunicationValue="telegram01" AuthorityID="112003,112005" Remark="manually add" IsSyncFromPicTable="0"/>
                            </ROOT>

    Example:
        DECLARE @StaffAndAuthority_in NVARCHAR(MAX) = '<ROOT>
                                                           <StaffAndAuthority RowID="6" HeadlineID="1211024" PicID="1619" PicName="malcolm2023" PicRoleID="48001" PicCommunicationID="49000" PicCommunicationValue="22weee_test" AuthorityID="112000,112003,112005" Remark="newsaving01" IsSyncFromPicTable="1"/>
                                                           <StaffAndAuthority RowID="7" HeadlineID="1211024" PicID="1619" PicName="malcolm2023" PicRoleID="48001" PicCommunicationID="49010" PicCommunicationValue="malcolm1411915" AuthorityID="112001,112002,112004" Remark="newsaving02" IsSyncFromPicTable="1"/>
                                                           <StaffAndAuthority RowID="-1" HeadlineID="1211024" PicID="" PicName="test01,test02" PicRoleID="48001" PicCommunicationID="49000" PicCommunicationValue="telegram01" AuthorityID="112003,112005" Remark="manually add" IsSyncFromPicTable="0"/>
                                                       </ROOT>'
        DECLARE @ErrCode_out INT = 0
        DECLARE @ErrMsg_out NVARCHAR(4000) = ''
        EXEC bodb_CRM.dbo.Acc_CRM_NewAccDetail_UpdHeadlineStaffAndAuthority @HeadlineID        = 1211024,
                                                                            @StaffAndAuthority = @StaffAndAuthority_in,
                                                                            @UserID            = 8,
                                                                            @IP                = '10.0.0.4',
                                                                            @ErrCode           = @ErrCode_out OUTPUT,
                                                                            @ErrMsg            = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out ErrCode, @ErrMsg_out ErrMsg
*/

BEGIN

    SET NOCOUNT ON


    -------------------------------------------------------------------------
    -- Parse data from @StaffAndAuthority to temp table #tmpStaffAndAuthority

    DECLARE @iDoc INT
    EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @StaffAndAuthority

    CREATE TABLE #tmpStaffAndAuthority (
        RowID                 INT,
        HeadlineID            INT,
        PicID                 INT,
        PicName               NVARCHAR(200),
        PicRoleID             INT,
        PicCommunicationID    INT,
        PicCommunicationValue NVARCHAR(200),
        AuthorityID           VARCHAR(MAX),
        Remark                NVARCHAR(4000),
        isSyncFromPicTable    BIT
    )

    INSERT INTO #tmpStaffAndAuthority (
        RowID,
        HeadlineID,
        PicID,
        PicName,
        PicRoleID,
        PicCommunicationID,
        PicCommunicationValue,
        AuthorityID,
        Remark,
        isSyncFromPicTable
    )
    SELECT ox.RowID,
           ox.HeadlineID,
           ox.PicID,
           ox.PicName,
           ox.PicRoleID,
           ox.PicCommunicationID,
           ox.PicCommunicationValue,
           ox.AuthorityID,
           ox.Remark,
           ox.IsSyncFromPicTable
    FROM OPENXML(@iDoc, '/ROOT/StaffAndAuthority', 1)
    WITH (RowID                 INT,
          HeadlineID            INT,
          PicID                 INT,
          PicName               NVARCHAR(200),
          PicRoleID             INT,
          PicCommunicationID    INT,
          PicCommunicationValue NVARCHAR(200),
          AuthorityID           VARCHAR(MAX),
          Remark                NVARCHAR(4000),
          IsSyncFromPicTable    BIT) AS ox


    ---------------------------------------
    -- Get old value of Staff and Authority

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
    WHERE cha.HeadlineID = @HeadlineID
    GROUP BY cha.RowID,
             cha.HeadlineID,
             cha.PicName,
             sr.SettingValue,
             sc.SettingValue,
             cha.PicCommunicationValue,
             cha.Remark,
             cha.isSyncFromPicTable,
             cha.CreatedDate
    ORDER BY cha.isSyncFromPicTable DESC,
             CASE WHEN cha.isSyncFromPicTable = 1 AND sr.SettingValue = 'Boss' THEN 1 ELSE 2 END,
             CASE WHEN cha.isSyncFromPicTable = 1 AND sr.SettingValue = 'Boss' THEN cha.PicName END,
             CASE WHEN cha.isSyncFromPicTable = 1 THEN sr.SettingValue END,
             CASE WHEN cha.isSyncFromPicTable = 1 THEN cha.PicName END,
             CASE WHEN cha.isSyncFromPicTable = 0 THEN cha.CreatedDate END
    OPTION (RECOMPILE)


    ---------------------------------------
    -- Update value for Staff and Authority

    BEGIN TRY    
        MERGE bodb_CRM.dbo.crmCustomerHeadlineStaffAndAuthority AS TARGET
        USING #tmpStaffAndAuthority AS SOURCE
        ON TARGET.HeadlineID = SOURCE.HeadlineID AND
           TARGET.RowID      = SOURCE.RowID
        WHEN MATCHED THEN
            UPDATE SET TARGET.PicName               = SOURCE.PicName,
                       TARGET.PicRoleID             = SOURCE.PicRoleID,
                       TARGET.PicCommunicationID    = SOURCE.PicCommunicationID,
                       TARGET.PicCommunicationValue = SOURCE.PicCommunicationValue,
                       TARGET.AuthorityID           = SOURCE.AuthorityID,
                       TARGET.Remark                = SOURCE.Remark
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                HeadlineID,
                PicID,
                PicName,
                PicRoleID,
                PicCommunicationID,
                PicCommunicationValue,
                AuthorityID,
                Remark,
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
                SOURCE.AuthorityID,
                SOURCE.Remark,
                SOURCE.isSyncFromPicTable,
                GETDATE()
            )
        WHEN NOT MATCHED BY SOURCE AND TARGET.HeadlineID = @HeadlineID
            THEN DELETE;
    END TRY
    BEGIN CATCH
        SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
        RETURN
    END CATCH


    ---------------------------------------
    -- Get new value of Staff and Authority

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
    WHERE cha.HeadlineID = @HeadlineID
    GROUP BY cha.RowID,
             cha.HeadlineID,
             cha.PicName,
             sr.SettingValue,
             sc.SettingValue,
             cha.PicCommunicationValue,
             cha.Remark,
             cha.isSyncFromPicTable,
             cha.CreatedDate
    ORDER BY cha.isSyncFromPicTable DESC,
             CASE WHEN cha.isSyncFromPicTable = 1 AND sr.SettingValue = 'Boss' THEN 1 ELSE 2 END,
             CASE WHEN cha.isSyncFromPicTable = 1 AND sr.SettingValue = 'Boss' THEN cha.PicName END,
             CASE WHEN cha.isSyncFromPicTable = 1 THEN sr.SettingValue END,
             CASE WHEN cha.isSyncFromPicTable = 1 THEN cha.PicName END,
             CASE WHEN cha.isSyncFromPicTable = 0 THEN cha.CreatedDate END
    OPTION (RECOMPILE)


    ---------------
    -- Write log --

    -- Prepare data
    -- + Variables
    DECLARE @CountRow                   INT
    DECLARE @getRowID                   INT
    DECLARE @getHeadlineID              INT
    DECLARE @StaffAndAuthorityOldValue  XML
    DECLARE @StaffAndAuthorityNewValue  XML
    DECLARE @StaffAndAuthorityNullValue XML = '<Acc_CRM_NewAccDetail_UpdHeadlineStaffAndAuthority>' +
                                              '<StaffAndAuthority>' +
                                              '</StaffAndAuthority>' +
                                              '</Acc_CRM_NewAccDetail_UpdHeadlineStaffAndAuthority>'
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
        SELECT @StaffAndAuthorityOldValue = '<Acc_CRM_NewAccDetail_UpdHeadlineStaffAndAuthority>' +
                                            '<StaffAndAuthority>' +
                                            ISNULL(OldValue, '') +
                                            '</StaffAndAuthority>' +
                                            '</Acc_CRM_NewAccDetail_UpdHeadlineStaffAndAuthority>'
        FROM #tmpDataToLoop
        WHERE RowID = @getRowID AND HeadlineID = @getHeadlineID

        IF (@StaffAndAuthorityOldValue IS NULL)
        BEGIN
            SET @StaffAndAuthorityOldValue = @StaffAndAuthorityNullValue
        END

        -- + Get value to @StaffAndAuthorityNewValue
        SELECT @StaffAndAuthorityNewValue = '<Acc_CRM_NewAccDetail_UpdHeadlineStaffAndAuthority>' +
                                            '<StaffAndAuthority>' +
                                            ISNULL(NewValue, '') +
                                            '</StaffAndAuthority>' +
                                            '</Acc_CRM_NewAccDetail_UpdHeadlineStaffAndAuthority>'
        FROM #tmpDataToLoop
        WHERE RowID = @getRowID AND HeadlineID = @getHeadlineID

        IF (@StaffAndAuthorityNewValue IS NULL)
        BEGIN
            SET @StaffAndAuthorityNewValue = @StaffAndAuthorityNullValue
        END

        -- + Write log
        IF (ISNULL(CAST(@StaffAndAuthorityOldValue AS NVARCHAR(MAX)), '') <> ISNULL(CAST(@StaffAndAuthorityNewValue AS NVARCHAR(MAX)), ''))
        BEGIN
            EXEC bodb_CRM.dbo.WriteLog_UserLog_crmLogCustomer @CustID    = @getHeadlineID,
                                                              @UserID    = @UserID,
                                                              @ActionID  = 112,
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


    ------------------
    -- Drop temp table

    DROP TABLE #tmpStaffAndAuthority
    DROP TABLE #tmpStaffAndAuthorityOldValue
    DROP TABLE #tmpStaffAndAuthorityNewValue
    DROP TABLE #tmpDataToLoop

END
GO