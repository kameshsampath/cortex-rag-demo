import io
import logging
from langchain.text_splitter import RecursiveCharacterTextSplitter
from snowflake.snowpark.files import SnowflakeFile
import PyPDF2
import pandas as pd


class PDFTextChunker:
    LOGGER = logging.getLogger(__name__)

    def read_pdf(self, file_url: str):
        self.LOGGER.info(f"Reading PDF File {file_url}")

        with SnowflakeFile.open(file_url, "rb") as f:
            buffer = io.BytesIO(f.readall())

        reader = PyPDF2.PdfReader(buffer)
        text = ""
        for page in reader.pages:
            try:
                text += page.extract_text().replace("\n", " ").replace("\0", " ")
            except:
                text = "Unable to Extract"
                self.LOGGER.warn(f"Unable to extract from file {file_url}, page {page}")

        return text

    def process(self, file_url: str):
        self.LOGGER.info(f"Processing File {file_url}")
        text = self.read_pdf(file_url)

        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=4000,
            chunk_overlap=400,
            length_function=len,
        )

        chunks = text_splitter.split_text(text)

        df = pd.DataFrame(chunks, columns=["chunks"])

        yield from df.itertuples(index=False, name=None)
