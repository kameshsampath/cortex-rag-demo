USE ROLE  &{ctx.env.SNOWFLAKE_ROLE};
USE DATABASE  &{ctx.env.SNOWFLAKE_DATABASE};
-- Schema to hold all file formats
CREATE SCHEMA IF NOT EXISTS FILE_FORMATS;
-- Database that will hold all stages
CREATE SCHEMA IF NOT EXISTS EXTERNAL_STAGES;
-- file format to load data from CSV
-- Default schema
USE SCHEMA PUBLIC;
CREATE FILE FORMAT IF NOT EXISTS FILE_FORMATS.CSVFORMAT
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TYPE = 'CSV';

-- s3 stage to load data files from
CREATE STAGE IF NOT EXISTS  EXTERNAL_STAGES.CALL_TRANSCRIPTS_DATA_STAGE
  FILE_FORMAT = FILE_FORMATS.CSVFORMAT
  URL = 's3://sfquickstarts/misc/call_transcripts/';

-- table that will be used in LLM queries
CREATE TABLE IF NOT EXISTS CALL_TRANSCRIPTS ( 
  DATE_CREATED DATE,
  LANGUAGE VARCHAR(60),
  COUNTRY VARCHAR(60),
  PRODUCT VARCHAR(60),
  CATEGORY VARCHAR(60),
  DAMAGE_TYPE VARCHAR(90),
  TRANSCRIPT VARCHAR
);

-- Load the data on the transcripts table
COPY INTO CALL_TRANSCRIPTS
  FROM @EXTERNAL_STAGES.CALL_TRANSCRIPTS_DATA_STAGE;

-- Schema to hold all pdf documents
CREATE SCHEMA IF NOT EXISTS DOCS;

CREATE STAGE IF NOT EXISTS  DOCS.docs
 DIRECTORY = (ENABLE = TRUE);

PUT file://docs/*.pdf  @DOCS.docs/docs
  AUTO_COMPRESS=FALSE ;

-- Refresh the /docs path 
ALTER STAGE DOCS.docs REFRESH SUBPATH = 'docs';

-- SCHEMA to hold all user defined functions
CREATE SCHEMA IF NOT EXISTS MY_FUNCTIONS;

-- Stage to hold all UDF/UDTF sources
CREATE STAGE IF NOT EXISTS MY_FUNCTIONS.SRC;

-- Copy the PDF Text Chunker
PUT file://src/pdf_text_chunker.py  @MY_FUNCTIONS.SRC
  AUTO_COMPRESS = FALSE 
  OVERWRITE = TRUE ;

-- PDF Text Chunker is used to extract the text from PDF
-- It scans all the PDF files in the @DOCS.docsstage 
CREATE OR REPLACE FUNCTION  MY_FUNCTIONS.PDF_TEXT_CHUNKER(file_url string)
RETURNS TABLE(chunk varchar)
LANGUAGE PYTHON
RUNTIME_VERSION = 3.11
PACKAGES = ('snowflake-snowpark-python==1.16.0', 'PyPDF2==2.10.5', 'langchain==0.0.298' )
IMPORTS = ('@MY_FUNCTIONS.SRC/pdf_text_chunker.py')
HANDLER = 'pdf_text_chunker.PDFTextChunker';

-- Load the PDF Chunks with its Vectors

-- Table to hold Doc Chunks
CREATE TABLE IF NOT EXISTS  DOCS_CHUNKS_TABLE ( 
    RELATIVE_PATH VARCHAR(16777216), -- Relative path to the PDF file
    SIZE NUMBER(38,0), -- Size of the PDF
    FILE_URL VARCHAR(16777216), -- URL for the PDF
    SCOPED_FILE_URL VARCHAR(16777216), -- Scoped url (you can choose which one to keep depending on your use case)
    CHUNK VARCHAR(16777216), -- Piece of text
    CHUNK_VEC VECTOR(FLOAT, 768)  -- Embedding using the VECTOR data type
);

-- just be sure no redundant data

TRUNCATE TABLE DOCS_CHUNKS_TABLE;

-- Load Chunks and its vectors
INSERT INTO DOCS_CHUNKS_TABLE (relative_path, size, file_url,
                            scoped_file_url, chunk, chunk_vec)
    SELECT 
        d.relative_path,
        d.size,
        d.file_url,
        build_scoped_file_url(@DOCS.docs,d.relative_path) as bs_file_url,
        f.chunk as chunk,
        SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m',chunk) as chunk_vec
    FROM 
        directory(@DOCS.docs) AS d,
        TABLE(MY_FUNCTIONS.PDF_TEXT_CHUNKER(build_scoped_file_url(@DOCS.docs,d.relative_path))) as f;
