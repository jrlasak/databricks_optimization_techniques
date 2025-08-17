Here is a comprehensive Databricks learning project focused on optimizing Delta Lake tables using various techniques.

### Project: Optimizing Delta Lake Tables in Databricks

This project will guide you through the process of creating and optimizing Delta Lake tables using synthetic data. We will cover Partitioning, Z-Ordering, Compaction (manual and auto), Liquid Clustering, and VACUUM. For each technique, we will analyze the Spark UI to understand the execution plans and measure the performance improvements.

**The final output will be a single Databricks notebook with different cells for each purpose.**

---

### Databricks Notebook: Delta Lake Optimization Project

#### Cell 1: Project Overview and Setup

````markdown
# Delta Lake Optimization Project

This notebook provides a hands-on guide to optimizing Delta Lake tables in Databricks. We will explore and compare various optimization techniques using synthetically generated sales data.

**Learning Objectives:**

- Understand and implement table partitioning.
- Apply Z-Ordering to improve data skipping.
- Perform manual and automatic compaction to optimize file sizes.
- Utilize Liquid Clustering for flexible data layout.
- Use the VACUUM command to manage table storage.
- Analyze Spark UI to observe execution plans and performance improvements.

**Setup:**
First, we'll define the catalog and schema for our project. Make sure you have the necessary permissions to create catalogs and schemas in your Databricks workspace.```

```python
# Configuration
CATALOG_NAME = "delta_optimization_project"
SCHEMA_NAME = "sales_data"

# Create the catalog and schema if they don't exist
spark.sql(f"CREATE CATALOG IF NOT EXISTS {CATALOG_NAME}")
spark.sql(f"USE CATALOG {CATALOG_NAME}")
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA_NAME}")
spark.sql(f"USE SCHEMA {SCHEMA_NAME}")
```
````

#### Cell 2: Data Generation

```markdown
## Step 1: Generate Synthetic Sales Data

We'll start by creating a synthetic dataset of sales transactions. This data will be the foundation for our optimization experiments. We'll include a variety of data types and cardinalities to make our tests realistic.
```

```python
import pandas as pd
from faker import Faker
import random
from datetime import datetime, timedelta

# Initialize Faker
fake = Faker()

# Define the number of records
num_records = 5_000_000

# Generate synthetic data
def generate_data(num_records):
    data = []
    for _ in range(num_records):
        data.append({
            "transaction_id": fake.uuid4(),
            "customer_id": random.randint(1000, 2000),
            "product_id": random.randint(100, 500),
            "sale_date": fake.date_between(start_date="-2y", end_date="today"),
            "quantity": random.randint(1, 10),
            "unit_price": round(random.uniform(10.5, 200.5), 2),
            "country": fake.country()
        })
    return data

# Create a Pandas DataFrame
pdf = pd.DataFrame(generate_data(num_records))

# Convert to Spark DataFrame
df = spark.createDataFrame(pdf)

# Write the data to a base Delta table
df.write.format("delta").mode("overwrite").saveAsTable("sales_raw")
```

#### Cell 3: Baseline Performance Analysis

```markdown
## Step 2: Analyze the Unoptimized Table

Before we apply any optimizations, let's run a query on our raw table and establish a baseline for performance. We'll look for sales data for a specific customer and product.

**Instructions:**

1. Run the query below.
2. Open the Spark UI for the job that just ran.
3. Observe the number of files read and the time taken for the query to complete.
```

```python
# Baseline query
from pyspark.sql.functions import col

(df.where((col("customer_id") == 1500) & (col("product_id") == 250))
 .show())
```

#### Cell 4: Table Partitioning

```markdown
## Step 3: Implementing Partitioning

Partitioning is a way to divide a table into smaller, more manageable parts based on the values of one or more columns. This is most effective on columns with low cardinality that are frequently used in filters.

Let's partition our sales data by `country`.
```

```python
# Create a partitioned table
(df.write.format("delta")
 .mode("overwrite")
 .partitionBy("country")
 .saveAsTable("sales_partitioned"))

# Run the same query on the partitioned table
(spark.read.table("sales_partitioned")
      .where((col("customer_id") == 1500) & (col("product_id") == 250))
      .show())
```

```markdown
**Analysis of Partitioning:**

1.  Run the query above on the partitioned table.
2.  Go to the Spark UI and compare the execution plan with the baseline. You'll notice that if a filter on the partition key (`country`) was present, Spark would be able to prune entire directories, significantly reducing the amount of data scanned. Even without a direct filter on the partition key, observe any changes in the query plan.
```

#### Cell 5: Z-Ordering

```markdown
## Step 4: Applying Z-Ordering

Z-Ordering is a technique that co-locates related information in the same set of files. This is particularly useful for high-cardinality columns that are often used in query predicates. We will apply Z-Ordering on `customer_id` and `product_id` to our partitioned table.
```

```python
from delta.tables import *

# Convert the partitioned table to a DeltaTable object
delta_table = DeltaTable.forName(spark, "sales_partitioned")

# Apply Z-Ordering
delta_table.optimize().executeZOrderBy("customer_id", "product_id")

# Rerun the query to see the effect of Z-Ordering
(spark.read.table("sales_partitioned")
      .where((col("customer_id") == 1500) & (col("product_id") == 250))
      .show())
```

````markdown
**Analysis of Z-Ordering:**

1.  After running the `OPTIMIZE` command with `ZORDER BY`, re-run the query.
2.  In the Spark UI, look at the "Details" for the scan phase. You should see a significant reduction in the number of files read, demonstrating the effectiveness of data skipping.```

#### Cell 6: Manual Compaction with `OPTIMIZE`

```markdown
## Step 5: Manual Compaction (OPTIMIZE)

Over time, streaming and DML operations can create many small files in your Delta table, which can hurt read performance. The `OPTIMIZE` command compacts these small files into larger ones.

First, let's simulate the creation of many small files.
```
````

```python
# Simulate small file creation by writing in a loop
for i in range(10):
    (df.sample(fraction=0.001)
     .write.format("delta")
     .mode("append")
     .saveAsTable("sales_to_compact"))

# Check the number of files
display(dbutils.fs.ls(f"dbfs:/user/hive/warehouse/{SCHEMA_NAME}.db/sales_to_compact"))
```

```python
# Now, perform manual compaction
delta_table_to_compact = DeltaTable.forName(spark, "sales_to_compact")
delta_table_to_compact.optimize().executeCompaction()

# Check the number of files again
display(dbutils.fs.ls(f"dbfs:/user/hive/warehouse/{SCHEMA_NAME}.db/sales_to_compact"))
```

```markdown
**Analysis of Compaction:**

- Observe the reduction in the number of files after running `OPTIMIZE`. This leads to more efficient reads as Spark needs to open and process fewer files.
```

#### Cell 7: Auto Compaction

```markdown
## Step 6: Auto Compaction

Databricks can automatically compact small files for you. This is enabled through table properties.

Let's create a new table with auto-compaction enabled.
```

```python
# Create a table with auto-compaction enabled
spark.sql("""
CREATE TABLE sales_auto_compact
USING DELTA
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true'
)
AS SELECT * FROM sales_raw
""")

# Simulate small writes to this table
for i in range(10):
    (df.sample(fraction=0.001)
     .write.format("delta")
     .mode("append")
     .saveAsTable("sales_auto_compact"))
```

````markdown
**Analysis of Auto Compaction:**

- After the writes complete, query the table's history to see the `OPTIMIZE` operations that were automatically triggered. Auto-compaction helps maintain optimal file sizes without manual intervention.```

#### Cell 8: Liquid Clustering

```markdown
## Step 7: Liquid Clustering

Liquid Clustering is a more flexible and adaptive way to organize data compared to partitioning and Z-Ordering. It's especially useful for tables with high-cardinality columns or evolving query patterns.

**Note:** Liquid Clustering requires a Databricks Runtime that supports it.
```
````

```python
# Create a table with Liquid Clustering
spark.sql("""
CREATE TABLE sales_liquid_clustered (
  transaction_id STRING,
  customer_id INT,
  product_id INT,
  sale_date DATE,
  quantity INT,
  unit_price DOUBLE,
  country STRING
)
USING DELTA
CLUSTER BY (customer_id, product_id)
""")

# Insert data into the clustered table
df.write.format("delta").mode("append").saveAsTable("sales_liquid_clustered")

# Rerun the query on the liquid clustered table
(spark.read.table("sales_liquid_clustered")
      .where((col("customer_id") == 1500) & (col("product_id") == 250))
      .show())
```

```markdown
**Analysis of Liquid Clustering:**

1.  Run the query on the liquid clustered table.
2.  Examine the Spark UI. Liquid Clustering provides similar data skipping benefits as Z-Ordering but is more adaptive to changes in your data and queries over time.
```

#### Cell 9: VACUUM

```markdown
## Step 8: VACUUM

The `VACUUM` command removes old, unreferenced data files from your Delta table's storage. This is crucial for managing storage costs and cleaning up your data lake.

**Important:** By default, `VACUUM` has a retention period of 7 days to prevent accidental deletion of data that might still be in use. For this educational exercise, we will disable this check. **Do not do this in a production environment.**
```

```python
# Disable the retention period check for demonstration purposes
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")

# VACUUM the partitioned table
delta_table_to_vacuum = DeltaTable.forName(spark, "sales_partitioned")
delta_table_to_vacuum.vacuum()

# Re-enable the retention check
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "true")
```

```markdown
**Analysis of VACUUM:**

- The `VACUUM` command cleans up files that are no longer part of the current version of the table. You can check the file system before and after running `VACUUM` on a table that has undergone several modifications to see the effect.
```

#### Cell 10: Conclusion and Cleanup

```markdown
## Project Conclusion

In this project, we have explored several key techniques for optimizing Delta Lake tables in Databricks. We've seen how partitioning, Z-Ordering, compaction, and Liquid Clustering can significantly improve query performance by reducing the amount of data that needs to be scanned. We also learned how to maintain our tables using the `VACUUM` command.

**Key Takeaways:**

- **Partitioning:** Best for low-cardinality columns used frequently in filters.
- **Z-Ordering:** Effective for improving data skipping on high-cardinality columns.
- **Compaction:** Solves the "small file problem" and is crucial for read performance.
- **Liquid Clustering:** A modern, flexible approach to data layout that adapts to your data and queries.
- **VACUUM:** Essential for managing storage and cleaning up old data files.

## Cleanup

Run the following cell to drop the catalog and all associated tables created during this project.
```

```python
# Drop the catalog and all its contents
spark.sql(f"DROP CATALOG IF EXISTS {CATALOG_NAME} CASCADE")
```
