""" 
Simple python CLI program to do CRUD on MySQL database (assignment1) to simulate real transaction DB system
Table: sellers 
"""
import mysql.connector as mc
from mysql.connector import Error

class MainCRUD:
    def __init__(self):
        db_settings = {
            "host": "localhost",
            "port": 3306,
            "user": "root",
            "password": "",
            "database": "assignment1",
        }
        self.db_config = db_settings
        # add all CRUD stored procedures here
        """Example template of routing_registry
          "1": {
                "description": "Manage User Profiles",
                "procedure": "sp_manage_user",
                "params": ["User ID", "User Name", "Action (INSERT/UPDATE)"],
            },
         """
        # customer table:
        # e.g.: 00012a2ce6f8dcda20d059ce98491703	248ffe10d632bebe4f7267f1f44844c9	6273	osasco	SP
        self.routing_registry = {
            "1": {
                "description": "Create New Order",
                "procedure": "sp_order_create",
                "params": [
                    "Customer ID ['b2191912d8ad6eac2e4dc3b6e1459515']",
                    "Estimated Delivery Date [YYYY-MM-DD HH:MM:ss / '2026-08-18 00:00:00']"],
            },
            "2": {
                "description": "Retrieve Specific Order",
                "procedure": "sp_order_retrieve",
                "params": ["Order ID [Leave Blank to select all/'00010242fe8c5a6d1ba2dd792cb16214']", 
                           "Delivery Status [Blank/'approved/canceled/created/delivered/invoiced/processing/shipped/unavailable']"],
            },
            "3": {
                "description": "Update Specific Order",
                "procedure": "sp_order_update",
                "params": ["Order ID ['00010242fe8c5a6d1ba2dd792cb16214']", 
                           "New Status ['approved/canceled/created/delivered/invoiced/processing/shipped/unavailable']",
                           "New Delivery Date [YYYY-MM-DD HH:MM:ss / '2026-08-18 00:00:00']"],
            },
            "4": {
                "description": "Delete Specific Order",
                "procedure": "sp_order_delete",
                "params": ["Order ID ['00010242fe8c5a6d1ba2dd792cb16214']"],
            },
            "5": {
                "description": "Create New Seller",
                "procedure": "sp_seller_create",
                "params": ["Zip Code ['9080']", 
                           "City Name ['santo andre']", 
                           "State Name ['SP']"],
            },
            "6": {
                "description": "Retrieve Seller",
                "procedure": "sp_seller_retrieve",
                "params": ["Seller ID [Blank to select all / '0015a82c2db000af6aaaf3ae2ecb0532'/ Partial ID '0015a82']", 
                           "State Name ['SP']"],
            },
            "7": {
                "description": "Update Specific Seller",
                "procedure": "sp_seller_update",
                "params": ["Seller ID [Blank to select all / '0015a82c2db000af6aaaf3ae2ecb0532']", 
                           "New Zip Code ['9081']", 
                           "New City Name ['santo andre 2']", 
                           "New State Name ['SP']"],
            },
            "8": {
                "description": "Delete Specific Seller",
                "procedure": "sp_seller_delete",
                "params": ["Seller ID ['0015a82c2db000af6aaaf3ae2ecb0532']"],
            },
        }

    def displayMenu(self):
        print("\n===Database Operation Menu===")
        print("\n-----------------------------")
        for key, info in self.routing_registry.items():
            print(f"[{key}] {info['description']} (Runs: {info['procedure']})")
        print("[Q] Quit")

    def execute_SQL_procedure(self, choice, args):
        proc_info = self.routing_registry[choice]
        proc_name = proc_info["procedure"]
        print(f"\nConnecting to DB to execute {proc_name} with arguments: {args}...")
        try:
            connector = mc.connect(**self.db_config)
            cursor = connector.cursor()
            cursor.execute('SELECT DATABASE()')
            dbname = cursor.fetchone()[0]
            if connector.is_connected():
                print(f"Successfully connected to MySQL server, DB:{dbname}")

            cursor.callproc(proc_name,args)
            for result in cursor.stored_results():
                # This fetches data rows if it's a retrieve/select SP, 
                # or safely clears internal status messages if it's a write SP.
                rows = result.fetchall()
                if rows:
                    print(f"\n--- Results from {proc_name} ---")
                    for row in rows:
                        print(row)

            # connector.commit() commit process is inside stored procedure
            print(f"Success: {proc_name} executed and changes committed.")
        except Error as error:
            print(f"Connection failed: {error}")
        finally:
            if "cursor" in locals() and cursor:
                cursor.close()
                print("Cursor closed")
            if "connector" in locals() and connector.is_connected():
                connector.close()
                print("Connection closed")

    def start(self):
        endFlag = True
        while(endFlag):
            self.displayMenu()
            choice = input("\nSelect an operation: ").strip()
            if choice.lower()=="q":
                check_exit = input("End Program?[y/n]\n").strip().lower()
                if (check_exit=="y"):
                    print("Exiting Program...")
                    endFlag=False
                else:
                    print("Exit protocol cancelled...")
            if choice in self.routing_registry:
                proc_info = self.routing_registry[choice]
                collected_args = []
                print(f"\n--- Gathering Inputs for {proc_info['description']} ---")
                # Gets required inputs
                for params_name in proc_info["params"]:
                    val=input(f"Enter {params_name}: ").strip()
                    if val=="":
                        # sp accepts null input
                        collected_args.append(None)
                    else:
                        collected_args.append(val)
                # select stored procedures and input data args
                self.execute_SQL_procedure(choice,collected_args)
            elif endFlag:
                print("Invalid selection. Please try again...")
                
            
if __name__ == "__main__":
    app = MainCRUD()
    app.start()
