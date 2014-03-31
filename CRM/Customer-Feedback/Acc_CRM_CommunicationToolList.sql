
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CommunicationToolList    Script Date: 3/26/2014 6:06:10 PM ******/
create procedure Acc_CRM_CommunicationToolList
AS
select * from crmCommunicationTool(nolock) where IsActive = 1
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CommunicationToolList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CommunicationToolList] TO [vnteam]
GO 
