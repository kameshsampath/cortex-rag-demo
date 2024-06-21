import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col, sql_expr
from snowflake.cortex import Complete, Summarize

st.set_page_config(page_title=":snowflake:💬 Snowflake", layout="wide")

large_llms = ["llama3-70b", "mistral-large"]
medium_llms = ["snowflake-arctic", "reka-flash", "mixtral-8x7b", "llama2-70b-chat"]
small_llms = ["llama3-8b", "mistral-7b", "gemma-7b"]


session = get_active_session()


@st.cache_data(show_spinner=False)
def fetch_similar_docs(question, num_chunks=3):
    col_similarity = sql_expr(
        f"""
VECTOR_COSINE_SIMILARITY(
chunk_vec,
SNOWFLAKE.CORTEX.EMBED_TEXT_768(
'{st.session_state.embed_model}',
'{question}')
)
"""
    )

    q_sel = session.table("DOCS_CHUNKS_TABLE").select(
        col("chunk"),
        col_similarity.alias("similarity"),
    )

    df = q_sel.sort(
        "similarity",
        ascending=False,
    ).limit(num_chunks)

    if st.session_state.enable_debug and df is not None:
        print(f"{df.queries['queries'][0]}")
    # extract chunks
    docs = df.to_pandas()
    context_docs = ["".join(chunk) for chunk in docs.loc[:, "CHUNK"].values]
    return context_docs


def get_chat_history():
    # Get the history from the st.session_stage.messages according to the slide window parameter
    chat_history = []
    if len(st.session_state.messages) > 0:
        for i in range(0, len(st.session_state.messages) - 1):
            chat_history.append(st.session_state.messages[i])

    return chat_history


def summarize_question_with_history(chat_history, question):
    prompt = f"""
        Based on the chat history between and the question, generate a query that extend the question
        with the chat history provided. The query should be in natural language. 
        Answer with only the query. Do not add any explanation.

        <chat_history>
        {chat_history}
        </chat_history>
        <question>
        {question}
        </question>
        """
    response = Summarize(prompt, session)
    if st.session_state.enable_debug:
        st.sidebar.subheader("Summarized Context with History")
        st.sidebar.text_area(
            "Summarized Context with History", response, label_visibility="hidden"
        )
    return response


def generate_prompt(question):
    context_docs = ""
    chat_history = ""
    if st.session_state.use_chat_history:
        chat_history = get_chat_history()
        if len(chat_history) != 0:
            summary = summarize_question_with_history(chat_history, question)
            context_docs = fetch_similar_docs(summary)
        else:
            context_docs = fetch_similar_docs(question)
    else:
        context_docs = fetch_similar_docs(question)

    prompt = f"""
[INST]
You are a helpful AI chat assistant with RAG capabilities. Answer user's question,with context between <context> and </context> tags.
You offer a chat experience considering the information included in the CHAT HISTORY
provided between <chat_history> and </chat_history> tags..
When answering the question contained between <question> and </question> tags be concise and do not hallucinate. 
If you don't have the information just say so.

Do not mention the CONTEXT used in your answer.
Do not mention the CHAT HISTORY used in your answer.
<chat_history>
{chat_history}
</chat_history>
<context>
{context_docs}
</context>
<question>
{question}
</question>
[/INST]
Answer:
"""
    return prompt


def generate_response(question):
    if st.session_state.use_rag:
        prompt = generate_prompt(question)
        response = Complete(st.session_state.llm_model, prompt)
    else:
        prompt = f"""
'[INST]
You are very capable AI Assistant. Answer question contained between <question> and </question> tags.

Answers should be concise.
Answers should not exceed 100 words .
Do not hallucinate. 

If you don't have the information just say so.
<question>  
{question} 
</question>
[/INST]
Answer: '
        """
    response = Complete(st.session_state.llm_model, prompt)

    return response


@st.cache_data(show_spinner=True)
def rag_docs():
    docs_available = session.sql("ls @docs.docs").collect()
    return docs_available


def sidebar():
    st.sidebar.selectbox(
        "Choose Model",
        medium_llms + small_llms + large_llms,
        key="llm_model",
    )

    st.sidebar.selectbox(
        "Embedding Model",
        ("snowflake-arctic-embed-m", "e5-base-v2"),
        key="embed_model",
    )

    st.sidebar.toggle(label="Use RAG", key="use_rag", value=True)
    st.sidebar.toggle(label="Use chat history", key="use_chat_history", value=True)
    st.sidebar.toggle(label="Debug", key="enable_debug")
    st.sidebar.button("Start Over", key="clear_conversation")

    if st.session_state.use_rag:
        list_docs = []
        for doc in rag_docs():
            list_docs.append(doc["name"])
        st.sidebar.dataframe(list_docs, use_container_width=True)


def chat_box():
    # Session State
    if (
        st.session_state.clear_conversation or "messages" not in st.session_state.keys()
    ):  # Initialize the chat message history
        st.session_state.messages = [
            {"role": "assistant", "content": "How can I help you ?"},
        ]

    # Conversational History
    for message in st.session_state.messages:
        if message["role"] == "system":
            continue
        with st.chat_message(message["role"]):
            st.write(message["content"])

    if prompt := st.chat_input():
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.write(prompt)

    # Generate a new response if last message is not from assistant
    if st.session_state.messages[-1]["role"] != "assistant":
        with st.chat_message("assistant"):
            with st.spinner("Thinking..."):
                response = generate_response(prompt)
                st.write(response)
        message = {"role": "assistant", "content": response}
        st.session_state.messages.append(message)


def main():
    sidebar()
    chat_box()


if __name__ == "__main__":
    main()
