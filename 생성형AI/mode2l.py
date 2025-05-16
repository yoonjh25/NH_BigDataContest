from langchain_openai import AzureChatOpenAI
from langchain.embeddings import AzureOpenAIEmbeddings
from langchain.vectorstores import FAISS
from langchain_experimental.agents.agent_toolkits import create_pandas_dataframe_agent
from langchain.chains import RetrievalQA
from langchain.schema import Document
import pandas as pd
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.document_loaders import PyPDFLoader
import os



# Azure OpenAI 설정
openai_api_key = "***"
openai_api_base = "https://yoonj-m2sdiwe0-eastus.cognitiveservices.azure.com/openai/deployments/text-embed/embeddings?api-version=2023-05-15"
llm = AzureChatOpenAI(
    temperature=0,
    model_name="gpt-35-turbo",
    azure_endpoint="***",
    openai_api_key=openai_api_key,
    openai_api_type="azure",
    openai_api_version="2024-02-01",
    deployment_name="gpt-35-turbo"
)

# 임베딩 설정 및 벡터 데이터베이스 생성
embeddings = AzureOpenAIEmbeddings(
    openai_api_key=openai_api_key,
    openai_api_base=openai_api_base,
    openai_api_type="azure",
    openai_api_version="2023-05-15",
    model="text-embedding-3-small",
    chunk_size=2048,
    validate_base_url=False
)


# PDF 및 텍스트 파일 로드
loader = PyPDFLoader('/Users/juhee/Desktop/농협증권/생성형AI/참고 데이터/etf_introduction_230406.pdf')
pdf_document = loader.load()
pdf_text = pdf_document[0].page_content

txt_files = [
    "참고 데이터/미국 테크아닌 기업들의 활황-11월.txt",
    "참고 데이터/나스닥 급락 코멘트- 대선 불확실성 선반영 중(6월).txt",
    "참고 데이터/글로벌 투자전략- 2025년 5대 리스크 요인.txt",
    "참고 데이터/원자력ETF.txt",
    "참고 데이터/미국 급락 코멘트:민감해진 투자심리,시장 하락 반영.txt",
    "참고 데이터/반도체 개발 주기 가속화 수혜.txt",
    "참고 데이터/AI 반도체 매출 상향에 주목.txt",
    "참고 데이터/신재생 에너지에 따른 전력 테마.txt"
]


# 문서 내용을 청크로 나누어 documents 리스트에 추가
documents = []
splitter = RecursiveCharacterTextSplitter(chunk_size=2048, chunk_overlap=50)

# PDF 파일 처리
pdf_chunks = splitter.split_text(pdf_text)
documents.extend([Document(page_content=chunk, metadata={"source": "etf_introduction_230406.pdf"}) for chunk in pdf_chunks])

# TXT 파일 처리
for file_path in txt_files:
    with open(file_path, 'r', encoding='utf-8') as file:
        txt_content = file.read()
        txt_chunks = splitter.split_text(txt_content)
        filename = file_path.split('/')[-1]
        documents.extend([Document(page_content=chunk, metadata={"source": filename}) for chunk in txt_chunks])

# 문서 수 확인
print(f"총 문서 수: {len(documents)}")  # 문서가 잘 추가되었는지 확인
# CSV 파일 로드 및 데이터프레임 에이전트 생성
csv_file = '참고 데이터/(etf 스코어 정리)score백분위, min-max scaling 포함 데이터.csv'
df = pd.read_csv(csv_file, nrows=300)
df.columns = ['ETF이름', 'ETF섹터', 'datetime', '1개월총수익율', '3개월총수익율', '1년총수익율', 
              'ETF점수', '상관관계점수', '최대낙폭점수', '변동성z점수']
df_agent = create_pandas_dataframe_agent(llm, df, verbose=True, allow_dangerous_code=True)

# FAISS 벡터 스토어 생성
vectorstore = FAISS.from_documents(documents=documents, embedding=embeddings)
retriever = vectorstore.as_retriever(search_type="similarity", search_kwargs={"k": 4})


# qa_chain = RetrievalQA.from_chain_type(llm, retriever=retriever, return_source_documents=True)

from langchain.prompts import PromptTemplate
from langchain.chains import RetrievalQA

# 명확한 지침과 단계별 검색을 포함한 프롬프트 템플릿 정의
prompt_template = PromptTemplate(
    input_variables=["context", "question"],
    template="""
    먼저 문서에서 아래 질문에 대한 답변을 찾아주세요. 만약 문서에서 답변을 찾지 못한다면, CSV 데이터를 참고하여 답변을 제공해주세요.

    컨텍스트:
    {context}

    질문:
    {question}

    답변:
    """
)

# PromptTemplate을 포함하여 qa_chain 생성
qa_chain = RetrievalQA.from_chain_type(
    llm,
    retriever=retriever,
    return_source_documents=True,
    chain_type_kwargs={"prompt": prompt_template}
)

def search_combined_response(question: str):
    # 1. 문서에서 먼저 답변을 검색
    try:
        doc_response_dict = qa_chain.batch([{"query": question}])[0]
        print("문서 검색 결과:", doc_response_dict)  # 문서 검색 결과 확인용

        # 문서에서 유의미한 답변이 존재한다면, 이를 반환
        if doc_response_dict and "result" in doc_response_dict and doc_response_dict["result"]:
            doc_answer = doc_response_dict["result"]  # 여기서 "result" 필드를 참조
            prompt = f"질문: '{question}'에 대한 답변을 제공해주세요. 문서에서 찾은 결과: {doc_answer}."
            llm_response = llm.invoke(prompt)
            return {"source": "Documents", "response": llm_response.content}
    
    except Exception as e:
        print("문서 검색 중 오류 발생:", e)

    # 문서에서 유효한 답변이 없을 경우에만 CSV 데이터에서 검색
    try:
        csv_response = df_agent.invoke(question)
        if csv_response:
            print("CSV 검색 결과:", csv_response)  # CSV 검색 결과 확인용
            prompt = f"질문: '{question}'에 대한 답변을 제공해주세요. 데이터에서 찾은 결과: {csv_response}."
            llm_response = llm.invoke(prompt)
            return {"source": "CSV data", "response": llm_response.content}
    except Exception as e:
        print("CSV 검색 중 오류 발생:", e)

    # 문서와 CSV 모두에서 답변을 찾지 못한 경우
    return {"source": "None", "response": "No relevant information found."}



from langchain.prompts import ChatPromptTemplate  # 필요한 경우 추가로 import

# def search_combined_response(question: str):
#     # 1. 문서에서 먼저 답변을 검색
#     try:
#         doc_response_dict = qa_chain.batch([{"query": question}])[0]
#         print("문서 검색 결과:", doc_response_dict)  # 문서 검색 결과 확인용

#         # 'answer' 키가 있는지 확인 후 응답 생성
#         if doc_response_dict and "answer" in doc_response_dict:
#             doc_answer = doc_response_dict["answer"]
#             prompt = f"질문: '{question}'에 대한 답변을 제공해주세요. 문서에서 찾은 결과: {doc_answer}."
#             llm_response = llm.invoke(prompt)
#             return {"source": "Documents", "response": llm_response.content}
    
#     except Exception as e:
#         print("문서 검색 중 오류 발생:", e)

#     # 문서에서 유효한 답변이 없을 경우에만 CSV 데이터에서 검색
#     try:
#         csv_response = df_agent.invoke(question)
#         if csv_response:
#             print("CSV 검색 결과:", csv_response)  # CSV 검색 결과 확인용
#             prompt = f"질문: '{question}'에 대한 답변을 제공해주세요. 데이터에서 찾은 결과: {csv_response}."
#             llm_response = llm.invoke(prompt)
#             return {"source": "CSV data", "response": llm_response.content}
#     except Exception as e:
#         print("CSV 검색 중 오류 발생:", e)

#     # 문서와 CSV 모두에서 답변을 찾지 못한 경우
#     return {"source": "None", "response": "No relevant information found."}




