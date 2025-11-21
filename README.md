# 📦 Inventory Management System – PostgreSQL Backend  
A complete project that implements a fully functional **Inventory Management System** using **PostgreSQL**, complete with schema design, PL/pgSQL business logic, triggers, procedures, and audit logging.  
This repository also includes the **complete project report** and the **EER diagram** for reference.

---

## 🚀 Overview  
This project focuses on building a robust, real-world inventory backend using advanced DBMS concepts.  
It showcases how enterprise inventory systems handle:

- User, product, supplier & warehouse management  
- Automated stock updates & validation  
- Order billing and price locking  
- Payment processing workflows  
- Delivery and returns tracking  
- Shipment restocking automation  
- Audit logs for stock-level changes  
- Query utilities for reporting

Everything is implemented using **clean relational design**, **referential integrity**, and **trigger-based automation**.

---

## 🧱 Tech Stack  
- **PostgreSQL**  
- **PL/pgSQL**  
- **EER Diagram** (MySQL Workbench style)  
- **SQL Schema + Business Logic Scripts**

---

## 📁 Repository Contents  
| File | Description |
|------|-------------|
| `Integrated Inventory Management System.sql` | Complete database schema with tables, enums, triggers, procedures & sample data |
| `Inventorty Management System Report.docx` | Full project documentation with explanations & analysis |
| `EER.jpg` | Complete EER diagram of the database |
| `README.md` | Project description and instructions |

---

## 🏗️ Key Features  
### 🔧 **Database Architecture**
- Normalized schema with clean relationships  
- ENUM types for consistent business statuses  
- Full dependency-ordered drop & create structure  

### ⚙️ **Business Logic (PL/pgSQL)**
- Automatic stock validation before orders  
- Automatic price locking in order details  
- Automatic order total computation  
- Shipment-based restocking system  
- Payment confirmation workflow  
- Safe product creation via stored procedure  

### 📜 **Triggers & Logs**
- Stock update triggers  
- Order total recalculation  
- Audit logs for all stock changes  

### 🧪 **Sample Data Included**
- Users (Customer, Admin, Employee)  
- Products & suppliers  
- Warehouses & shipments  
- Demonstration orders, payments & functions  

---

## 📝 How to Run  
1. Install PostgreSQL 14+  
2. Open pgAdmin / terminal  
3. Run the SQL script:  
```sql
\i inventory_management.sql
```
4. All tables, functions, triggers, and sample data will be created automatically.

---

## 📊 Demonstration Queries  
The script includes demo queries showcasing:

- Placing orders  
- Automatic stock deduction  
- Payment processing  
- Shipment restocking  
- Customer order history  
- Low-stock product detection  

---

## 📚 Documentation  
For detailed explanation of design choices, ER diagrams, procedures, and analysis:  
✔ **Refer to the full project report included in the repo.**

---

## 🤝 Contribution  
Feel free to fork the project, enhance the schema, or integrate it with a frontend/backend framework.

