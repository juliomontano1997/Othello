--DOMIANS
CREATE DOMAIN t_mail VARCHAR(50) NOT NULL CONSTRAINT CHK_t_mail CHECK (VALUE SIMILAR TO '[A-z]%@[A-z]%.[A-z]%');

CREATE TABLE players
(
	playerID    SERIAL      NOT NULL  UNIQUE,
	mail        t_mail      NOT NULL,
	playerName  VARCHAR(30) NOT NULL,
	playerLevel INT         NOT NULL,
	image	    VARCHAR(20) NOT NULL,
	CONSTRAINT PK_mail_playerID PRIMARY KEY (mail,playerID)
	
);

CREATE TABLE sessions
(
	sessionID        SERIAL      NOT NULL,
	state	         BOOLEAN     NOT NULL, 
	playerOneID      INT         NOT NULL,
	playerTwoID      INT         NOT NULL,
	actualPlayerID   INT         NOT NULL,
	boardSize        INT         NOT NULL,
	board            INTEGER[]   NOT NULL, 
	colorPlayer1     VARCHAR(30) NOT NULL,
	colorPlayer2     VARCHAR(30) NOT NULL,
	levelPlayerOne   INT         NOT NULL,
	levelPlayerTwo   INT         NOT NULL,
	amountPassTurn   INT         NOT NULL,
	CONSTRAINT PK_sessionID PRIMARY KEY (sessionID),
	CONSTRAINT FK_playerOneID_players FOREIGN KEY (playerOneID) REFERENCES players(playerID),
	CONSTRAINT FK_playerTwoID_players FOREIGN KEY (playerTwoID) REFERENCES players(playerID)	
);

CREATE TABLE sessionStadistics
(
	sessionID        INT         NOT NULL  UNIQUE,
	winsPlayer1      INT         NOT NULL,
	winsPlayer2      INT         NOT NULL,
	ties             INT         NOT NULL,
	amountGames      INT         NOT NULL,
	numberActualGame INT         NOT NULL,
	CONSTRAINT FK_sessionID_sessions FOREIGN KEY (sessionID) REFERENCES sessions 
);

CREATE TABLE messages 
(
	messageID      SERIAL  NOT NULL,
	sessionID      INT     NOT NULL, 
	transmitterID  INT     NOT NULL,
	messageContent TEXT    NOT NULL,
	CONSTRAINT PK_messageID PRIMARY KEY (messageID),
	CONSTRAINT FK_sessionID_sessions FOREIGN KEY (sessionID) REFERENCES sessions
);

CREATE TABLE notifications
(
	notificationID      SERIAL  NOT NULL,
	playerID  	    INT     NOT NULL,
	notificationContent TEXT    NOT NULL,
	CONSTRAINT PK_notificationID PRIMARY KEY (notificationID),
	CONSTRAINT FK_playerID_players FOREIGN KEY (playerID) REFERENCES players(playerID)
);

CREATE TABLE invitations
(
	invitationID  SERIAL  NOT NULL,
	transmitterID INT     NOT NULL, 
	receiverID    INT     NOT NULL,
	boardSize     INT     NOT NULL,
	amountGames   INT     NOT NULL,
	CONSTRAINT PK_invitationID PRIMARY KEY (invitationID),
	CONSTRAINT FK_transmitterID_players FOREIGN KEY (transmitterID) REFERENCES players(playerID),
	CONSTRAINT FK_receiverID_players FOREIGN KEY (receiverID) REFERENCES players(playerID)	
);

--PROCEDURES

CREATE OR REPLACE FUNCTION mg_get_player(IN i_mail t_mail, OUT o_playerID INT, OUT o_playerName VARCHAR(30), OUT o_playerLevel INT, OUT o_image VARCHAR(20))
RETURNS
SETOF RECORD AS 
$body$
BEGIN 	
	RETURN query 
	SELECT playerID, playerName, playerLevel, image FROM players WHERE mail = i_mail;
END;	
$body$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION mg_get_board(IN i_sessionID INT, OUT o_playerOneID INT, OUT o_playerTwoID INT,OUT o_actualPlayerID INT, OUT o_boardSize INT, OUT o_board INTEGER[], OUT o_colorPlayer1 VARCHAR(30), OUT o_colorPlayer2 VARCHAR(30))
RETURNS
SETOF RECORD AS 
$body$
BEGIN 	
	RETURN query 
	SELECT playerOneID, playerTwoID, actualPlayerID, boardSize, board, colorPlayer1, colorPlayer2 FROM sessions where sessionID = i_sessionID;
END;	
$body$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION mg_update_board(IN i_sessionID INT, IN i_actualPlayerID INT, IN i_board INTEGER[])
RETURNS BOOLEAN AS
$body$
BEGIN 	
	IF i_actualPlayerID = (SELECT actualPlayerID FROM sessions WHERE sessionID = i_sessionID) THEN
		UPDATE sessions SET board = i_board WHERE sessionID = i_sessionID;
		IF i_actualPlayerID = (SELECT playerOneID FROM sessions WHERE sessionID = i_sessionID) THEN UPDATE sessions SET actualPlayerID = (SELECT playerTwoID FROM sessions WHERE sessionID = i_sessionID) WHERE sessionID = i_sessionID;
		ELSE UPDATE sessions SET actualPlayerID = (SELECT playerOneID FROM sessions WHERE sessionID = i_sessionID) WHERE sessionID = i_sessionID;
		END IF;
		UPDATE sessions SET amountPassTurn = 0 WHERE sessionID = i_sessionID;
		RETURN TRUE;
	END IF;
	RETURN FALSE;
	EXCEPTION WHEN OTHERS THEN RETURN FALSE;
END;	
$body$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mg_passTurn(IN i_sessionID INT)
RETURNS BOOLEAN AS
$body$
BEGIN 	
	UPDATE sessions SET amountPassTurn = amountPassTurn + 1 WHERE sessionID = i_sessionID;
	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN RETURN FALSE;
END;	
$body$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mg_finishGame(IN i_sessionID INT, IN i_winers INT, IN i_board INT[])
RETURNS BOOLEAN AS
$body$
BEGIN 	
	IF i_winers = 2 THEN 
		UPDATE sessionStadistics SET ties = ties + 1 WHERE sessionID = i_sessionID;		
	ELSIF i_winers = (SELECT playerOneID FROM sessions WHERE sessionID = i_sessionID) THEN
		UPDATE sessionStadistics SET winsPlayer1 = winsPlayer1 + 1 WHERE sessionID = i_sessionID;
	ELSE
		UPDATE sessionStadistics SET winsPlayer2 = winsPlayer2 + 1 WHERE sessionID = i_sessionID;
	END IF;

	UPDATE sessionStadistics SET numberActualGame = numberActualGame + 1 WHERE sessionID = i_sessionID;
	UPDATE sessions SET amountPassTurn = 0 WHERE sessionID = i_sessionID;
	UPDATE sessions SET board = i_board WHERE sessionID = i_sessionID;	
	RETURN TRUE;	
	EXCEPTION WHEN OTHERS THEN RETURN FALSE;
END;	
$body$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mg_finishSession(IN i_sessionID INT)
RETURNS BOOLEAN AS
$body$
BEGIN 	
	IF (SELECT winsPlayer1 FROM sessionStadistics WHERE sessionID = i_sessionID) > (SELECT winsPlayer2 FROM sessionStadistics WHERE sessionID = i_sessionID) THEN 
		UPDATE players SET playerLevel = playerLevel + 1 WHERE playerID = (SELECT playerOneID FROM sessions WHERE sessionID = i_sessionID);	
			
	ELSIF (SELECT winsPlayer1 FROM sessionStadistics WHERE sessionID = i_sessionID) < (SELECT winsPlayer2 FROM sessionStadistics WHERE sessionID = i_sessionID) THEN
		UPDATE players SET playerLevel = playerLevel + 1 WHERE playerID = (SELECT playerTwoID FROM sessions WHERE sessionID = i_sessionID);
	ELSE
		UPDATE players SET playerLevel = playerLevel + 1 WHERE playerID = (SELECT playerOneID FROM sessions WHERE sessionID = i_sessionID);
		UPDATE players SET playerLevel = playerLevel + 1 WHERE playerID = (SELECT playerTwoID FROM sessions WHERE sessionID = i_sessionID);
	END IF;	
	DELETE FROM messages WHERE sessionID = i_sessionID;
	DELETE FROM sessionStadistics WHERE sessionID = i_sessionID;
	DELETE FROM sessions WHERE sessionID = i_sessionID;
	RETURN TRUE;	
	EXCEPTION WHEN OTHERS THEN RETURN FALSE;
END;	
$body$
LANGUAGE plpgsql;



--INSERTS

INSERT INTO players (playerID, mail, playerName, playerLevel, image) VALUES (0,'maquina@othello.com','Maquina',0,'image1'),(1,'juan12@gmail.com','Juan12',1,'image2');

INSERT INTO sessions (state, playerOneID, playerTwoID, actualPlayerID, boardSize, board, colorPlayer1, colorPlayer2, levelPlayerOne, levelPlayerTwo, amountPassTurn) VALUES 
	(true,0,1,1,6,'{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,1,-1,-1,-1,-1,1,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1}','red','blue',1,1,0);

INSERT INTO sessionStadistics (sessionID, winsPlayer1, winsPlayer2, ties, amountGames, numberActualGame) VALUES (3,0,0,0,3,1);
