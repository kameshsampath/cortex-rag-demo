USE ROLE  &{ctx.env.SNOWFLAKE_ROLE};
USE DATABASE  &{ctx.env.SNOWFLAKE_DATABASE};

-- Schema to hold all Streamlit
CREATE SCHEMA IF NOT EXISTS APPS;

USE SCHEMA APPS;

GRANT CREATE STREAMLIT ON SCHEMA APPS TO ROLE &{ctx.env.SNOWFLAKE_ROLE};
GRANT CREATE STAGE ON SCHEMA APPS TO ROLE &{ctx.env.SNOWFLAKE_ROLE};

CREATE OR REPLACE STAGE  APPS.SRC
 DIRECTORY = (ENABLE = TRUE);

PUT file://app/environment.yml @APPS.SRC
  AUTO_COMPRESS = FALSE 
  OVERWRITE = TRUE;

PUT file://app/app.py  @APPS.SRC/rag_demo
  AUTO_COMPRESS = FALSE 
  OVERWRITE = TRUE;

ALTER STAGE APPS.SRC REFRESH;

CREATE OR REPLACE STREAMLIT APPS.rag_demo_app
    ROOT_LOCATION = '@APPS.SRC/rag_demo'
    MAIN_FILE = 'app.py'
    TITLE = "Cortex RAG DEMO"
    QUERY_WAREHOUSE = s;