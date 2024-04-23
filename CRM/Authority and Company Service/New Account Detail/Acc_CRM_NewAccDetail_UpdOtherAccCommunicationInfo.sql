/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo @CustID                INT,
                                                                      @NewCommunicationTools NVARCHAR(MAX),
                                                                      @UserID                INT,
                                                                      @IP                    VARCHAR(45)    = '',
                                                                      @ErrCode               INT            = 0  OUTPUT,
                                                                      @ErrMsg                NVARCHAR(4000) = '' OUTPUT
AS

/*
    Created: Ned.Le
    Date:    20231212
    Task:    Insert/Update/Delete communication info of customer (non headline account)
    DB:      DBCRM.bodb_CRM

    Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

    Param's Explanation:
        @CustID:                CustID that its data be manipulated
        @NewCommunicationTools: <ROOT>
                                    <NewCommunicationTool CommunicationID="49001" CommunicationValue="023568974,0909862546"/>
                                    <NewCommunicationTool CommunicationID="49006" CommunicationValue="whatsapp01,whatsapp02"/>
                                </ROOT>

    Example:
        DECLARE @NewCommunicationTools_in NVARCHAR(MAX) = '<ROOT>
                                                               <NewCommunicationTool CommunicationID="49001" CommunicationValue="023568974,0909862546"/>
                                                               <NewCommunicationTool CommunicationID="49006" CommunicationValue="whatsapp01,whatsapp02"/>
                                                           </ROOT>'
        DECLARE @ErrCode_out INT = 0
        DECLARE @ErrMsg_out NVARCHAR(4000) = ''
        EXEC bodb_CRM.dbo.Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo @CustID                = 753649,
                                                                            @NewCommunicationTools = @NewCommunicationTools_in,
                                                                            @UserID                = 8,
                                                                            @IP                    = '10.0.0.4',
                                                                            @ErrCode               = @ErrCode_out OUTPUT,
                                                                            @ErrMsg                = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out ErrCode, @ErrMsg_out ErrMsg
*/

BEGIN

    SET NOCOUNT ON

    -- Prepare data for XML parameter
    DECLARE @CommunicationInfoNullValue XML
    SELECT  @CommunicationInfoNullValue = '<Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo>' +
                                          '<NewCommunicationTool>' +
                                          '</NewCommunicationTool>' +
                                          '</Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo>'

    -- Parse data from @NewCommunicationTools to temp table #tmpNewCommunicationTools
    DECLARE @iDoc INT
    EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @NewCommunicationTools

    CREATE TABLE #tmpNewCommunicationTools (
        CommunicationID    INT,
        CommunicationValue NVARCHAR(MAX)
    )

    INSERT INTO #tmpNewCommunicationTools (
        CommunicationID,
        CommunicationValue
    )
    SELECT ox.CommunicationID,
           ox.CommunicationValue
    FROM OPENXML(@iDoc, '/ROOT/NewCommunicationTool', 1)
    WITH (CommunicationID INT, CommunicationValue NVARCHAR(MAX)) AS ox

    -- Get old value of Communication Info
    DECLARE @CommunicationInfoOldValue XML
    SELECT  @CommunicationInfoOldValue = '<Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo>' +
                                         '<NewCommunicationTool>' +
                                         STRING_AGG(CAST(ISNULL(bodb_CRM.dbo.f_EncodeXMLValue(sc.SettingValue + ': ' + cnc.CommunicationValue), '') AS NVARCHAR(MAX)), '<br/>') WITHIN GROUP (ORDER BY sc.SettingValue) +
                                         '</NewCommunicationTool>' +
                                         '</Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo>'
    FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool cnc WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cnc.CommunicationID = sc.SettingID
    WHERE cnc.CustID = @CustID
    OPTION (RECOMPILE)

    IF (@CommunicationInfoOldValue IS NULL)
    BEGIN
        SET @CommunicationInfoOldValue = @CommunicationInfoNullValue
    END

    -- Update value for Communication Info
    BEGIN TRY    
        MERGE bodb_CRM.dbo.crmCustomerNewCommunicationTool AS TARGET
        USING #tmpNewCommunicationTools AS SOURCE
        ON TARGET.CustID = @CustID AND TARGET.CommunicationID = SOURCE.CommunicationID
        WHEN MATCHED THEN
            UPDATE SET TARGET.CommunicationValue = SOURCE.CommunicationValue
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (CustID, CommunicationID, CommunicationValue)
            VALUES (@CustID, SOURCE.CommunicationID, SOURCE.CommunicationValue)
        WHEN NOT MATCHED BY SOURCE AND TARGET.CustID = @CustID
            THEN DELETE;
    END TRY
    BEGIN CATCH
        SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
        RETURN
    END CATCH
    
    -- Get new value of Communication Info
    DECLARE @CommunicationInfoNewValue XML
    SELECT  @CommunicationInfoNewValue = '<Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo>' +
                                         '<NewCommunicationTool>' +
                                         STRING_AGG(CAST(ISNULL(bodb_CRM.dbo.f_EncodeXMLValue(sc.SettingValue + ': ' + cnc.CommunicationValue), '') AS NVARCHAR(MAX)), '<br/>') WITHIN GROUP (ORDER BY sc.SettingValue) +
                                         '</NewCommunicationTool>' +
                                         '</Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo>'
    FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool cnc WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cnc.CommunicationID = sc.SettingID
    WHERE cnc.CustID = @CustID
    OPTION (RECOMPILE)

    IF (@CommunicationInfoNewValue IS NULL)
    BEGIN
        SET @CommunicationInfoNewValue = @CommunicationInfoNullValue
    END

    -- Write log
    EXEC bodb_CRM.dbo.WriteLog_UserLog_crmLogCustomer @CustID    = @CustID,
                                                      @UserID    = @UserID,
                                                      @ActionID  = 109,
                                                      @IP        = @IP,
                                                      @NewValues = @CommunicationInfoNewValue,
                                                      @OldValues = @CommunicationInfoOldValue

    -- Drop temp table
    DROP TABLE #tmpNewCommunicationTools

END
GO