/*<info serverAlias="DBCRM-bodb_CRM"></info>*/
/*
	Created: 20231006@Malcolm
	Task : Rename Sps
	DB: DBCRM/bodb_CRM
	
*/

EXEC sp_rename 'Task_BackupFull', 'DEL_Task_BackupFull'
GO
EXEC sp_rename 'Task_STDBY_SYN_CRM_TableCTIns', 'DEL_Task_STDBY_SYN_CRM_TableCTIns'
GO
EXEC sp_rename 'Task_STDBY_SYN_CRM_TableCTSel', 'DEL_Task_STDBY_SYN_CRM_TableCTSel'
GO
EXEC sp_rename 'Task_STDBY_Sync_CRM', 'DEL_Task_STDBY_Sync_CRM'
GO
EXEC sp_rename 'Task_STDBY_Sync_CRM_Add_IDENT', 'DEL_Task_STDBY_Sync_CRM_Add_IDENT'
GO
EXEC sp_rename 'Task_STDBY_SYNC_CRM_currentVersion', 'DEL_Task_STDBY_SYNC_CRM_currentVersion'
GO
EXEC sp_rename 'Task_STDBY_SYNC_CRM_Log', 'DEL_Task_STDBY_SYNC_CRM_Log'
GO
