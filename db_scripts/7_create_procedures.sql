DELIMITER $$


CREATE OR REPLACE PROCEDURE P_CREATE_USER (
	IN PI_FIRST_NAME VARCHAR(255),
	IN PI_LAST_NAME VARCHAR(255),
	IN PI_USERNAME VARCHAR(255),
	IN PI_EMAIL VARCHAR(255),
	IN PI_PASSWORD_HASH CHAR(60),
	IN PI_PROFILE_PICTURE_PATH VARCHAR(255),
	IN PI_LANGUAGE_CODE VARCHAR(2),
	OUT PO_USER_ID INT
)
BEGIN
	INSERT INTO USERS (
		FIRST_NAME,
		LAST_NAME,
		USERNAME,
		EMAIL,
		PASSWORD_HASH,
		PROFILE_PICTURE_PATH,
		LANGUAGE_ISO_CODE
	)
	VALUES (
		PI_FIRST_NAME,
		PI_LAST_NAME,
		PI_USERNAME,
		PI_EMAIL,
		PI_PASSWORD_HASH,
		PI_PROFILE_PICTURE_PATH,
		PI_LANGUAGE_CODE
	);

	SET PO_USER_ID = LAST_INSERT_ID();
END;
$$


CREATE OR REPLACE PROCEDURE P_SET_USER_LANGUAGE(
	IN PI_USER_ID INT,
	IN PI_LANGUAGE_CODE VARCHAR(2)
)
BEGIN
	UPDATE USERS SET LANGUAGE_ISO_CODE = PI_LANGUAGE_CODE WHERE ID = PI_USER_ID;
END;
$$


CREATE OR REPLACE PROCEDURE P_CREATE_CATEGORY (
	IN PI_OWNER_ID INT,
	IN PI_NAME VARCHAR(255),
	IN PI_COLOR_SCHEME CHAR(7),
	OUT PO_CATEGORY_ID INT
)
BEGIN
	INSERT INTO CATEGORIES (
		OWNER_ID,
		NAME,
		COLOR_SCHEME_ID
	)
	VALUES (
		PI_OWNER_ID,
		PI_NAME,
		PI_COLOR_SCHEME
	);

	SET PO_CATEGORY_ID = LAST_INSERT_ID();
END;
$$


CREATE OR REPLACE PROCEDURE P_EDIT_CATEGORY (
	IN PI_ID INT,
	IN PI_OWNER_ID INT,
	IN PI_NAME VARCHAR(255),
	IN PI_COLOR_SCHEME_ID INT
)
BEGIN
	UPDATE 
		CATEGORIES
	SET 
		NAME = PI_NAME,
		COLOR_SCHEME_ID = PI_COLOR_SCHEME_ID
	WHERE
		ID = PI_ID AND
		OWNER_ID = PI_OWNER_ID;
END;
$$

CREATE OR REPLACE PROCEDURE P_DELETE_CATEGORY (
	IN PI_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_DEFAULT_CATEGORY_ID INT;

	SELECT COUNT(*) INTO @OWNER FROM CATEGORIES WHERE OWNER_ID = PI_USER_ID AND ID = PI_ID;

	IF @OWNER > 0 THEN
		SELECT MIN(ID) INTO V_DEFAULT_CATEGORY_ID
		FROM CATEGORIES
		WHERE OWNER_ID = PI_USER_ID;

		SET @DEFAULT_CATEGORY_ID = V_DEFAULT_CATEGORY_ID;

		-- Update the CATEGORY_ID of the rows that would be left without a category
		UPDATE FILES_HAVE_CATEGORIES
		SET CATEGORY_ID = @DEFAULT_CATEGORY_ID
		WHERE FILE_ID IN (
			SELECT FILE_ID FROM FILES_HAVE_CATEGORIES
			GROUP BY FILE_ID
			HAVING COUNT(*) = 1
		)
		AND CATEGORY_ID = PI_ID;

		UPDATE NOTES_HAVE_CATEGORIES
		SET CATEGORY_ID = @DEFAULT_CATEGORY_ID
		WHERE NOTE_ID IN (
			SELECT NOTE_ID FROM NOTES_HAVE_CATEGORIES
			GROUP BY NOTE_ID
			HAVING COUNT(*) = 1
		)
		AND CATEGORY_ID = PI_ID;

		UPDATE PROJECTS_HAVE_CATEGORIES
		SET CATEGORY_ID = @DEFAULT_CATEGORY_ID
		WHERE PROJECT_ID IN (
			SELECT PROJECT_ID FROM PROJECTS_HAVE_CATEGORIES
			GROUP BY PROJECT_ID
			HAVING COUNT(*) = 1
		)
		AND CATEGORY_ID = PI_ID;

		DELETE FROM FILES_HAVE_CATEGORIES
		WHERE CATEGORY_ID = PI_ID;

		DELETE FROM NOTES_HAVE_CATEGORIES
		WHERE CATEGORY_ID = PI_ID;

		DELETE FROM PROJECTS_HAVE_CATEGORIES
		WHERE CATEGORY_ID = PI_ID;

		DELETE FROM CATEGORIES
		WHERE ID = PI_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$

CREATE OR REPLACE PROCEDURE P_DELETE_FILE (
	IN PI_FILE_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_FILE_ID, 'FILE', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			FILE_PRIVILEGES
		WHERE 
			FILE_ID = PI_FILE_ID;

		DELETE FROM
			FILES_HAVE_CATEGORIES
		WHERE 
			FILE_ID = PI_FILE_ID;

		DELETE FROM NOTES_ATTACH_FILES
		WHERE FILE_ID = PI_FILE_ID;

		DELETE FROM 
			FILES 
		WHERE
			ID = PI_FILE_ID;

	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$

CREATE OR REPLACE PROCEDURE P_DELETE_NOTE (
	IN PI_NOTE_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_NOTE_ID, 'NOTE', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			NOTE_PRIVILEGES
		WHERE 
			NOTE_ID = PI_NOTE_ID;

		DELETE FROM
			NOTES_HAVE_CATEGORIES
		WHERE 
			NOTE_ID = PI_NOTE_ID;

		DELETE FROM
			NOTES_ATTACH_FILES
		WHERE 
			NOTE_ID = PI_NOTE_ID;

		DELETE FROM
			PROJECTS_ATTACH_NOTES
		WHERE 
			NOTE_ID = PI_NOTE_ID;

		DELETE FROM
			TASKS_ATTACH_NOTES
		WHERE 
			NOTE_ID = PI_NOTE_ID;

		DELETE FROM 
			NOTES 
		WHERE
			ID = PI_NOTE_ID;

	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$

CREATE OR REPLACE PROCEDURE P_REORDER_TASKS (
	IN PI_PROJECT_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_PROJECT_ID, 'PROJECT', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		UPDATE TASKS t
                JOIN (
                        SELECT 
				PROJECT_ID, 
				@rownum:=@rownum+1 AS new_place, 
				ID
                        FROM 
				TASKS, 
				(SELECT @rownum:=0) r
                        WHERE 
				PROJECT_ID = PI_PROJECT_ID
                        ORDER BY 
				PLACE
                ) x ON t.ID = x.ID
                SET t.PLACE = x.new_place;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_DELETE_TASK (
	IN PI_TASK_ID INT,
	IN PI_PROJECT_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_PROJECT_ID, 'PROJECT', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			TASK_PRIVILEGES
		WHERE 
			TASK_ID = PI_TASK_ID;

		DELETE FROM
			TASKS_ATTACH_NOTES
		WHERE 
			TASK_ID = PI_TASK_ID;

		DELETE FROM 
			TASKS
		WHERE
			ID = PI_TASK_ID;

		CALL P_REORDER_TASKS(PI_PROJECT_ID, PI_USER_ID);
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_DELETE_PROJECT (
	IN PI_PROJECT_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_PROJECT_ID, 'PROJECT', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			PROJECT_PRIVILEGES
		WHERE 
			PROJECT_ID = PI_PROJECT_ID;

		DELETE FROM
			PROJECTS_HAVE_CATEGORIES
		WHERE 
			PROJECT_ID = PI_PROJECT_ID;

		DELETE FROM
			PROJECTS_ATTACH_NOTES
		WHERE 
			PROJECT_ID = PI_PROJECT_ID;

		DELETE TN FROM
			TASKS_ATTACH_NOTES TN
			INNER JOIN TASKS T ON TN.TASK_ID = T.ID
		WHERE 
			T.PROJECT_ID = PI_PROJECT_ID;
	
		DELETE TP
		FROM 
			TASK_PRIVILEGES TP
			INNER JOIN TASKS T ON TP.TASK_ID = T.ID
		WHERE 
			T.PROJECT_ID = PI_PROJECT_ID;

		DELETE FROM 
			TASKS
		WHERE 
			PROJECT_ID = PI_PROJECT_ID;

		DELETE FROM 
			PROJECTS 
		WHERE
			ID = PI_PROJECT_ID;

	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$

CREATE OR REPLACE PROCEDURE P_CHECK_PRIVILEGES (
	IN PI_USER_ID INT,
	IN PI_OBJECT_ID INT,
	IN PI_OBJECT_TYPE VARCHAR(100),
	IN PI_PRIVILEGE VARCHAR(20),
	OUT PO_HAS_PRIVILEGE BOOLEAN
)
BEGIN
	DECLARE V_QUERY VARCHAR(1000);

	SET @TABLE_NAME = CONCAT(PI_OBJECT_TYPE, '_PRIVILEGES');
	SET @QUERY = CONCAT('
		SELECT
			COUNT(*) > 0
		INTO 
			@HAS_PRIVILEGE
		FROM ', 
			@TABLE_NAME ,'
		WHERE
			USER_ID = ? AND ',
			PI_OBJECT_TYPE ,'_ID = ? AND
			PRIVILEGE = ?;
	');

	PREPARE STMT FROM @QUERY;
	SET 
		@USER_ID = PI_USER_ID,
		@OBJECT_ID = PI_OBJECT_ID,
		@PRIVILEGE = PI_PRIVILEGE;
	EXECUTE STMT USING @USER_ID, @OBJECT_ID, @PRIVILEGE;
	DEALLOCATE PREPARE STMT;

	SET PO_HAS_PRIVILEGE = @HAS_PRIVILEGE;
END;
$$

CREATE OR REPLACE PROCEDURE P_APPEND_CATEGORY (
    IN PI_CATEGORY_ID INT,
    IN PI_OBJECT_ID INT,
    IN PI_OBJECT_TYPE VARCHAR(100),
    IN PI_USER_ID INT
)
BEGIN
    DECLARE V_QUERY VARCHAR(1000);
    DECLARE V_NUMBER_OF_ROWS INT;

    DECLARE V_IS_VIEWER BOOLEAN;

    -- Initialize session variables
    SET @table_name = NULL;
    SET @query = NULL;
    SET @num_rows = NULL;

    CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_OBJECT_ID, PI_OBJECT_TYPE, 'VIEW', V_IS_VIEWER);
    IF V_IS_VIEWER THEN
        SET @table_name = CONCAT(PI_OBJECT_TYPE, 'S_HAVE_CATEGORIES');
        SET @query = CONCAT('SELECT COUNT(*) INTO @num_rows FROM ', @table_name, ' WHERE ', PI_OBJECT_TYPE, '_ID = ? AND CATEGORY_ID = ?');
        PREPARE STMT FROM @query;
        EXECUTE STMT USING PI_OBJECT_ID, PI_CATEGORY_ID;
        DEALLOCATE PREPARE STMT;

        SET V_NUMBER_OF_ROWS = @num_rows;

        IF V_NUMBER_OF_ROWS = 0 THEN
            SET @query = CONCAT('INSERT INTO ', @table_name, '(', PI_OBJECT_TYPE, '_ID, CATEGORY_ID) VALUES (?, ?)');
            PREPARE STMT FROM @query;
            EXECUTE STMT USING PI_OBJECT_ID, PI_CATEGORY_ID;
            DEALLOCATE PREPARE STMT;
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-no-privileges';
    END IF;
END;


CREATE OR REPLACE PROCEDURE _P_GRANT_ACCESS (
	IN PI_USER_ID INT,
	IN PI_OBJECT_ID INT,
	IN PI_PRIVILEGE VARCHAR(10),
	IN PI_OBJECT_TYPE VARCHAR(50)
)
BEGIN
	DECLARE QUERY VARCHAR(500);
	DECLARE TABLE_NAME VARCHAR(500);

	SET TABLE_NAME = CONCAT(PI_OBJECT_TYPE, '_PRIVILEGES');
	SET QUERY = CONCAT('
		INSERT INTO ', TABLE_NAME, ' (
			USER_ID, 
			', PI_OBJECT_TYPE, '_ID, 
			PRIVILEGE
		) 
		VALUES (
			?, 
			?, 
			?
		)');

	PREPARE STMT FROM QUERY;
	EXECUTE STMT USING PI_USER_ID, PI_OBJECT_ID, PI_PRIVILEGE;
	DEALLOCATE PREPARE STMT;
END;
$$

CREATE OR REPLACE PROCEDURE P_UPLOAD_FILE (
	IN PI_ORIGINAL_NAME VARCHAR(1000),
	IN PI_SERVER_NAME VARCHAR(1000),
	IN PI_EXTENSION VARCHAR(100),
	IN PI_TITLE VARCHAR(1000),
	IN PI_DESCRIPTION TEXT,
	IN PI_USER_ID INT,
	OUT PO_FILE_ID INT
)
BEGIN
	-- HANDLE EMPTY STRINGS
	SET PI_ORIGINAL_NAME = NULLIF(PI_ORIGINAL_NAME, '');
	SET PI_SERVER_NAME = NULLIF(PI_SERVER_NAME, '');
	SET PI_EXTENSION = NULLIF(PI_EXTENSION, '');
	SET PI_TITLE = NULLIF(PI_TITLE, '');
	SET PI_DESCRIPTION = NULLIF(PI_DESCRIPTION , '');

	-- UPLOAD THE FILE.
	INSERT INTO FILES (
		ORIGINAL_NAME,
		SERVER_NAME,
		EXTENSION,
		TITLE,
		DESCRIPTION,
		UPLOADED_ON
	)
	VALUES (
		PI_ORIGINAL_NAME,
		PI_SERVER_NAME,
		PI_EXTENSION,
		PI_TITLE,
		PI_DESCRIPTION,
		NOW()
	);

	SET PO_FILE_ID = LAST_INSERT_ID();

	-- ADD THE ACCESSES.
	CALL _P_GRANT_ACCESS(PI_USER_ID, PO_FILE_ID, 'VIEW', 'FILE');
	CALL _P_GRANT_ACCESS(PI_USER_ID, PO_FILE_ID, 'EDIT', 'FILE');
END;
$$

CREATE OR REPLACE PROCEDURE P_UNAPPEND_CATEGORY (
	IN PI_USER_ID INT,
	IN PI_CATEGORY_ID INT,
	IN PI_OBJECT_ID INT,
	IN PI_OBJECT_TYPE VARCHAR(50)
)
BEGIN
	DECLARE QUERY VARCHAR(500);
	DECLARE TABLE_NAME VARCHAR(500);
	DECLARE NUM_ROWS INT;

	-- CHECK IF A VIEWER TRIES TO EDIT THE FILE.
	DECLARE IS_VIEWER BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_OBJECT_ID, 'V', PI_OBJECT_TYPE, IS_VIEWER);

	IF IS_VIEWER THEN 
		SET @TABLE_NAME = CONCAT(PI_OBJECT_TYPE, 'S_HAVE_CATEGORIES');
		SET QUERY = CONCAT('DELETE FROM ', @TABLE_NAME, ' WHERE CATEGORY_ID = ? AND ', PI_OBJECT_TYPE, '_ID = ?');
		PREPARE STMT FROM QUERY;
		EXECUTE STMT USING PI_CATEGORY_ID, PI_OBJECT_ID;
		DEALLOCATE PREPARE STMT;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'USER DOES NOT HAVE PRIVILEGES TO THE RESOURCE!';
	END IF;
END;
$$

CREATE OR REPLACE PROCEDURE P_EDIT_NOTE (
	IN PI_NOTE_ID INT,
	IN PI_TITLE VARCHAR(1000),
	IN PI_DESCRIPTION TEXT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_NOTE_ID, 'NOTE', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		UPDATE 
			NOTES
		SET 
			TITLE = PI_TITLE,
			DESCRIPTION = PI_DESCRIPTION
		WHERE 
			ID = PI_NOTE_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$

CREATE OR REPLACE PROCEDURE P_EDIT_PROJECT (
	IN PI_PROJECT_ID INT,
	IN PI_TITLE VARCHAR(1000),
	IN PI_DESCRIPTION TEXT,
	IN PI_DEADLINE DATETIME,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_PROJECT_ID, 'PROJECT', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		UPDATE 
			PROJECTS
		SET 
			TITLE = PI_TITLE,
			DESCRIPTION = PI_DESCRIPTION,
			DEADLINE = PI_DEADLINE
		WHERE 
			ID = PI_PROJECT_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$

CREATE OR REPLACE PROCEDURE P_EDIT_TASK (
	IN PI_TASK_ID INT,
	IN PI_BLOCKER BOOLEAN,
	IN PI_TITLE VARCHAR(1000),
	IN PI_DESCRIPTION TEXT,
	IN PI_DURATION INT,
	IN PI_DEADLINE DATETIME,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_TASK_ID, 'TASK', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		UPDATE 
			TASKS
		SET 
			BLOCKER = PI_BLOCKER,
			TITLE = PI_TITLE,
			DESCRIPTION = PI_DESCRIPTION,
			DURATION = PI_DURATION,
			DEADLINE = PI_DEADLINE
		WHERE 
			ID = PI_TASK_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$

CREATE OR REPLACE PROCEDURE P_EDIT_FILE (
	IN PI_FILE_ID INT,
	IN PI_ORIGINAL_NAME VARCHAR(255),
	IN PI_SERVER_NAME VARCHAR(255),
	IN PI_EXTENSION VARCHAR(25),
	IN PI_TITLE VARCHAR(1000),
	IN PI_DESCRIPTION TEXT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_FILE_ID, 'FILE', 'EDIT', V_IS_EDITOR);

	SET PI_ORIGINAL_NAME = NULLIF(PI_ORIGINAL_NAME, '');
	SET PI_SERVER_NAME = NULLIF(PI_SERVER_NAME, '');
	SET PI_EXTENSION = NULLIF(PI_EXTENSION, '');


	SET PI_ORIGINAL_NAME = IFNULL(PI_ORIGINAL_NAME, (SELECT ORIGINAL_NAME FROM FILES WHERE ID = PI_FILE_ID));
	SET PI_SERVER_NAME = IFNULL(PI_SERVER_NAME, (SELECT SERVER_NAME FROM FILES WHERE ID = PI_FILE_ID));
	SET PI_EXTENSION = IFNULL(PI_EXTENSION, (SELECT EXTENSION FROM FILES WHERE ID = PI_FILE_ID));

	IF V_IS_EDITOR THEN
		UPDATE 
			FILES
		SET 
			ORIGINAL_NAME = PI_ORIGINAL_NAME,
			SERVER_NAME = PI_SERVER_NAME,
			EXTENSION = PI_EXTENSION,
			TITLE = PI_TITLE,
			DESCRIPTION = PI_DESCRIPTION
		WHERE 
			ID = PI_FILE_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$

CREATE OR REPLACE PROCEDURE P_CREATE_NOTE (
	IN PI_TITLE VARCHAR(1000),
	IN PI_DESCRIPTION TEXT,
	IN PI_USER_ID INT,
	OUT PO_NOTE_ID INT
)
BEGIN
	SET PI_TITLE = NULLIF(PI_TITLE, '');
	SET PI_DESCRIPTION = NULLIF(PI_DESCRIPTION , '');

	INSERT INTO NOTES (
		TITLE,
		DESCRIPTION,
		CREATED_ON
	)
	VALUES (
		PI_TITLE,
		PI_DESCRIPTION,
		NOW()
	);

	SET PO_NOTE_ID = LAST_INSERT_ID();

	-- ADD THE ACCESSES.
	CALL _P_GRANT_ACCESS(PI_USER_ID, PO_NOTE_ID, 'VIEW', 'NOTE');
	CALL _P_GRANT_ACCESS(PI_USER_ID, PO_NOTE_ID, 'EDIT', 'NOTE');
END;
$$


CREATE OR REPLACE PROCEDURE P_UNATTACH_FILE_FROM_NOTE (
	IN PI_FILE_ID INT,
	IN PI_NOTE_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_NOTE_ID, 'NOTE', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			NOTES_ATTACH_FILES
		WHERE 
			NOTE_ID = PI_NOTE_ID AND
			FILE_ID = PI_FILE_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_UNATTACH_NOTE_FROM_PROJECT (
	IN PI_NOTE_ID INT,
	IN PI_PROJECT_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_PROJECT_ID, 'PROJECT', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			PROJECTS_ATTACH_NOTES
		WHERE 
			PROJECT_ID = PI_PROJECT_ID AND
			NOTE_ID = PI_NOTE_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_UNATTACH_NOTE_FROM_TASK (
	IN PI_NOTE_ID INT,
	IN PI_TASK_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_TASK_ID, 'TASK', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			TASKS_ATTACH_NOTES
		WHERE 
			TASK_ID = PI_TASK_ID AND
			NOTE_ID = PI_NOTE_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_UNATTACH_NOTES_FROM_TASK (
	IN PI_TASK_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_TASK_ID, 'TASK', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			TASKS_ATTACH_NOTES
		WHERE 
			TASK_ID = PI_TASK_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_UNATTACH_FILES_FROM_NOTE (
	IN PI_NOTE_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_NOTE_ID, 'NOTE', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			NOTES_ATTACH_FILES
		WHERE 
			NOTE_ID = PI_NOTE_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_UNATTACH_NOTES_FROM_PROJECT (
	IN PI_PROJECT_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_PROJECT_ID, 'PROJECT', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		DELETE FROM
			PROJECTS_ATTACH_NOTES
		WHERE 
			PROJECT_ID = PI_PROJECT_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_ATTACH_FILE_TO_NOTE (
	IN PI_FILE_ID INT,
	IN PI_NOTE_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_NOTE_ID, 'NOTE', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		INSERT INTO NOTES_ATTACH_FILES(
			NOTE_ID,
			FILE_ID
		) 
		VALUES(
			PI_NOTE_ID,
			PI_FILE_ID
		);
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_ATTACH_NOTE_TO_PROJECT (
	IN PI_NOTE_ID INT,
	IN PI_PROJECT_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_PROJECT_ID, 'PROJECT', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		INSERT INTO PROJECTS_ATTACH_NOTES(
			PROJECT_ID,
			NOTE_ID
		) 
		VALUES(
			PI_PROJECT_ID,
			PI_NOTE_ID
		);
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_ATTACH_NOTE_TO_TASK(
	IN PI_NOTE_ID INT,
	IN PI_TASK_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_TASK_ID, 'TASK', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		INSERT INTO TASKS_ATTACH_NOTES(
			TASK_ID,
			NOTE_ID
		) 
		VALUES(
			PI_TASK_ID,
			PI_NOTE_ID
		);
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_CREATE_PROJECT(
	IN PI_TITLE VARCHAR(1000),
	IN PI_DESCRIPTION TEXT,
	IN PI_DEADLINE DATETIME,
	IN PI_USER_ID INT,
	OUT PO_PROJECT_ID INT
)
BEGIN
	SET PI_TITLE = NULLIF(PI_TITLE, '');
	SET PI_DESCRIPTION = NULLIF(PI_DESCRIPTION, '');

	INSERT INTO PROJECTS (
		TITLE,
		DESCRIPTION,
		CREATED_ON,
		DEADLINE
	)
	VALUES (
		PI_TITLE,
		PI_DESCRIPTION,
		NOW(),
		PI_DEADLINE
	);

	SET PO_PROJECT_ID = LAST_INSERT_ID();

	INSERT INTO USERS_HAVE_PROJECTS_HIDE_COMPLETED_TASKS (
		USER_ID,
		PROJECT_ID,
		HIDE_COMPLETED_TASKS
	)
	VALUES (
		PI_USER_ID,
		PO_PROJECT_ID,
		false
	);

	-- ADD THE ACCESSES.
	CALL _P_GRANT_ACCESS(PI_USER_ID, PO_PROJECT_ID, 'VIEW', 'PROJECT');
	CALL _P_GRANT_ACCESS(PI_USER_ID, PO_PROJECT_ID, 'EDIT', 'PROJECT');
END;
$$


DELIMITER $$

CREATE OR REPLACE PROCEDURE P_CREATE_TASK(
	IN PI_PROJECT_ID INT,
	IN PI_BLOCKER BOOLEAN,
	IN PI_TITLE VARCHAR(1000),
	IN PI_DESCRIPTION TEXT,
	IN PI_DURATION INT,
	IN PI_DEADLINE DATETIME,
	IN PI_USER_ID INT,
	OUT PO_TASK_ID INT
)
BEGIN
	DECLARE V_PLACE INT;

	SET V_PLACE = (SELECT IFNULL(MAX(PLACE)+1, 1) FROM TASKS WHERE PROJECT_ID = PI_PROJECT_ID);
	SET PI_TITLE = NULLIF(PI_TITLE, '');
	SET PI_DESCRIPTION = NULLIF(PI_DESCRIPTION, '');

	INSERT INTO TASKS (
		PROJECT_ID,
		PLACE,
		BLOCKER,
		TITLE,
		DESCRIPTION,
		CREATED_ON,
		DURATION,
		DEADLINE
	)
	VALUES (
		PI_PROJECT_ID,
		V_PLACE,
		PI_BLOCKER,
		PI_TITLE,
		PI_DESCRIPTION,
		NOW(),
		PI_DURATION,
		PI_DEADLINE
	);

	SET PO_TASK_ID = LAST_INSERT_ID();

	CALL _P_GRANT_ACCESS(PI_USER_ID, PO_TASK_ID, 'VIEW', 'TASK');
	CALL _P_GRANT_ACCESS(PI_USER_ID, PO_TASK_ID, 'EDIT', 'TASK');
END
$$


CREATE OR REPLACE PROCEDURE P_MOVE_TASK(
	IN PI_PROJECT_ID INT,
	IN PI_TASK_ID INT,
	IN PI_NEW_PLACE INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;
	DECLARE V_CURRENT_PLACE INT;
	DECLARE V_LAST_PLACE INT;

	SET V_CURRENT_PLACE = (SELECT PLACE FROM TASKS WHERE ID = PI_TASK_ID);
	SET V_LAST_PLACE = (SELECT MAX(PLACE) FROM TASKS WHERE PROJECT_ID = PI_PROJECT_ID);

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_PROJECT_ID, 'PROJECT', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		IF PI_NEW_PLACE > 0 THEN
			IF PI_NEW_PLACE > V_LAST_PLACE THEN
				SET PI_NEW_PLACE = V_LAST_PLACE;
			END IF;

			IF PI_NEW_PLACE > V_CURRENT_PLACE THEN
				UPDATE TASKS SET PLACE = PLACE - 1 WHERE PLACE > V_CURRENT_PLACE AND PLACE <= PI_NEW_PLACE;
				UPDATE TASKS SET PLACE = PI_NEW_PLACE WHERE ID = PI_TASK_ID;
			ELSEIF PI_NEW_PLACE < V_CURRENT_PLACE THEN
				UPDATE TASKS SET PLACE = PLACE + 1 WHERE PLACE < V_CURRENT_PLACE AND PLACE >= PI_NEW_PLACE;
				UPDATE TASKS SET PLACE = PI_NEW_PLACE WHERE ID = PI_TASK_ID;
			END IF;
		END IF;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;

END
$$


CREATE OR REPLACE PROCEDURE P_COMPLETE_TASK (
	IN PI_TASK_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_EDITOR BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_TASK_ID, 'TASK', 'EDIT', V_IS_EDITOR);

	IF V_IS_EDITOR THEN
		IF (SELECT COMPLETED_ON FROM TASKS WHERE ID = PI_TASK_ID) IS NULL THEN
			UPDATE TASKS SET COMPLETED_ON = NOW() WHERE ID = PI_TASK_ID;
		ELSE
			UPDATE TASKS SET COMPLETED_ON = NULL WHERE ID = PI_TASK_ID;
		END IF;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


CREATE OR REPLACE PROCEDURE P_FLIP_HIDE_COMPLETED_TASKS_OF_PROJECT(
	IN PI_PROJECT_ID INT,
	IN PI_USER_ID INT
)
BEGIN
	DECLARE V_IS_VIEWER BOOLEAN;

	CALL P_CHECK_PRIVILEGES(PI_USER_ID, PI_PROJECT_ID, 'PROJECT', 'VIEW', V_IS_VIEWER);

	IF V_IS_VIEWER THEN
		UPDATE
			USERS_HAVE_PROJECTS_HIDE_COMPLETED_TASKS
		SET
			HIDE_COMPLETED_TASKS = NOT HIDE_COMPLETED_TASKS
		WHERE
			USER_ID = PI_USER_ID AND
			PROJECT_ID = PI_PROJECT_ID;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'error-insufficient-privileges';
	END IF;
END;
$$


DELIMITER ;
