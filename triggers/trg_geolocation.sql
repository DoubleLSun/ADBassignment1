-- checks for LAT and LNG range (most important field)
-- change state to all capital letter
DELIMITER $$
CREATE TRIGGER trg_bi_geolocation 
BEFORE INSERT
ON geolocation
FOR EACH ROW
BEGIN
	-- checking for latitude outliers
    IF NEW.geolocation_lat < -90 OR NEW.geolocation_lat > 90 THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Latitude out of range: value must be within -90 and 90 degrees";
	END IF;
     -- checking for longitude outliers   
	IF NEW.geolocation_lng < -180 OR NEW.geolocation_lng > 180 THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Longitude out of range: value must be within -180 and 180 degrees";
	END IF;
        SET NEW.geolocation_state = UPPER(NEW.geolocation_state);

END$$
DELIMITER ;


-- Put insert logs into audit_log
DELIMITER $$

CREATE TRIGGER trg_ai_geolocation 
AFTER INSERT
ON geolocation
FOR EACH ROW
BEGIN
	
    INSERT INTO audit_log(
		at_table,
        action_desc,
        action_date
        ) 
	VALUES (
		"geolocation",
        CONCAT("New location added at ", NEW.geolocation_city, " with LAT/LON ", NEW.geolocation_lat, "/",NEW.geolocation_lng),
        NOW()
	);
END$$
DELIMITER ;

-- test INSERT triggers
INSERT INTO geolocation(
	geolocation_zip_code_prefix,
	geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state)
VALUES(
	"77777",
	-100,
    90,
    "test city",
    "TC"
)

INSERT INTO geolocation(
	geolocation_zip_code_prefix,
	geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state)
VALUES(
	"77777",
	45,
    -200,
    "test city",
    "TC"
)

INSERT INTO geolocation(
	geolocation_zip_code_prefix,
	geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state)
VALUES(
	"66666",
	45,
    90,
    "test city",
    "TC"
)
SELECT * FROM geolocation WHERE geolocation_zip_code_prefix = "66666"

    
-- Check if any updated value is null, then reject the null updates
DELIMITER $$
CREATE TRIGGER trg_bu_geolocation
BEFORE UPDATE
ON geolocation
FOR EACH ROW
BEGIN
	
    IF NEW.geolocation_zip_code_prefix IS NULL
    OR NEW.geolocation_lat IS NULL
    OR NEW.geolocation_lng IS NULL
    OR NEW.geolocation_city IS NULL
    OR NEW.geolocation_state IS NULL THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "1 or more fields cannot be empty";
	END IF;
    
	IF NEW.geolocation_lat < -90 OR NEW.geolocation_lat > 90 THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Latitude out of range: value must be within -90 and 90 degrees";
	END IF;
     -- checking for longitude outliers   
	IF NEW.geolocation_lng < -180 OR NEW.geolocation_lng > 180 THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Longitude out of range: value must be within -180 and 180 degrees";
	END IF;
END$$
DELIMITER ;


-- Put updated fields into the log
DELIMITER $$
CREATE TRIGGER trg_au_geolocation
AFTER UPDATE
ON geolocation
FOR EACH ROW
BEGIN
	DECLARE zip_msg VARCHAR(255) DEFAULT NULL;
	DECLARE lat_msg VARCHAR(255) DEFAULT NULL;
	DECLARE lng_msg VARCHAR(255) DEFAULT NULL;
	DECLARE city_msg VARCHAR(255) DEFAULT NULL;
	DECLARE state_msg VARCHAR(255) DEFAULT NULL;


	IF OLD.geolocation_zip_code_prefix != NEW.geolocation_zip_code_prefix THEN
		SET zip_msg = CONCAT("ZIP Code updated: ", NEW.geolocation_zip_code_prefix);
	END IF;
    
	IF OLD.geolocation_lat != NEW.geolocation_lat THEN
		SET lat_msg = CONCAT("Latitude updated: ", NEW.geolocation_lat);
	END IF;
    
	IF OLD.geolocation_lng != NEW.geolocation_lng THEN
		SET lng_msg = CONCAT("Longitute updated: ", NEW.geolocation_lng);
	END IF;
    
	IF OLD.geolocation_city != NEW.geolocation_city THEN
		SET city_msg = CONCAT("City updated: ", NEW.geolocation_city);
	END IF;
    
	IF OLD.geolocation_state != NEW.geolocation_state THEN
		SET state_msg = CONCAT("State updated: ", NEW.geolocation_state);
	END IF;
    
	INSERT INTO audit_log(
	at_table,
	action_desc,
	action_date
    )
    VALUES(
		"geolocation",
        CONCAT_WS(",",zip_msg,lat_msg,lng_msg,city_msg,state_msg),
        NOW()
    );
END$$

DELIMITER ;

-- Test UPDATE triggers (run insert again if didn't do it in INSERT test)
INSERT INTO geolocation(
	geolocation_zip_code_prefix,
	geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state)
VALUES(
	"66666",
	45,
    90,
    "test city",
    "TC"
);

SET SQL_SAFE_UPDATES = 0;
UPDATE geolocation
SET geolocation_lat = null
WHERE geolocation_zip_code_prefix = "66666";
SET SQL_SAFE_UPDATES = 1;

SET SQL_SAFE_UPDATES = 0;
UPDATE geolocation
SET geolocation_lat = 67
WHERE geolocation_zip_code_prefix = "66666";
SET SQL_SAFE_UPDATES = 1;

DELETE 


-- Put delete logs into audit_log
DELIMITER $$
CREATE TRIGGER trg_ad_geolocation
AFTER DELETE
ON geolocation
FOR EACH ROW
BEGIN

    INSERT INTO audit_log(
		at_table,
        action_desc,
        action_date
    )
    VALUES(
		"geolocation",
        CONCAT('Deleted location at ', OLD.geolocation_city, " with LAT/LON of ", OLD.geolocation_lat, "/", OLD.geolocation_lng),
        NOW()
    );

END$$

DELIMITER ;

-- test DELETE trigger
SET SQL_SAFE_UPDATES = 0;
delete from geolocation where geolocation_zip_code_prefix = "66666";
SET SQL_SAFE_UPDATES = 1;



    