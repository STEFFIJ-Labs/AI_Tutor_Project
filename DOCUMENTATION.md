# AI Tutor System: Database Documentation

## 1. System Overview
This documentation describes the **"Database IN" (Knowledge Core)** of the AI Tutor System. 
Unlike the "Database OUT" (which stores user analytics and interactions), this database acts as the strict, structural foundation that feeds linguistic rules, dialects, and contextual metadata to the AI models.



## 2. Structural Design Choices
The database (`ai_tutor_db`) consists of 10 tables designed in Third Normal Form (3NF), with strategic denormalization using JSONB fields to accommodate AI-generated complexities.

### Key Architectural Features:
* **Recursive Relationships:** The `LANGUAGE_VARIANT` table uses a self-referencing Foreign Key (`parent_variant_id`) to map dialects (e.g., Neapolitan) or spoken variants (e.g., Finnish Puhekieli) directly to their standard parent languages without duplicating structures.
* **JSONB for AI Compatibility:** Tables like `CONTENT_UNIT` and `LEMMA` utilize `JSONB` data types to store highly dynamic data such as syntactic dependency trees (`syntax_ud_json`) and L1 interference patterns. This bypasses the rigidity of 1NF while allowing high-performance querying directly from the AI pipeline.
* **Composite Primary Keys:** The Many-to-Many relationships bridging content with cultural contexts (`Rel_Content_Context`) and tones (`Rel_Content_Tone`) are resolved using Composite Primary Keys to ensure absolute referential integrity while adding weighted parameters (e.g., `intensity_score`).

## 3. Implementation Details
As per the assignment requirements:
1. **Creation Script:** The raw DDL and DML codes used to build the structure and insert initial test data are located in `creation_script.sql`.
2. **Database Dump:** The final physical state of the database, including the auto-generated relationships and JSON objects, has been exported as an SQL dump and is available in `database_schema.sql`.
3. **AI Pipeline Simulation:** A Python script (`ai_pipeline_simulator.py`) using `psycopg2` was developed to demonstrate how the AI layer queries the `JSONB` fields natively, bridging the relational database with the AI inference logic.
