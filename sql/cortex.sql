-- COMPLETE FUNCTION
SELECT 
    SNOWFLAKE.CORTEX.COMPLETE(
        'snowflake-arctic',
        'Tell me about Snowflake'
    ) AS Response;

-- TRANSLATE FUNCTION
SELECT 
    SNOWFLAKE.CORTEX.TRANSLATE(
        'Comment allez-vous?',
        'fr_FR','en_XX'
    ) AS Translated;

-- SENTIMENT FUNCTION
SELECT 
    TRANSCRIPT,
    ROUND(
        SNOWFLAKE.CORTEX.SENTIMENT(TRANSCRIPT)
    )::INT AS Sentiment
FROM CALL_TRANSCRIPTS 
WHERE LANGUAGE = 'English'
LIMIT 10;

-- SUMMARIZE
SELECT 
    TRANSCRIPT,
    SNOWFLAKE.CORTEX.SUMMARIZE(TRANSCRIPT) AS Summary
FROM CALL_TRANSCRIPTS 
WHERE LANGUAGE = 'English' LIMIT 1;

-- PROMPT
SET PROMPT = 
'### 
Summarize this transcript in less than 200 words. 
Put the product name, defect and summary in JSON format. 
###';

SELECT 
    TRANSCRIPT,
    SNOWFLAKE.CORTEX.COMPLETE(
    'snowflake-arctic',
    CONCAT(
      '[INST]',
      $PROMPT,
      TRANSCRIPT,
     '[/INST]')
     ) AS Summary
FROM CALL_TRANSCRIPTS 
WHERE LANGUAGE = 'English'
LIMIT 1;