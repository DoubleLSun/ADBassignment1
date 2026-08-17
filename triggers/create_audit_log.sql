-- create the audit log table for trigger
CREATE TABLE audit_log(
	log_id INT AUTO_INCREMENT PRIMARY KEY,
    at_table VARCHAR(255),
    action_desc VARCHAR(255),
    action_date DATETIME
);
