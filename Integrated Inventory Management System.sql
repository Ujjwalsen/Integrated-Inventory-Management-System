
-- =============================================================================
-- INVENTORY MANAGEMENT SYSTEM - POSTGRESQL BACKEND
-- =============================================================================

-- Drop existing objects in reverse order of dependency to allow for a clean re-run.
DROP TRIGGER IF EXISTS trg_log_stock_change ON Products;
DROP FUNCTION IF EXISTS fn_log_stock_change();
DROP TABLE IF EXISTS Product_Stock_Log;

DROP TRIGGER IF EXISTS trg_calculate_order_total ON Order_Details;
DROP FUNCTION IF EXISTS fn_calculate_order_total();

DROP TRIGGER IF EXISTS trg_check_and_update_stock ON Order_Details;
DROP TRIGGER IF EXISTS trg_set_order_price ON Order_Details;
DROP FUNCTION IF EXISTS fn_check_and_update_stock();
DROP FUNCTION IF EXISTS fn_set_order_price();

DROP PROCEDURE IF EXISTS sp_add_new_product(VARCHAR, NUMERIC, INT, VARCHAR, INT, INT, INT);
DROP PROCEDURE IF EXISTS sp_process_payment(INT);
DROP PROCEDURE IF EXISTS sp_update_shipment_status(INT, VARCHAR, VARCHAR);

DROP FUNCTION IF EXISTS fn_get_customer_order_history(INT);
DROP FUNCTION IF EXISTS fn_get_products_below_stock_threshold(INT);

DROP TABLE IF EXISTS Support_Tickets;
DROP TABLE IF EXISTS Returns;
DROP TABLE IF EXISTS Employees;
DROP TABLE IF EXISTS Delivery;
DROP TABLE IF EXISTS Payments;
DROP TABLE IF EXISTS Order_Details;
DROP TABLE IF EXISTS Orders;
DROP TABLE IF EXISTS Warehouse_Stock;
DROP TABLE IF EXISTS Warehouse;
DROP TABLE IF EXISTS Shipment_Products;
DROP TABLE IF EXISTS Shipment;
DROP TABLE IF EXISTS Product_Suppliers;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS Suppliers;
DROP TABLE IF EXISTS Users;

DROP TYPE IF EXISTS user_role_enum;
DROP TYPE IF EXISTS order_status_enum;
DROP TYPE IF EXISTS payment_status_enum;
DROP TYPE IF EXISTS delivery_status_enum;
DROP TYPE IF EXISTS return_status_enum;

-- =============================================================================
-- 1. CUSTOM DATA TYPES (ENUMS)
-- =============================================================================
-- Using ENUMs ensures data consistency for status fields.

CREATE TYPE user_role_enum AS ENUM ('Customer', 'Admin', 'Employee');
CREATE TYPE order_status_enum AS ENUM ('Pending', 'Paid', 'Processing', 'Shipped', 'Delivered', 'Cancelled');
CREATE TYPE payment_status_enum AS ENUM ('Pending', 'Completed', 'Failed', 'Refunded');
CREATE TYPE delivery_status_enum AS ENUM ('Pending', 'Out for Delivery', 'Delivered', 'Failed');
CREATE TYPE return_status_enum AS ENUM ('Requested', 'Approved', 'Rejected', 'Processing', 'Completed');

-- =============================================================================
-- 2. TABLE CREATION
-- =============================================================================

-- Merged Users, Admin, and Customers from the EER diagram.
-- The 'is a' relationship is handled by the 'User_Role' column.
CREATE TABLE Users (
    User_ID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Password_Hash VARCHAR(255) NOT NULL, -- Storing passwords in plain text is bad practice.
    Contact VARCHAR(50),
    Address TEXT,
    User_Role user_role_enum NOT NULL DEFAULT 'Customer',
    Created_At TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE Suppliers (
    Supplier_ID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Location TEXT,
    Contact_Email VARCHAR(100)
);

CREATE TABLE Products (
    Product_ID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Description TEXT,
    Price NUMERIC(10, 2) NOT NULL CHECK (Price > 0),
    Stock_Qty INT NOT NULL CHECK (Stock_Qty >= 0),
    Category VARCHAR(50)
);

-- Junction table for the many-to-many relationship between Products and Suppliers.
CREATE TABLE Product_Suppliers (
    Product_ID INT REFERENCES Products(Product_ID) ON DELETE CASCADE,
    Supplier_ID INT REFERENCES Suppliers(Supplier_ID) ON DELETE CASCADE,
    PRIMARY KEY (Product_ID, Supplier_ID)
);

CREATE TABLE Shipment (
    Shipment_ID SERIAL PRIMARY KEY,
    Supplier_ID INT REFERENCES Suppliers(Supplier_ID),
    Shipment_Date DATE DEFAULT CURRENT_DATE,
    Expected_Arrival_Date DATE,
    Status VARCHAR(50) DEFAULT 'In Transit'
);

-- Junction table for products included in a shipment (many-to-many).
CREATE TABLE Shipment_Products (
    Shipment_ID INT REFERENCES Shipment(Shipment_ID) ON DELETE CASCADE,
    Product_ID INT REFERENCES Products(Product_ID) ON DELETE CASCADE,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    PRIMARY KEY (Shipment_ID, Product_ID)
);

CREATE TABLE Warehouse (
    Warehouse_ID SERIAL PRIMARY KEY,
    Location TEXT NOT NULL,
    Capacity INT CHECK (Capacity > 0)
);

-- Junction table for where products are stored (many-to-many).
CREATE TABLE Warehouse_Stock (
    Warehouse_ID INT REFERENCES Warehouse(Warehouse_ID) ON DELETE CASCADE,
    Product_ID INT REFERENCES Products(Product_ID) ON DELETE CASCADE,
    Quantity_In_Warehouse INT NOT NULL CHECK (Quantity_In_Warehouse >= 0),
    PRIMARY KEY (Warehouse_ID, Product_ID)
);

CREATE TABLE Orders (
    Order_ID SERIAL PRIMARY KEY,
    Customer_ID INT REFERENCES Users(User_ID) ON DELETE SET NULL, -- Use SET NULL so order history remains if a user is deleted.
    Order_Date TIMESTAMPTZ DEFAULT NOW(),
    Status order_status_enum DEFAULT 'Pending',
    Total_Amount NUMERIC(12, 2) DEFAULT 0.00 -- This will be calculated by a trigger.
);

-- This is the 'contains' relationship, acting as a junction table for Orders and Products.
CREATE TABLE Order_Details (
    Order_Detail_ID SERIAL PRIMARY KEY,
    Order_ID INT REFERENCES Orders(Order_ID) ON DELETE CASCADE,
    Product_ID INT REFERENCES Products(Product_ID), -- Don't cascade delete, we want to know what was ordered.
    Quantity INT NOT NULL CHECK (Quantity > 0),
    Price NUMERIC(10, 2) NOT NULL -- This price is "locked in" from the Products table at the time of insertion.
);

CREATE TABLE Payments (
    Payment_ID SERIAL PRIMARY KEY,
    Order_ID INT REFERENCES Orders(Order_ID) ON DELETE CASCADE,
    Amount NUMERIC(12, 2) NOT NULL,
    Mode VARCHAR(50) NOT NULL, -- e.g., 'Credit Card', 'PayPal'
    Status payment_status_enum DEFAULT 'Pending',
    Payment_Date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE Delivery (
    Delivery_ID SERIAL PRIMARY KEY,
    Order_ID INT UNIQUE REFERENCES Orders(Order_ID) ON DELETE CASCADE, -- One-to-One relationship
    Address TEXT NOT NULL,
    Estimated_Delivery_Date DATE,
    Actual_Delivery_Date DATE,
    Status delivery_status_enum DEFAULT 'Pending'
);

-- Employees table (merged from EER diagram)
CREATE TABLE Employees (
    Employee_ID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Role VARCHAR(50) NOT NULL, -- e.g., 'Support Staff', 'Warehouse Manager'
    Salary NUMERIC(10, 2) CHECK (Salary > 0),
    Hire_Date DATE DEFAULT CURRENT_DATE
    -- Can also be linked to the Users table if employees need to log in.
);

CREATE TABLE Returns (
    Return_ID SERIAL PRIMARY KEY,
    Order_ID INT REFERENCES Orders(Order_ID) ON DELETE CASCADE,
    Reason TEXT NOT NULL,
    Status return_status_enum DEFAULT 'Requested',
    Requested_Date TIMESTAMPTZ DEFAULT NOW(),
    Handled_By_Employee_ID INT REFERENCES Employees(Employee_ID) -- Employee who processed the return.
);

CREATE TABLE Support_Tickets (
    Ticket_ID SERIAL PRIMARY KEY,
    Customer_ID INT REFERENCES Users(User_ID) ON DELETE CASCADE,
    Issue TEXT NOT NULL,
    Status VARCHAR(50) DEFAULT 'Open',
    Created_At TIMESTAMPTZ DEFAULT NOW(),
    Handled_By_Employee_ID INT REFERENCES Employees(Employee_ID)
);

-- =============================================================================
-- 3. AUDIT & LOGGING TABLE
-- =============================================================================
-- This table is not in the EER but is essential for a useful trigger.

CREATE TABLE Product_Stock_Log (
    Log_ID SERIAL PRIMARY KEY,
    Product_ID INT REFERENCES Products(Product_ID),
    Old_Qty INT,
    New_Qty INT,
    Change_Timestamp TIMESTAMPTZ DEFAULT NOW(),
    Operation_Type VARCHAR(20) -- e.g., 'Order', 'Restock', 'Manual Update'
);

-- =============================================================================
-- 4. FUNCTIONS & TRIGGERS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TRIGGER 1: Check stock and prevent order if insufficient.
-- PURPOSE: Ensures that a customer cannot order more of a product than is
-- currently in stock. This runs BEFORE the order detail is inserted.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_and_update_stock()
RETURNS TRIGGER AS $$
DECLARE
    current_stock INT;
BEGIN
    -- Lock the product row to prevent race conditions
    SELECT Stock_Qty INTO current_stock FROM Products WHERE Product_ID = NEW.Product_ID FOR UPDATE;
    
    IF current_stock < NEW.Quantity THEN
        RAISE EXCEPTION 'Insufficient stock for Product ID %: Requested %, Available %', NEW.Product_ID, NEW.Quantity, current_stock;
    END IF;
    
    -- If stock is sufficient, update the product's stock quantity
    UPDATE Products
    SET Stock_Qty = Stock_Qty - NEW.Quantity
    WHERE Product_ID = NEW.Product_ID;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_and_update_stock
BEFORE INSERT ON Order_Details
FOR EACH ROW
EXECUTE FUNCTION fn_check_and_update_stock();

-- -----------------------------------------------------------------------------
-- TRIGGER 2: Set the price in Order_Details.
-- PURPOSE: Automatically fetches the product's current price from the Products
-- table and "locks it in" in the Order_Details table when the order is placed.
-- This prevents future price changes from affecting past orders.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_order_price()
RETURNS TRIGGER AS $$
BEGIN
    NEW.Price := (SELECT Price FROM Products WHERE Product_ID = NEW.Product_ID);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_order_price
BEFORE INSERT ON Order_Details
FOR EACH ROW
EXECUTE FUNCTION fn_set_order_price();

-- -----------------------------------------------------------------------------
-- TRIGGER 3: Calculate the total amount for an order.
-- PURPOSE: Automatically recalculates the Orders.Total_Amount field whenever
-- an item is added, updated, or removed from an order.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calculate_order_total()
RETURNS TRIGGER AS $$
DECLARE
    order_id_to_update INT;
BEGIN
    -- Determine which Order_ID to update
    IF TG_OP = 'DELETE' THEN
        order_id_to_update := OLD.Order_ID;
    ELSE
        order_id_to_update := NEW.Order_ID;
    END IF;

    -- Update the total amount in the Orders table
    UPDATE Orders
    SET Total_Amount = (
        SELECT COALESCE(SUM(Price * Quantity), 0.00)
        FROM Order_Details
        WHERE Order_ID = order_id_to_update
    )
    WHERE Order_ID = order_id_to_update;

    RETURN NULL; -- This is an AFTER trigger, so the return value is ignored.
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_order_total
AFTER INSERT OR UPDATE OR DELETE ON Order_Details
FOR EACH ROW
EXECUTE FUNCTION fn_calculate_order_total();

-- -----------------------------------------------------------------------------
-- TRIGGER 4: Log changes to product stock.
-- PURPOSE: An essential auditing feature. Every time the Stock_Qty in the
-- Products table is updated, this trigger logs the old and new quantity
-- in the Product_Stock_Log table.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_log_stock_change()
RETURNS TRIGGER AS $$
BEGIN
    -- We only want to log if the quantity actually changed.
    IF OLD.Stock_Qty <> NEW.Stock_Qty THEN
        INSERT INTO Product_Stock_Log (Product_ID, Old_Qty, New_Qty, Operation_Type)
        VALUES (NEW.Product_ID, OLD.Stock_Qty, NEW.Stock_Qty, 'Manual Update'); -- Default operation type
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_stock_change
AFTER UPDATE ON Products
FOR EACH ROW
WHEN (OLD.Stock_Qty IS DISTINCT FROM NEW.Stock_Qty)
EXECUTE FUNCTION fn_log_stock_change();

-- Note: The 'fn_check_and_update_stock' trigger already modifies stock, but it
-- won't fire this trigger. To log order-based changes, we'd add an
-- INSERT statement to Product_Stock_Log within 'fn_check_and_update_stock'
-- and set Operation_Type to 'Order'.

-- =============================================================================
-- 5. STORED PROCEDURES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PROCEDURE 1: Add a new product.
-- PURPOSE: Provides a controlled and safe way to add a new product,
-- including adding it to a supplier and a warehouse in one transaction.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_add_new_product(
    p_name VARCHAR,
    p_price NUMERIC,
    p_stock_qty INT,
    p_category VARCHAR,
    p_supplier_id INT,
    p_warehouse_id INT DEFAULT 1, -- Assume a default warehouse
    p_warehouse_qty INT DEFAULT 0
)
LANGUAGE plpgsql AS $$
DECLARE
    new_product_id INT;
BEGIN
    -- Insert the new product
    INSERT INTO Products (Name, Price, Stock_Qty, Category)
    VALUES (p_name, p_price, p_stock_qty, p_category)
    RETURNING Product_ID INTO new_product_id;

    -- Link it to the supplier
    IF p_supplier_id IS NOT NULL THEN
        INSERT INTO Product_Suppliers (Product_ID, Supplier_ID)
        VALUES (new_product_id, p_supplier_id);
    END IF;

    -- Add it to warehouse stock
    IF p_warehouse_id IS NOT NULL AND p_warehouse_qty > 0 THEN
        INSERT INTO Warehouse_Stock (Warehouse_ID, Product_ID, Quantity_In_Warehouse)
        VALUES (p_warehouse_id, new_product_id, p_warehouse_qty);
    END IF;

    RAISE NOTICE 'Successfully added new product: % (ID: %)', p_name, new_product_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to add product: %', SQLERRM;
END;
$$;

-- -----------------------------------------------------------------------------
-- PROCEDURE 2: Process a payment.
-- PURPOSE: A crucial business logic procedure. When a payment is confirmed,
-- this procedure updates the payment status AND the corresponding order status.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_process_payment(
    p_payment_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_order_id INT;
    v_order_status order_status_enum;
BEGIN
    -- Find the order associated with the payment
    SELECT Order_ID INTO v_order_id
    FROM Payments
    WHERE Payment_ID = p_payment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment ID % not found.', p_payment_id;
    END IF;

    -- Update payment status
    UPDATE Payments
    SET Status = 'Completed'
    WHERE Payment_ID = p_payment_id;

    -- Update order status
    UPDATE Orders
    SET Status = 'Paid'
    WHERE Order_ID = v_order_id
    RETURNING Status INTO v_order_status;
    
    RAISE NOTICE 'Payment % processed. Order % status updated to %.', p_payment_id, v_order_id, v_order_status;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process payment: %', SQLERRM;
END;
$$;

-- -----------------------------------------------------------------------------
-- PROCEDURE 3: Update Shipment and Restock Products
-- PURPOSE: When a shipment arrives, this procedure updates its status
-- and automatically restocks the products in the Products table.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_update_shipment_status(
    p_shipment_id INT,
    p_new_status VARCHAR,
    p_operation_type VARCHAR DEFAULT 'Restock'
)
LANGUAGE plpgsql AS $$
DECLARE
    product_record RECORD;
BEGIN
    -- Update the shipment status
    UPDATE Shipment
    SET Status = p_new_status
    WHERE Shipment_ID = p_shipment_id;

    -- If the shipment has 'Arrived', restock the products
    IF p_new_status = 'Arrived' THEN
        FOR product_record IN
            SELECT Product_ID, Quantity FROM Shipment_Products WHERE Shipment_ID = p_shipment_id
        LOOP
            -- Update the stock in the Products table
            UPDATE Products
            SET Stock_Qty = Stock_Qty + product_record.Quantity
            WHERE Product_ID = product_record.Product_ID;

            -- Manually log this stock change (as the trigger might not capture the context)
            INSERT INTO Product_Stock_Log (Product_ID, Old_Qty, New_Qty, Operation_Type)
            SELECT
                product_record.Product_ID,
                p.Stock_Qty - product_record.Quantity, -- Old quantity
                p.Stock_Qty, -- New quantity
                p_operation_type
            FROM Products p
            WHERE p.Product_ID = product_record.Product_ID;
            
        END LOOP;
    END IF;
    
    RAISE NOTICE 'Shipment % status updated to %.', p_shipment_id, p_new_status;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to update shipment: %', SQLERRM;
END;
$$;

-- =============================================================================
-- 6. QUERY FUNCTIONS (TABLE-RETURNING & SCALAR)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FUNCTION 1: Get a customer's order history.
-- PURPOSE: A simple, reusable function to retrieve all orders for a
-- specific customer.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_get_customer_order_history(p_customer_id INT)
RETURNS TABLE(
    Order_ID INT,
    Order_Date TIMESTAMPTZ,
    Total_Amount NUMERIC(12, 2),
    Status order_status_enum
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        O.Order_ID,
        O.Order_Date,
        O.Total_Amount,
        O.Status
    FROM Orders O
    WHERE O.Customer_ID = p_customer_id
    ORDER BY O.Order_Date DESC;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- FUNCTION 2: Get products below a stock threshold.
-- PURPOSE: An essential function for inventory management. This helps
-- identify which products need to be reordered.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_get_products_below_stock_threshold(p_threshold INT)
RETURNS TABLE(
    Product_ID INT,
    Name VARCHAR,
    Current_Stock INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        P.Product_ID,
        P.Name,
        P.Stock_Qty
    FROM Products P
    WHERE P.Stock_Qty < p_threshold
    ORDER BY P.Stock_Qty ASC;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 7. SAMPLE DATA INSERTION
-- =============================================================================
-- This section populates the database to demonstrate functionality.

INSERT INTO Users (Name, Email, Password_Hash, Address, User_Role) VALUES
('Alice Smith', 'alice@example.com', 'hash_pw_123', '123 Main St', 'Customer'),
('Bob Johnson', 'bob@example.com', 'hash_pw_456', '456 Oak Ave', 'Customer'),
('Charlie Root', 'admin@inventory.com', 'hash_pw_789', '789 Admin Blvd', 'Admin'),
('David Lee', 'employee@inventory.com', 'hash_pw_101', '101 Staff Rd', 'Employee');

INSERT INTO Suppliers (Name, Location, Contact_Email) VALUES
('Global Electronics', 'Shenzhen, China', 'sales@globalelec.com'),
('Premium Parts Co.', 'Detroit, MI', 'parts@premium.com');

INSERT INTO Warehouse (Location, Capacity) VALUES
('Main Warehouse - A', 10000),
('Secondary Warehouse - B', 5000);

-- Use the procedure to add products
CALL sp_add_new_product('Laptop Pro 15"', 1200.00, 50, 'Electronics', 1, 1, 50);
CALL sp_add_new_product('Wireless Mouse', 45.00, 150, 'Accessories', 1, 1, 150);
CALL sp_add_new_product('Mechanical Keyboard', 130.00, 75, 'Accessories', 2, 1, 75);
CALL sp_add_new_product('USB-C Hub', 25.50, 200, 'Accessories', 2, 1, 200);
CALL sp_add_new_product('4K Monitor', 450.00, 10, 'Monitors', 1, 2, 10); -- Low stock item

INSERT INTO Employees (Name, Role, Salary) VALUES
('Sarah Jenkins', 'Support Staff', 55000),
('Mark Rober', 'Warehouse Manager', 70000);

-- =============================================================================
-- 8. DEMONSTRATING THE TRIGGERS AND PROCEDURES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- DEMO 1: Placing an order (Triggers 1, 2, 3 will fire)
-- -----------------------------------------------------------------------------
-- Customer Alice (ID 1) places an order.
INSERT INTO Orders (Customer_ID) VALUES (1) RETURNING Order_ID; -- Let's say this returns Order_ID 1

-- Add items to the order.
-- This will:
-- 1. (trg_set_order_price)      Lock in the price (e.g., 1200.00 for the laptop).
-- 2. (trg_check_and_update_stock) Decrease Product 1's stock from 50 to 49.
-- 3. (trg_calculate_order_total) Update Order 1's Total_Amount.
INSERT INTO Order_Details (Order_ID, Product_ID, Quantity) VALUES (1, 1, 1);

-- 4. (trg_set_order_price)      Lock in the price (45.00 for the mouse).
-- 5. (trg_check_and_update_stock) Decrease Product 2's stock from 150 to 148.
-- 6. (trg_calculate_order_total) Update Order 1's Total_Amount again.
INSERT INTO Order_Details (Order_ID, Product_ID, Quantity) VALUES (1, 2, 2);

-- Check the results:
SELECT * FROM Orders WHERE Order_ID = 1; -- Total_Amount should be (1 * 1200) + (2 * 45) = 1290.00
SELECT * FROM Products WHERE Product_ID IN (1, 2); -- Stock_Qty should be 49 and 148.

-- -----------------------------------------------------------------------------
-- DEMO 2: Attempting to order an out-of-stock item
-- -----------------------------------------------------------------------------
-- Customer Bob (ID 2) places an order
INSERT INTO Orders (Customer_ID) VALUES (2) RETURNING Order_ID; -- Let's say this returns Order_ID 2

-- Try to order 11 4K Monitors (Product ID 5), but only 10 are in stock.
-- This INSERT will FAIL thanks to 'trg_check_and_update_stock'.
-- UNCOMMENT THE LINE BELOW TO TEST (it will raise an error)
-- INSERT INTO Order_Details (Order_ID, Product_ID, Quantity) VALUES (2, 5, 11);

-- -----------------------------------------------------------------------------
-- DEMO 3: Processing a payment (Procedure 2)
-- -----------------------------------------------------------------------------
-- Create a payment for Order 1
INSERT INTO Payments (Order_ID, Amount, Mode)
SELECT Order_ID, Total_Amount, 'Credit Card' FROM Orders WHERE Order_ID = 1 RETURNING Payment_ID; -- Let's say this is Payment_ID 1

-- Now, process the payment
CALL sp_process_payment(1);

-- Check the results:
SELECT Status FROM Payments WHERE Payment_ID = 1; -- Should be 'Completed'
SELECT Status FROM Orders WHERE Order_ID = 1; -- Should be 'Paid'

-- -----------------------------------------------------------------------------
-- DEMO 4: Restocking products (Procedure 3 & Trigger 4)
-- -----------------------------------------------------------------------------
-- A shipment arrives from Supplier 1
INSERT INTO Shipment (Supplier_ID, Status) VALUES (1, 'In Transit') RETURNING Shipment_ID; -- Let's say this is Shipment_ID 1
-- The shipment contains more 4K Monitors
INSERT INTO Shipment_Products (Shipment_ID, Product_ID, Quantity) VALUES (1, 5, 20);

-- Now, mark the shipment as 'Arrived' using the procedure
CALL sp_update_shipment_status(1, 'Arrived');

-- Check the results:
SELECT Stock_Qty FROM Products WHERE Product_ID = 5; -- Should be 10 (original) + 20 (shipment) = 30
-- Check the audit log:
SELECT * FROM Product_Stock_Log WHERE Product_ID = 5; -- Should show a 'Restock' operation.

-- -----------------------------------------------------------------------------
-- DEMO 5: Using the query functions
-- -----------------------------------------------------------------------------

-- Get Alice's (Customer 1) order history
SELECT * FROM fn_get_customer_order_history(1);

-- Find products that are running low (e.g., threshold of 50)
SELECT * FROM fn_get_products_below_stock_threshold(50); -- Should list Laptop (49) and 4K Monitor (30)

-- =============================================================================
-- END OF SCRIPT
-- =============================================================================

