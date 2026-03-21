
CREATE TABLE positions (
id SERIAL PRIMARY KEY,
title VARCHAR UNIQUE NOT NULL
);

CREATE TABLE department_types(
id SERIAL PRIMARY KEY,
name VARCHAR UNIQUE NOT NULL
);

CREATE TABLE departments (
id SERIAL PRIMARY KEY,
name VARCHAR UNIQUE NOT NULL
);

CREATE TABLE branch_addresses (
id SERIAL PRIMARY KEY,
name VARCHAR UNIQUE NOT NULL
);

CREATE TABLE projects (
id SERIAL PRIMARY KEY,
name VARCHAR UNIQUE NOT NULL
);

CREATE TABLE employees(
id SERIAL PRIMARY KEY ,
full_name VARCHAR,
salary MONEY,
hire_date DATE NOT NULL,
position_id INT,
department_type_id INT,
department_id INT,
branch_address_id INT,
FOREIGN KEY (position_id) REFERENCES positions(id),
FOREIGN KEY (department_type_id) REFERENCES department_types(id),
FOREIGN KEY (department_id) REFERENCES departments(id),
FOREIGN KEY (branch_address_id) REFERENCES branch_addresses(id)
);

CREATE TABLE employee_projects (
employee_id INT,
project_id INT,
PRIMARY KEY (employee_id, project_id),
FOREIGN KEY (employee_id) REFERENCES employees(id),
FOREIGN KEY (project_id) REFERENCES projects(id)
);