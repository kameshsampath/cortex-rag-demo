# Demo Script

Modified version of [Cortex RAG Demo](https://quickstarts.snowflake.com/guide/asking_questions_to_your_own_documents_with_snowflake_cortex/#0) with updates to LLM Functions, Streamlit.

## Env Setup

```shell
pip install -U requirements.txt
```

## Prepare DB

```shell
snow sql -f sql/setup.sql --role='ACCOUNTADMIN'
```

## Verify Connection

```shell
snow connection test
```

## Load Data

```shell
snow sql -f sql/load.sql
```

Verify loaded data,

```shell
snow sql -q 'SELECT * FROM CALL_TRANSCRIPTS LIMIT 10'
```

Verify the docs are loaded,

```shell
snow sql -q 'ls @DOCS.docs'
```

Verify doc chunks and its corresponding vectors,

```shell
snow sql -q 'SELECT RELATIVE_PATH, SIZE, CHUNK, CHUNK_VEC FROM DOCS_CHUNKS_TABLE LIMIT 5;'
```

## Streamlit App

```shell
snow sql -f sql/app.sql
```

Get details about the application,

```shell
snow streamlit describe APPS.rag_demo_app
```

Get the application URL,

```shell
snow streamlit get-url APPS.rag_demo_app
```

## Useful Links

- [Cortex RAG Quickstart](https://quickstarts.snowflake.com/guide/asking_questions_to_your_own_documents_with_snowflake_cortex/#0)
- [Snow CLI](https://github.com/snowflakedb/snowflake-cli)
- [Snowflake Trial](https://signup.snowflake.com/)
