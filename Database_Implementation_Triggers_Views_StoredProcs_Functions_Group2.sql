USE SUMMER_CAMP;
GO
/*******************************************************************************************************************
--This function will enable users to verify a permission for a student.
*******************************************************************************************************************/
GO
IF (OBJECT_ID('CAMP.fn_Check_Permission') IS NOT NULL) DROP FUNCTION [CAMP].[fn_Check_Permission]
GO
CREATE FUNCTION [CAMP].[fn_Check_Permission] (@StudentID int, @Persmission_Type varchar(50)) RETURNS VARCHAR(3)
AS
BEGIN

	DECLARE @IsPermitted VARCHAR(3)
	
	DECLARE @Cnt INT

	SELECT @Cnt=COUNT(1)
	FROM CAMP.STUDENT A
	INNER JOIN CAMP.MAP_STUDENT_PERMISSION B ON A.STUDENT_ID = B.STUDENT_ID
	INNER JOIN CAMP.PERMISSION_TYPE C ON B.PERMISSION_TYPE_ID=C.PERMISSION_TYPE_ID
	WHERE A.STUDENT_ID=@StudentID AND C.PERMISSION_TYPE=@Persmission_Type AND GETDATE() BETWEEN PERMISSION_START_DATE AND PERMISSION_END_DATE

	SELECT @IsPermitted=CASE WHEN @Cnt=0 THEN 'No' ELSE 'Yes' END 
	
	RETURN @IsPermitted
	
END

GO

/*******************************************************************************************************************
--This function will return total Classes that a student is enrolled/scheduled to attend.
*******************************************************************************************************************/
GO

IF (OBJECT_ID('CAMP.fn_GetCurrent_Class') IS NOT NULL) DROP FUNCTION [CAMP].[fn_GetCurrent_Class]

GO

CREATE FUNCTION [CAMP].[fn_GetCurrent_Class] (@StudentID INT) RETURNS INT
AS
BEGIN

	DECLARE @CntClasses VARCHAR(30)

	SELECT @CntClasses=COUNT(1) FROM CAMP.SCHEDULE A
	INNER JOIN CAMP.STUDENT_SCHEDULE B ON A.SCHEDULE_ID=B.SCHEDULE_ID AND B.STUDENT_ID=@StudentID
	GROUP BY B.STUDENT_ID	

	RETURN @CntClasses
END

GO

/*******************************************************************************************************************
--This is an all up View to view all users and the roles they are assigned to
*******************************************************************************************************************/
GO

IF (OBJECT_ID('CAMP.vwUserRoles') IS NOT NULL) DROP VIEW [CAMP].[vwUserRoles]

GO

CREATE VIEW [CAMP].[vwUserRoles]
AS 
SELECT 
	A.[USER_ID], 
	FIRST_NAME + ' ' + LAST_NAME AS [FULL_NAME],  
	CASE WHEN B.[USER_ID] IS NOT NULL THEN 'Yes' ELSE 'No' END AS IS_ADMIN,
	CASE WHEN C.[USER_ID] IS NOT NULL THEN 'Yes' ELSE 'No' END AS IS_INSTRUCTOR,
	CASE WHEN D.[USER_ID] IS NOT NULL THEN 'Yes' ELSE 'No' END AS IS_STUDENT,
	CASE WHEN E.[USER_ID] IS NOT NULL THEN 'Yes' ELSE 'No' END AS IS_PARENT,
	CASE WHEN F.[USER_ID] IS NOT NULL THEN 'Yes' ELSE 'No' END AS IS_WORKCREW,
	CASE WHEN A.IS_ACTIVE =1 THEN 'Active' ELSE 'InActive' END AS USER_STATUS
FROM CAMP.[USER] A
LEFT JOIN (
	SELECT [User_ID] FROM CAMP.MAP_USER_ROLE B1 
	INNER JOIN CAMP.ROLES B2 ON B1.ROLE_ID=B2.ROLE_ID AND B2.ROLE_NAME='Administrator') B
ON A.[USER_ID] = B.[USER_ID]
LEFT JOIN (
	SELECT [User_ID] FROM CAMP.MAP_USER_ROLE C1 
	INNER JOIN CAMP.ROLES C2 ON C1.ROLE_ID=C2.ROLE_ID AND C2.ROLE_NAME='instructor') C
ON A.[USER_ID] = C.[USER_ID]
LEFT JOIN (
	SELECT [User_ID] FROM CAMP.MAP_USER_ROLE D1 
	INNER JOIN CAMP.ROLES D2 ON D1.ROLE_ID=D2.ROLE_ID AND D2.ROLE_NAME='Student') D
ON A.[USER_ID] = D.[USER_ID]
LEFT JOIN (
	SELECT [User_ID] FROM CAMP.MAP_USER_ROLE E1 
	INNER JOIN CAMP.ROLES E2 ON E1.ROLE_ID=E2.ROLE_ID AND E2.ROLE_NAME='parent') E
ON A.[USER_ID] = E.[USER_ID]
LEFT JOIN (
	SELECT [User_ID] FROM CAMP.MAP_USER_ROLE F1 
	INNER JOIN CAMP.ROLES F2 ON F1.ROLE_ID=F2.ROLE_ID AND F2.ROLE_NAME='work crews') F
ON A.[USER_ID] = F.[USER_ID]

GO


/*******************************************************************************************************************
--This procedure will fetch current list of activities fior a building, including rooms, classes and total an estimated #students in the class. 
*******************************************************************************************************************/
GO

IF (OBJECT_ID('CAMP.usp_GetCurrentBuildingActivity') IS NOT NULL)  DROP PROCEDURE [CAMP].[usp_GetCurrentBuildingActivity]

GO

CREATE PROCEDURE [CAMP].[usp_GetCurrentBuildingActivity] @BUILDING_NAME VARCHAR(20)
AS
SELECT 
	t2.CLASS_NAME,
	t3.FIRST_NAME+t3.LAST_NAME as STAFF_NAME, 
	t4.ROOM_NAME, 
	sub_t6.NumberOfStudents AS TOTAL_STUDENTS
FROM CAMP.SCHEDULE t1
INNER JOIN CAMP.CLASS t2 ON t2.CLASS_ID = t1.CLASS_ID
INNER JOIN CAMP.[USER] t3 ON t3.USER_ID = t1.STAFF_ID
INNER JOIN CAMP.ROOM t4 ON t4.ROOM_ID = t1.ROOM_ID
INNER JOIN CAMP.BUILDING t5 ON t5.BUILDING_ID = t4.BUILDING_ID 
LEFT JOIN 
 (
	 SELECT 
		t1.SCHEDULE_ID, 
		COUNT(Distinct(t1.STUDENT_ID)) AS NumberOfStudents
	 FROM CAMP.STUDENT_SCHEDULE t1
	 INNER JOIN CAMP.SCHEDULE t2 ON t2.SCHEDULE_ID = t1.SCHEDULE_ID
	 GROUP BY t1.SCHEDULE_ID 
 ) Sub_t6 ON t1.SCHEDULE_ID = Sub_t6.SCHEDULE_ID
 WHERE BUILDING_NAME =  @BUILDING_NAME

GO

/*******************************************************************************************************************
--This Trigger will insert the ScheduleID into the Notifications table, Whenever there is a change in the Schedule
*******************************************************************************************************************/

GO
IF EXISTS (SELECT * FROM sys.objects WHERE [name] = N'TRG_NOTIFY_SCHEDULE_CHANGE' AND [type] = 'TR')
BEGIN
      DROP TRIGGER [CAMP].[TRG_NOTIFY_SCHEDULE_CHANGE];
END;

GO

CREATE TRIGGER [CAMP].[TRG_NOTIFY_SCHEDULE_CHANGE] ON [CAMP].[SCHEDULE]
AFTER UPDATE
AS  
BEGIN 
    INSERT INTO CAMP.NOTIFICATIONS
    SELECT d.Schedule_ID, 0 AS Notify_Status, getdate()      
    FROM Inserted d
END

GO

/*******************************************************************************************************************
--This is an all up View to view all students and their schedule
*******************************************************************************************************************/

GO 
IF (OBJECT_ID('CAMP.vwStudentsSchedules') IS NOT NULL) DROP VIEW [CAMP].[vwStudentsSchedules]
GO
CREATE VIEW [CAMP].[vwStudentsSchedules]
AS 
	SELECT u.FIRST_NAME,u.LAST_NAME,c.CLASS_NAME,
	       s.ROOM_ID,r.BUILDING_ID,s.START_TIME,
		   s.END_TIME, s.CLASS_DATE
    FROM [SUMMER_CAMP].[CAMP].[SCHEDULE] s
			JOIN [SUMMER_CAMP].[CAMP].[STUDENT_SCHEDULE] su 
			ON su.SCHEDULE_ID = s.SCHEDULE_ID
			JOIN [SUMMER_CAMP].[CAMP].[CLASS] c 
			ON c.CLASS_ID = s.CLASS_ID
			JOIN [SUMMER_CAMP].[CAMP].[USER] u
			ON u.USER_ID = su.STUDENT_ID
			JOIN [SUMMER_CAMP].[CAMP].[ROOM] r 
			ON r.ROOM_ID = s.ROOM_ID
	WHERE u.IS_ACTIVE = 1

GO

/*******************************************************************************************************************
--This is an all up View to view all teachers and their schedule
*******************************************************************************************************************/

GO 
IF (OBJECT_ID('CAMP.vwTeachersSchedules') IS NOT NULL) DROP VIEW [CAMP].[vwTeachersSchedules]
GO
CREATE VIEW [CAMP].[vwTeachersSchedules]
AS 
	SELECT u.FIRST_NAME,u.LAST_NAME,
	        c.CLASS_NAME,s.ROOM_ID,r.BUILDING_ID,
			s.START_TIME, s.END_TIME, s.CLASS_DATE
	FROM [SUMMER_CAMP].[CAMP].[SCHEDULE] s
		 JOIN [SUMMER_CAMP].[CAMP].[STAFF] st
		 ON st.STAFF_ID = s.STAFF_ID
		 JOIN [SUMMER_CAMP].[CAMP].[USER] u
		 ON u.USER_ID = s.STAFF_ID
		 JOIN [SUMMER_CAMP].[CAMP].[CLASS] c 
		 ON c.CLASS_ID = s.CLASS_ID
		 JOIN [SUMMER_CAMP].[CAMP].[ROOM] r 
	     ON r.ROOM_ID = s.ROOM_ID
		 JOIN [SUMMER_CAMP].[CAMP].[MAP_USER_ROLE] ro 
		 ON ro.USER_ID = u.USER_ID
	WHERE u.IS_ACTIVE = 1 AND ro.ROLE_ID in (2, 1)



GO


/*******************************************************************************************************************
--This is an all up View to view all active users 
*******************************************************************************************************************/
GO 
IF (OBJECT_ID('CAMP.vwCurrentActiveUsers') IS NOT NULL) DROP VIEW [CAMP].[vwCurrentActiveUsers]
GO
CREATE VIEW [CAMP].[vwCurrentActiveUsers]
AS
	SELECT 
		  u.FIRST_NAME + ' '  + u.LAST_NAME as 'User name',
		  rs.ROLE_NAME
	FROM [SUMMER_CAMP].[CAMP].[USER] u
		 JOIN [CAMP].[MAP_USER_ROLE] r 
		 ON r.USER_ID = u.USER_ID
		 JOIN [SUMMER_CAMP].[CAMP].[ROLES] rs 
		 ON rs.ROLE_ID =r.ROLE_ID
	WHERE u.IS_ACTIVE = 1

GO
/*******************************************************************************************************************
--This is an all up View to view all inactive users 
*******************************************************************************************************************/
GO 
IF (OBJECT_ID('CAMP.vwCurrentInactiveUsers') IS NOT NULL) DROP VIEW [CAMP].[vwCurrentInactiveUsers]
GO
CREATE VIEW [CAMP].[vwCurrentInactiveUsers]
 AS
	SELECT 
		  u.FIRST_NAME + ' '  + u.LAST_NAME as 'User name',
		  rs.ROLE_NAME
	FROM [SUMMER_CAMP].[CAMP].[USER] u
		JOIN [CAMP].[MAP_USER_ROLE] r 
		ON r.USER_ID = u.USER_ID
		JOIN [SUMMER_CAMP].[CAMP].[ROLES] rs 
		ON rs.ROLE_ID =r.ROLE_ID
	WHERE u.IS_ACTIVE = 0
GO

/*******************************************************************************************************************
--This function returns students who have more than one permissions release 
*******************************************************************************************************************/
GO
IF (OBJECT_ID('CAMP.fn_StudentWithMultiPermissions') IS NOT NULL) DROP FUNCTION [CAMP].[fn_StudentWithMultiPermissions]
GO
CREATE FUNCTION [CAMP].[fn_StudentWithMultiPermissions] 
()
RETURNS @MultiPermissions TABLE
  (
    StudentName nvarchar(100),
	Total smallint
  )
AS
BEGIN 
	INSERT @MultiPermissions
	SELECT s.FIRST_NAME + ' '  + s.LAST_NAME, COUNT(PERMISSION_TYPE_ID)
    FROM [SUMMER_CAMP].[CAMP].[MAP_STUDENT_PERMISSION] p
	JOIN [SUMMER_CAMP].[CAMP].[USER] s ON s.USER_ID = p.STUDENT_ID
    GROUP BY s.FIRST_NAME + ' '  + s.LAST_NAME
    HAVING COUNT(PERMISSION_TYPE_ID) > 1
RETURN
END
GO

/*******************************************************************************************************************
--This trigger does not allow users to be deleted from the SUMMER_CAMP table
*******************************************************************************************************************/

GO
IF EXISTS (SELECT * FROM sys.objects WHERE [name] = N'USER_DELETE' AND [type] = 'TR')
BEGIN
      DROP TRIGGER [CAMP].[USER_DELETE];
END;

GO
CREATE TRIGGER [CAMP].[USER_DELETE] ON [SUMMER_CAMP].[CAMP].[USER]
FOR DELETE
AS 
IF (SELECT COUNT(*) FROM Deleted) >= 1
BEGIN
	RAISERROR(
		'You cannot delete any users instead set the Is_ACTIVE flag to false for the related user',
		16, 1)
	ROLLBACK TRANSACTION
END
GO

/*******************************************************************************************************************
This trigger does not allow employee's budget to be changed
*******************************************************************************************************************/
GO
IF EXISTS (SELECT * FROM sys.objects WHERE [name] = N'STUDENT_PAYMENT_UPDATE' AND [type] = 'TR')
BEGIN
      DROP TRIGGER [CAMP].[STUDENT_PAYMENT_UPDATE];
END;
GO
CREATE TRIGGER [CAMP].[STUDENT_PAYMENT_UPDATE]
  ON [SUMMER_CAMP].[CAMP].[MAP_STUDENT_PAYMENT]
  FOR UPDATE
AS 
IF UPDATE (PAYMENT_DUE_DATE)
BEGIN 
    BEGIN TRANSACTION
	RAISERROR(
		'Updating the payment due date for a specific camp is not allowed',
		10, 1)
	ROLLBACK TRANSACTION
END
GO

/*******************************************************************************************************************
--This procedure will  report a student's schedule
*******************************************************************************************************************/
GO

IF (OBJECT_ID('CAMP.uspGetReportingStudentAndAssignedClasses') IS NOT NULL)  DROP PROCEDURE [CAMP].[uspGetReportingStudentAndAssignedClasses]

GO
 CREATE PROC [CAMP].[uspGetReportingStudentAndAssignedClasses] @studentId int
 AS
    SELECT u.FIRST_NAME,u.LAST_NAME,
	        c.CLASS_NAME,s.ROOM_ID,r.BUILDING_ID,
			s.START_TIME, s.END_TIME, s.CLASS_DATE
	FROM [SUMMER_CAMP].[CAMP].[SCHEDULE] s
		 JOIN [SUMMER_CAMP].[CAMP].[STAFF] st
		 ON st.STAFF_ID = s.STAFF_ID
		 JOIN [SUMMER_CAMP].[CAMP].[USER] u
		 ON u.USER_ID = s.STAFF_ID
		 JOIN [SUMMER_CAMP].[CAMP].[CLASS] c 
		 ON c.CLASS_ID = s.CLASS_ID
		 JOIN [SUMMER_CAMP].[CAMP].[ROOM] r 
	     ON r.ROOM_ID = s.ROOM_ID
		 JOIN [SUMMER_CAMP].[CAMP].[MAP_USER_ROLE] ro 
		 ON ro.USER_ID = u.USER_ID
	WHERE u.IS_ACTIVE = 1 AND ro.ROLE_ID in (2, 1) AND u.USER_ID = @studentId

		
GO 	

/*******************************************************************************************************************
--This procedure will  report a teacher's schedule
*******************************************************************************************************************/
GO

IF (OBJECT_ID('CAMP.uspGetReportingTeacherAndAssignedClasses') IS NOT NULL)  DROP PROCEDURE [CAMP].[uspGetReportingTeacherAndAssignedClasses]

GO
CREATE PROC [CAMP].[uspGetReportingTeacherAndAssignedClasses] @instructorId int
AS
	SELECT u.FIRST_NAME,u.LAST_NAME,
	        c.CLASS_NAME,s.ROOM_ID,r.BUILDING_ID,
			s.START_TIME, s.END_TIME, s.CLASS_DATE
	FROM [SUMMER_CAMP].[CAMP].[SCHEDULE] s
		 JOIN [SUMMER_CAMP].[CAMP].[STAFF] st
		 ON st.STAFF_ID = s.STAFF_ID
		 JOIN [SUMMER_CAMP].[CAMP].[USER] u
		 ON u.USER_ID = s.STAFF_ID
		 JOIN [SUMMER_CAMP].[CAMP].[CLASS] c 
		 ON c.CLASS_ID = s.CLASS_ID
		 JOIN [SUMMER_CAMP].[CAMP].[ROOM] r 
	     ON r.ROOM_ID = s.ROOM_ID
	WHERE u.USER_ID = @instructorId AND u.IS_ACTIVE = 1
	
GO

/*******************************************************************************************************************
-- Report to display weekly scheduled activities - This will create a report giving information about class 
schedule and associated rooms and building
*******************************************************************************************************************/
GO 	
IF (OBJECT_ID('CAMP.vw_getweeklyschedule') IS NOT NULL) DROP VIEW [CAMP].[vw_getweeklyschedule]
GO

CREATE VIEW [CAMP].[vw_getweeklyschedule]
AS
	SELECT 
		c.CLASS_NAME, 
		r.ROOM_NAME, 
		r.BUILDING_ID, 
		s.SCHEDULE_ID, 
		s.CLASS_DATE, 
		s.START_TIME, 
		s.END_TIME
	FROM [SUMMER_CAMP].[CAMP].[SCHEDULE] s
	INNER JOIN [SUMMER_CAMP].[CAMP].[CLASS] c 
		ON c.CLASS_ID = s.CLASS_ID
	INNER JOIN [SUMMER_CAMP].[CAMP].[ROOM] r 
		ON r.ROOM_ID = s.ROOM_ID
	WHERE s.CLASS_DATE = GETDATE() + 7;
GO

/*******************************************************************************************************************
--This procedure check student's permission and also check the duration for which the student is exempted
*******************************************************************************************************************/
GO
IF (OBJECT_ID('CAMP.usp_getstudentpermissions') IS NOT NULL) DROP PROCEDURE [CAMP].[usp_getstudentpermissions]
GO
 
CREATE PROCEDURE [CAMP].[usp_getstudentpermissions] @STUDENT_ID INT
AS
   SELECT 
	u.FIRST_NAME, 
	u.LAST_NAME, 
	sp.PERMISSION_START_DATE, 
	sp.PERMISSION_END_DATE, 
	pt.PERMISSION_TYPE, 
	pt.PERMISSION_TYPE_DESC
    FROM [SUMMER_CAMP].[CAMP].[MAP_STUDENT_PERMISSION] sp
	INNER JOIN [SUMMER_CAMP].[CAMP].[USER] u
		ON sp.[STUDENT_ID] = u.[USER_ID]
	INNER JOIN [SUMMER_CAMP].[CAMP].[PERMISSION_TYPE] pt 
		ON sp.PERMISSION_TYPE_ID = pt.PERMISSION_TYPE_ID
	WHERE sp.STUDENT_ID = @STUDENT_ID
GO

/*******************************************************************************************************************
-- Report to show permission - creating a view for everyone to check student's permission 
*******************************************************************************************************************/
GO

IF (OBJECT_ID('CAMP.vw_getstudentpermissions') IS NOT NULL) DROP VIEW [CAMP].[vw_getstudentpermissions]
GO

CREATE VIEW [CAMP].[vw_getstudentpermissions]
AS
   SELECT 
	u.FIRST_NAME, 
	u.LAST_NAME, 
	sp.PERMISSION_START_DATE, 
	sp.PERMISSION_END_DATE, 
	pt.PERMISSION_TYPE, 
	pt.PERMISSION_TYPE_DESC
   FROM [SUMMER_CAMP].[CAMP].[MAP_STUDENT_PERMISSION] sp
   INNER JOIN [SUMMER_CAMP].[CAMP].[USER] u
      ON sp.[STUDENT_ID] = u.[USER_ID]
   INNER JOIN [SUMMER_CAMP].[CAMP].[PERMISSION_TYPE] pt 
	  ON sp.PERMISSION_TYPE_ID = pt.PERMISSION_TYPE_ID
GO
/*******************************************************************************************************************
-- Report to show release - creating a view and stored proocedure to display release dates and exception categories
*******************************************************************************************************************/
GO
IF (OBJECT_ID('CAMP.vw_getreleaseinformation') IS NOT NULL) DROP VIEW [CAMP].[vw_getreleaseinformation]
GO

CREATE VIEW [CAMP].[vw_getreleaseinformation]
AS
	SELECT 
	u.FIRST_NAME, 
	u.LAST_NAME, 
	sr.RELEASE_START_DATE, 
	sr.RELEASE_END_DATE, 
	rt.RELEASE_TYPE, 
	rt.RELEASE_TYPE_DESC
    FROM [SUMMER_CAMP].[CAMP].[MAP_STUDENT_RELEASE] sr
	INNER JOIN [SUMMER_CAMP].[CAMP].[USER] u
		ON sr.[STUDENT_ID] = u.[USER_ID]
	INNER JOIN [SUMMER_CAMP].[CAMP].[RELEASE_TYPE] rt 
		ON sr.RELEASE_TYPE_ID = rt.RELEASE_TYPE_ID
GO
/*******************************************************************************************************************
-- This procedure will generate a report of release information of students
*******************************************************************************************************************/
GO

IF (OBJECT_ID('CAMP.usp_getreleaseinformation') IS NOT NULL) DROP PROCEDURE [CAMP].[usp_getreleaseinformation]
GO

CREATE PROCEDURE [CAMP].[usp_getreleaseinformation] @STUDENT_ID INT
AS
	SELECT 
	u.FIRST_NAME, 
	u.LAST_NAME, 
	sr.RELEASE_START_DATE, 
	sr.RELEASE_END_DATE, 
	rt.RELEASE_TYPE, 
	rt.RELEASE_TYPE_DESC
    FROM [SUMMER_CAMP].[CAMP].[MAP_STUDENT_RELEASE] sr
	INNER JOIN [SUMMER_CAMP].[CAMP].[USER] u
		ON sr.[STUDENT_ID] = u.[USER_ID]
	INNER JOIN [SUMMER_CAMP].[CAMP].[RELEASE_TYPE] rt 
		ON sr.RELEASE_TYPE_ID = rt.RELEASE_TYPE_ID
	WHERE sr.STUDENT_ID = @STUDENT_ID
GO

/*******************************************************************************************************************
-- Report to show payment - create a view and stored procedure to track payment status of students
*******************************************************************************************************************/
GO
IF (OBJECT_ID('CAMP.vw_getpaymentinformation') IS NOT NULL) DROP VIEW [CAMP].[vw_getpaymentinformation]
GO

CREATE VIEW [CAMP].[vw_getpaymentinformation]
AS
	SELECT 
	u.FIRST_NAME, 
	u.LAST_NAME, 
	sp.PAYMENT_DATE, 
	sp.PAYMENT_DUE_DATE, 
	ps.PAYMENT_STATUS, 
	sp.CAMP_YEAR
    FROM [SUMMER_CAMP].[CAMP].[MAP_STUDENT_PAYMENT] sp
	INNER JOIN [SUMMER_CAMP].[CAMP].[USER] u
		ON sp.[STUDENT_ID] = u.[USER_ID]
	INNER JOIN [SUMMER_CAMP].[CAMP].[PAYMENT_STATUS] ps 
		ON sp.PAYMENT_STATUS_ID = ps.PAYMENT_STATUS_ID
GO
/*******************************************************************************************************************
-- This procedure allows to view the payment information of students by passing the student id
*******************************************************************************************************************/
GO
IF (OBJECT_ID('CAMP.usp_getpaymentinformation') IS NOT NULL) DROP PROCEDURE [CAMP].[usp_getpaymentinformation]
GO

CREATE PROCEDURE [CAMP].[usp_getpaymentinformation] @STUDENT_ID INT
AS
	SELECT 
	u.FIRST_NAME, 
	u.LAST_NAME, 
	sp.PAYMENT_DATE, 
	sp.PAYMENT_DUE_DATE, 
	ps.PAYMENT_STATUS, 
	sp.CAMP_YEAR
    FROM [SUMMER_CAMP].[CAMP].[MAP_STUDENT_PAYMENT] sp
	INNER JOIN [SUMMER_CAMP].[CAMP].[USER] u
		ON sp.[STUDENT_ID] = u.[USER_ID]
	INNER JOIN [SUMMER_CAMP].[CAMP].[PAYMENT_STATUS] ps 
		ON sp.PAYMENT_STATUS_ID = ps.PAYMENT_STATUS_ID
	WHERE sp.STUDENT_ID = @STUDENT_ID
GO
/*******************************************************************************************************************
-- This procedure will generate a report that parents can access to view their child's information
*******************************************************************************************************************/
GO
IF (OBJECT_ID('CAMP.usp_GetChildDetails') IS NOT NULL) DROP PROCEDURE [CAMP].[usp_GetChildDetails]
GO

CREATE PROCEDURE [CAMP].[usp_GetChildDetails] @PARENT_ID INT
AS
SELECT
	u.FIRST_NAME,
	u.LAST_NAME,
	s.DATE_OF_BIRTH,
	sp.PAYMENT_DATE,
	sp.PAYMENT_DUE_DATE,
	ps.PAYMENT_STATUS,
	sp.CAMP_YEAR
FROM [CAMP].[STUDENT] s
JOIN [CAMP].[USER] u
	ON s.[STUDENT_ID] = u.[USER_ID]
JOIN [CAMP].[MAP_STUDENT_PAYMENT] sp
	ON sp.[STUDENT_ID] = s.[STUDENT_ID]
JOIN [CAMP].[PAYMENT_STATUS] ps
	ON sp.PAYMENT_STATUS_ID = ps.PAYMENT_STATUS_ID
WHERE s.PRIMARY_PARENT_ID = @PARENT_ID OR s.SECONDARY_PARENT_ID = @PARENT_ID

GO
